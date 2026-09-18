import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../database/app_database.dart';
import '../database/database_service.dart';
import '../network/dio_client.dart';
import '../config/api_config.dart';
import '../services/connectivity_service.dart';
import '../services/logger_service.dart';
import '../session/account_session.dart';
import '../session/unsynced_work_quarantine.dart';
import 'sync_acknowledgement.dart';
import 'sync_push_limits.dart';
import 'sync_queue_service.dart';

/// [partialFailure] means the cycle finished but some queued work did not land.
/// Reporting plain [idle] there told the user everything was saved while their
/// changes were still stuck in the queue.
enum SyncState { idle, syncing, error, offline, partialFailure }

class SyncService {
  SyncService._();
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;

  // Created once for the life of the service and closed only by [dispose].
  // Closing it on logout left every later session publishing into a dead stream:
  // signing out and back in threw on the first state change.
  final _stateController = StreamController<SyncState>.broadcast();

  StreamSubscription<ConnectionStatus>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  SyncState _currentState = SyncState.idle;
  bool _isSyncing = false;

  /// The sync cycle currently running, so a session can be stopped by awaiting it
  /// rather than pulling the database out from under it.
  Future<void>? _activeSync;

  /// The account generation this session was started for. Work that outlives the
  /// session must not write anything.
  int _sessionGeneration = 0;
  bool _sessionActive = false;

  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState get currentState => _currentState;
  bool get isSessionActive => _sessionActive;

  AppDatabase get _db => DatabaseService().database;
  DioClient get _dio => DioClient();
  SyncQueueService get _queue => SyncQueueService();

  /// Starts syncing for the signed-in account.
  ///
  /// Safe to call repeatedly: an existing session is stopped first, so this is
  /// also how an account switch is handled.
  Future<void> startSession() async {
    await stopSession();

    _sessionGeneration = AccountSession().generation;
    _sessionActive = true;

    _connectivitySubscription = ConnectivityService().statusStream.listen((status) {
      if (!_sessionActive) return;
      if (status == ConnectionStatus.online) {
        _setState(SyncState.idle);
        performSync();
      } else {
        _setState(SyncState.offline);
      }
    });

    if (!ConnectivityService().isOnline) {
      _setState(SyncState.offline);
    } else {
      _setState(SyncState.idle);
    }

    // Periodic sync every 5 minutes
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_sessionActive && ConnectivityService().isOnline) {
        performSync();
      }
    });
  }

  /// Stops syncing for the current account and waits for work already running.
  ///
  /// Awaiting matters: the caller clears the local database next, and a sync
  /// still writing into it would either fail or repopulate the database it was
  /// just told to empty. The state stream stays open for the next session.
  Future<void> stopSession() async {
    _sessionActive = false;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;

    final running = _activeSync;
    if (running != null) {
      AppLogger.info('Waiting for in-flight sync before ending session');
      try {
        await running;
      } catch (_) {
        // Already logged by the cycle itself.
      }
    }

    _isSyncing = false;
    _activeSync = null;
    _currentState = SyncState.idle;
  }

  /// Kept for callers that still use the old name.
  @Deprecated('Use startSession(); initialize() does not scope work to an account')
  void initialize() => unawaited(startSession());

  void _setState(SyncState state) {
    _currentState = state;
    if (_stateController.isClosed) return;
    _stateController.add(state);
  }

  Future<void> performSync() async {
    if (_isSyncing || !ConnectivityService().isOnline) return;
    if (!_sessionActive) {
      AppLogger.debug('Sync requested with no active session; ignoring');
      return;
    }

    final cycle = _runSyncCycle();
    _activeSync = cycle;
    try {
      await cycle;
    } finally {
      if (identical(_activeSync, cycle)) _activeSync = null;
    }
  }

  Future<void> _runSyncCycle() async {
    final generation = _sessionGeneration;

    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      // Phase 1: Push local changes
      final pushedCleanly = await _pushChanges();

      // Phase 2: Pull server changes
      await _pullChanges();

      // The account may have changed while this cycle was running; publishing
      // its result would describe a session that no longer exists.
      if (!AccountSession().isCurrent(generation)) {
        AppLogger.info('Sync finished after its session ended; result discarded');
        return;
      }

      // A successful pull does not mean the user's own changes were saved.
      _setState(pushedCleanly ? SyncState.idle : SyncState.partialFailure);
    } catch (e) {
      AppLogger.error('Sync failed: $e');
      if (AccountSession().isCurrent(generation)) {
        _setState(SyncState.error);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> performInitialSync() async {
    if (!ConnectivityService().isOnline) {
      AppLogger.info('Offline - skipping initial sync');
      return;
    }
    if (!_sessionActive) {
      AppLogger.debug('Initial sync requested with no active session; ignoring');
      return;
    }

    // Registered in _activeSync exactly as an ordinary cycle is. Without this
    // stopSession() returns while the initial pull is still running, and a full
    // pull for the previous account lands in the next account's database - the
    // one case where the most data is in flight at once.
    final cycle = _runInitialSync();
    _activeSync = cycle;
    try {
      await cycle;
    } finally {
      if (identical(_activeSync, cycle)) _activeSync = null;
    }
  }

  Future<void> _runInitialSync() async {
    final generation = _sessionGeneration;
    _isSyncing = true;
    _setState(SyncState.syncing);

    try {
      await _pullChanges(); // since=null means full sync
      if (AccountSession().isCurrent(generation)) _setState(SyncState.idle);
    } catch (e) {
      AppLogger.error('Initial sync failed: $e');
      if (AccountSession().isCurrent(generation)) _setState(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes queued operations and applies each acknowledgement to the exact
  /// revision it was sent for.
  ///
  /// Returns false when any operation failed, so the caller can report a partial
  /// failure instead of showing a clean idle state over a queue that is stuck.
  ///
  /// The queue goes out in batches the server will accept rather than in one
  /// request. `POST /sync/push` caps both the number of operations and the size
  /// of the body, and a batch over either is refused outright - not throttled,
  /// refused - so an uncapped flush would leave a long offline session with no
  /// way back at all. [planPushBatches] splits the queue in place, so a parent
  /// create is never sent after the child that depends on it.
  ///
  /// Splitting has nothing to offer one operation that is over the limit on its
  /// own, though, and that case is worse than a large queue: the smallest
  /// request carrying it is still refused, so it would be refused on every
  /// cycle and the flush would stop in front of everything behind it, forever.
  /// Such an operation is screened out here and set aside instead - see
  /// [_setAsideUnsendable].
  Future<bool> _pushChanges() async {
    // An operation abandoned mid-flight by a process kill would otherwise sit in
    // `inProgress` forever.
    await _recoverStuckOperations();

    final pendingOps = await _queue.getPendingOperations();
    if (pendingOps.isEmpty) return true;

    // Encoded once, here, and measured from the same map that is sent. Sizing a
    // batch from anything other than the bytes it will actually weigh is how a
    // client builds the request the server refuses.
    final candidates = pendingOps
        .map((op) => _PushCandidate(op, _changeFor(op)))
        .toList(growable: false);

    // An operation too large for any request at all is taken out before the
    // queue is planned.
    //
    // Chunking cannot rescue it: a body carrying nothing but this one operation
    // is already over the limit, so the server answers 413 - and a 413 is a
    // verdict on the body, which the next attempt would repeat exactly. Sent,
    // it would be refused on every cycle, the flush would stop at it, and every
    // operation queued behind it would wait on a request that can never
    // succeed. That is a queue that never drains again, from one over-sized
    // note.
    final sendable = <_PushCandidate>[];
    final unsendable = <_PushCandidate>[];
    for (final candidate in candidates) {
      if (exceedsPushBodyLimit(candidate.encodedBytes)) {
        unsendable.add(candidate);
      } else {
        sendable.add(candidate);
      }
    }

    var allSucceeded = true;

    if (unsendable.isNotEmpty) {
      await _setAsideUnsendable(unsendable.map((c) => c.op).toList());
      // The cycle did not carry the user's work, and must not report as though
      // it had. The durable record of what happened is in recovery storage.
      allSucceeded = false;
    }

    if (sendable.isEmpty) return allSucceeded;

    final batches = planPushBatches<_PushCandidate>(
      sendable,
      (candidate) => candidate.encodedBytes,
    );

    AppLogger.info('Pushing ${sendable.length} changes to server '
        'in ${batches.length} batch(es)');

    var sent = 0;

    for (final batch in batches) {
      final outcome = await _pushBatch(batch);

      if (!outcome.reachedServer) {
        // Everything after this batch stays exactly as it was: pending, in
        // order, never marked in flight. Sending the next batch anyway would
        // push children whose parent create has just gone back on the queue,
        // and the server would refuse every one of them for a trip it has not
        // been told about yet.
        AppLogger.warning('Stopping the flush after a failed batch; '
            '${sendable.length - sent} operations stay queued');
        return false;
      }

      sent += batch.length;
      if (!outcome.allAcknowledged) allSucceeded = false;
    }

    return allSucceeded;
  }

  /// The wire form of one queued operation.
  Map<String, dynamic> _changeFor(SyncQueueData op) {
    final payload = jsonDecode(op.payload);
    return {
      'entity_type': op.entityType,
      'entity_id': op.entityId,
      'operation': op.operation,
      'data': payload,
      if (op.operation == 'update')
        'base_version': (payload as Map<String, dynamic>)['_base_version'],
    };
  }

  /// Sends one batch and settles every operation in it.
  ///
  /// Only this batch is marked in flight, and only this batch is released when
  /// the request fails. Marking the whole queue up front - which is what a
  /// single-request flush did - would leave operations that were never sent
  /// sitting in `inProgress`, waiting on the five-minute stuck-operation
  /// recovery before they could be pushed at all.
  Future<_BatchOutcome> _pushBatch(List<_PushCandidate> batch) async {
    // Record what each operation is being sent *for* before sending it. If the
    // user edits the record while the request is in flight, the revision no
    // longer matches and the response must not clear their dirty flag.
    final sentRevisions = <String, DateTime?>{};
    await _db.transaction(() async {
      for (final candidate in batch) {
        final op = candidate.op;
        final revision = await _currentRevision(op.entityType, op.entityId);
        sentRevisions[op.id] = revision;
        await _db.syncQueueDao.markInProgress(
          op.id,
          sentRevision: revision,
          sentAt: DateTime.now(),
        );
      }
    });

    List<dynamic> results;
    try {
      final response = await _dio.post(
        '${ApiConfig.sync}/push',
        data: {
          'changes': batch.map((c) => c.change).toList(growable: false),
        },
      );
      results = (response.data['results'] as List?) ?? [];
    } catch (e) {
      AppLogger.error('Push failed: $e');
      // The server may still have applied some of these. Return them to the
      // queue rather than dropping them; creates are replay-guarded and updates
      // are revision-checked, so a redelivery is safe.
      for (final candidate in batch) {
        await _db.syncQueueDao.releaseInProgress(candidate.op.id);
      }

      // A refusal is not a failure to reach the server, and treating it as one
      // is what strands a queue. 413 means the request arrived, was read and was
      // judged too large: the next attempt sends the identical bytes and gets
      // the identical answer. Retrying it is not slow, it is endless.
      //
      // This should be unreachable - the flush screens over-sized operations out
      // before planning, and every batch is built to the server's own numbers -
      // so getting here means the mirrored limits have drifted apart. Even then
      // the queue must keep moving, so the batch is halved until the operation
      // that cannot fit is alone, and that one is set aside. Halving keeps queue
      // order: the front half is sent, in full, before the back half.
      if (_isPayloadTooLarge(e)) {
        if (batch.length == 1) {
          await _setAsideUnsendable([batch.single.op]);
          // Reached the server, so the flush carries on to the batches behind
          // it; not acknowledged, so the cycle reports a partial failure.
          return const _BatchOutcome(
              reachedServer: true, allAcknowledged: false);
        }

        AppLogger.warning('The server refused a batch of ${batch.length} as too '
            'large; splitting it and sending the halves in order');

        final half = batch.length ~/ 2;
        final first = await _pushBatch(batch.sublist(0, half));
        if (!first.reachedServer) return first;

        final second = await _pushBatch(batch.sublist(half));
        return _BatchOutcome(
          reachedServer: second.reachedServer,
          allAcknowledged: first.allAcknowledged && second.allAcknowledged,
        );
      }

      return const _BatchOutcome(reachedServer: false, allAcknowledged: false);
    }

    var allAcknowledged = true;

    for (var i = 0; i < batch.length; i++) {
      final op = batch[i].op;

      if (i >= results.length) {
        // The server answered for fewer operations than we sent. Treat the rest
        // as unanswered rather than assuming success.
        await _db.syncQueueDao.releaseInProgress(op.id);
        allAcknowledged = false;
        continue;
      }

      final result = results[i] as Map<String, dynamic>;
      final handled = await _applyAcknowledgement(op, result, sentRevisions[op.id]);
      if (!handled) allAcknowledged = false;
    }

    return _BatchOutcome(reachedServer: true, allAcknowledged: allAcknowledged);
  }

  /// Whether [error] is the server refusing a body as too large.
  bool _isPayloadTooLarge(Object error) =>
      error is DioException && error.response?.statusCode == 413;

  /// What is written against work that could not be pushed at all.
  static const String _tooLargeError =
      'Too large for one sync push; set aside rather than retried';

  /// Takes operations the server can never accept off the queue, keeping them.
  ///
  /// Both halves matter. Off the queue, because an operation that is refused on
  /// arrival is refused on every arrival, and one left in line stops the flush
  /// in front of everything queued behind it - a single over-long note would
  /// mean no change the user makes afterwards ever syncs again. Kept, because
  /// the alternative to retrying forever is not deleting it: the payload is
  /// work only the user could have written, and it goes to the same recovery
  /// storage that holds the work of a revoked trip.
  ///
  /// The local row is deliberately left alone - still there, still dirty. The
  /// user's data has not gone anywhere; it is the push that could not be made.
  Future<void> _setAsideUnsendable(List<SyncQueueData> ops) async {
    for (final op in ops) {
      AppLogger.error(
          'Operation ${op.operation} ${op.entityType} ${op.entityId} is larger '
          'than one push may carry; setting it aside rather than retrying it '
          'forever');
    }

    final userId = AccountSession().userId;
    if (userId == null) {
      // Nothing to file it under. It still cannot block the queue - the flush
      // screens it out of every batch it plans - so the reason is recorded on
      // the row, and the next cycle, which will have a session, files it.
      for (final op in ops) {
        await _queue.markFailed(op.id, _tooLargeError);
      }
      return;
    }

    await UnsyncedWorkQuarantine(_db).quarantineOperations(
      userId,
      ops,
      reason: QuarantineReason.tooLarge,
    );
  }

  /// Applies one push result. Returns false when the operation still needs retrying.
  Future<bool> _applyAcknowledgement(
    SyncQueueData op,
    Map<String, dynamic> result,
    DateTime? sentRevision,
  ) async {
    final status = result['status'] as String? ?? PushResultStatus.error;

    return _db.transaction(() async {
      // Re-read inside the transaction: the user may have edited the record
      // between the response arriving and this write.
      final currentRevision = await _currentRevision(op.entityType, op.entityId);

      // Anything still queued for this record is an edit made after this
      // operation was sent. That is exact, unlike a timestamp comparison: local
      // revisions are stored to the second, so a quick follow-up edit can share
      // a timestamp with the push it followed.
      final queuedForEntity =
          await _db.syncQueueDao.getForEntity(op.entityType, op.entityId);
      final hasNewerQueuedOperation =
          queuedForEntity.any((row) => row.id != op.id);

      final outcome = resolveAcknowledgement(
        status: status,
        sentRevision: sentRevision ?? op.sentRevision,
        currentRevision: currentRevision,
        serverDataAvailable: result['data'] != null,
        hasNewerQueuedOperation: hasNewerQueuedOperation,
      );

      switch (outcome.action) {
        case AckAction.applyServerData:
          if (outcome.applyServerPayload) {
            // Applied through the acknowledgement path, which writes the row
            // even though it is dirty. The background upsert path deliberately
            // skips dirty rows, which is why server normalisation never used to
            // reach the very records being synchronised.
            await _applyAcknowledgedServerData(
              op.entityType,
              op.entityId,
              result['data'] as Map<String, dynamic>,
            );
          }
          if (outcome.clearDirtyFlag) {
            await _clearDirtyFlag(op.entityType, op.entityId);
          }
          await _db.syncQueueDao.resolveConflictsFor(op.entityType, op.entityId);

        case AckAction.keepNewerLocalEdit:
          AppLogger.info(
              'Acknowledgement for ${op.entityType} ${op.entityId} is stale; '
              'a newer local edit is queued and keeps its pending state');

        case AckAction.recordConflict:
          await _db.syncQueueDao.recordConflict(SyncConflictsCompanion(
            id: Value('${op.entityType}:${op.entityId}'),
            entityType: Value(op.entityType),
            entityId: Value(op.entityId),
            localPayload: Value(op.payload),
            serverPayload: Value(jsonEncode(result['server_version'] ?? {})),
            detectedAt: Value(DateTime.now()),
            // The place in line of the operation that was refused. Anything
            // queued after this is an edit the user made later, and resolution
            // must not erase it. Recorded as a sequence because two edits in
            // one second are indistinguishable by timestamp.
            detectedSequence: Value(op.sequence),
            isResolved: const Value(false),
          ));
          AppLogger.warning(
              'Conflict on ${op.entityType} ${op.entityId}; both versions kept');

        case AckAction.retry:
          final error = result['error'] as String? ?? 'Unknown error';
          await _queue.markFailed(op.id, error);
          return false;
      }

      if (outcome.removeQueueEntry) {
        await _queue.markCompleted(op.id);
      }
      return true;
    });
  }

  /// Returns an in-flight operation to the queue once it has clearly been
  /// abandoned, for example by the process being killed mid-push.
  Future<void> _recoverStuckOperations() async {
    final inFlight = await _db.syncQueueDao.getInProgress();
    if (inFlight.isEmpty) return;

    final now = DateTime.now();
    for (final op in inFlight) {
      if (!isStuckInFlight(sentAt: op.sentAt, now: now)) continue;

      AppLogger.warning(
          'Recovering stuck sync operation ${op.operation} '
          '${op.entityType} ${op.entityId}');
      await _db.syncQueueDao.releaseInProgress(op.id);
    }
  }

  /// Drops cached trips the server no longer lists as readable.
  ///
  /// The incremental access-removal event only covers revocations that happened
  /// since the last sync. A share revoked before revocation started leaving a
  /// marker produced no event at all, so the only way to find it is to compare
  /// the whole cache against the authoritative list.
  ///
  /// Trips with unsynced local work are deliberately kept. Losing access to
  /// somebody else's trip must not destroy the user's own unsent edits, and a
  /// locally created trip the server has not seen yet is legitimately absent
  /// from the list.
  Future<void> _reconcileReadableTrips(Set<String> readableTripIds) async {
    final cached = await _db.tripsDao.getAll();
    if (cached.isEmpty) return;

    for (final trip in cached) {
      if (readableTripIds.contains(trip.id)) continue;

      // Never pushed, so the server could not list it. Not a revocation.
      if (trip.isLocalOnly) continue;

      AppLogger.info('Trip ${trip.id} is no longer readable; evicting');
      await _evictRevokedTrip(trip.id);
    }
  }

  /// Removes a trip the server says this device may no longer see.
  ///
  /// Everything under it goes too: a revoked collaborator keeping a readable
  /// cached copy of the itinerary, budget and documents is the whole problem this
  /// solves. The trip leaves normal browsing unconditionally - having unsent edits
  /// is not a reason to keep showing content the user no longer has access to.
  ///
  /// Those edits are not destroyed, though. They are moved into this account's
  /// recovery storage first, so the work survives even though the trip does not.
  /// Deleting them because the trip went away would throw away something only the
  /// user could have recreated.
  ///
  /// This cannot reach a device that stays offline; it takes effect on reconnect.
  Future<void> _evictRevokedTrip(String tripId) async {
    AppLogger.info('Access removed for trip $tripId; evicting cached content');

    final userId = AccountSession().userId;
    if (userId != null) {
      await UnsyncedWorkQuarantine(_db).quarantineTrip(userId, tripId);
    }

    // Anything still queued after the quarantine has been preserved or was never
    // the user's to keep; it would be refused by the server either way.
    for (final entityType in const [
      'activity',
      'expense',
      'packing_item',
      'document',
      'memory',
    ]) {
      await _db.syncQueueDao.removeForTripPayload(entityType, tripId);
    }
    await _db.syncQueueDao.removeForEntity('trip', tripId);

    await _db.activitiesDao.deleteByTrip(tripId);
    await _db.expensesDao.deleteByTrip(tripId);
    await _db.packingDao.deleteByTrip(tripId);
    await _db.documentsDao.deleteByTrip(tripId);
    await _db.memoriesDao.deleteByTrip(tripId);
    await _db.tripsDao.hardDelete(tripId);
  }

  /// The local row's current `updatedAt`, or null when it no longer exists.
  Future<DateTime?> _currentRevision(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        return (await _db.tripsDao.getById(entityId))?.updatedAt;
      case 'activity':
        return (await _db.activitiesDao.getById(entityId))?.updatedAt;
      case 'expense':
        return (await _db.expensesDao.getById(entityId))?.updatedAt;
      case 'memory':
        return (await _db.memoriesDao.getById(entityId))?.updatedAt;
      case 'document':
        return (await _db.documentsDao.getById(entityId))?.updatedAt;
      case 'packing_item':
        return (await _db.packingDao.getById(entityId))?.updatedAt;
      case 'template':
        return (await _db.templatesDao.getById(entityId))?.updatedAt;
      default:
        return null;
    }
  }

  Future<void> _pullChanges() async {
    // Captured before the request, because everything below writes to a
    // database that belongs to whichever account is signed in at the time - not
    // to the one that asked. A full pull is the largest single body of data the
    // app ever writes, so this is the worst thing to get wrong.
    final scope = AccountSession().capture();

    final lastSyncAt = await _db.syncQueueDao.getLastSyncAt();
    AppLogger.info('Pulling changes since: ${lastSyncAt ?? "beginning"}');

    try {
      final response = await _dio.post(
        '${ApiConfig.sync}/pull',
        data: {'since': lastSyncAt},
      );

      final data = response.data as Map<String, dynamic>;
      final serverTime = data['server_time'] as String;
      final changes = data['changes'] as Map<String, dynamic>;

      // Access the server says this device no longer has. Evicted before the
      // upserts so a revoked trip cannot be written back in by the same cycle.
      final accessRemoved =
          (data['access_removed_trip_ids'] as List?)?.cast<String>() ?? const [];

      // Present only on a full sync: the authoritative set of trips this account
      // may read. Used to find content whose share was revoked before revocation
      // left a marker, which no incremental event can describe.
      final readableTripIds =
          (data['readable_trip_ids'] as List?)?.cast<String>();

      var applied = false;

      await _db.transaction(() async {
        // Checked here rather than before the transaction, so the check and the
        // writes are serialised against the clear that runs on sign-out. Passing
        // a check outside the transaction still leaves room for the account to
        // change between the check and the commit.
        if (!scope.isCurrent) {
          AppLogger.warning(
              'Pull answered after its session ended; nothing written');
          return;
        }

        for (final tripId in accessRemoved) {
          await _evictRevokedTrip(tripId);
        }

        if (readableTripIds != null) {
          await _reconcileReadableTrips(readableTripIds.toSet());
        }

        await _processEntityChanges('trips', changes['trips'], _upsertTrip, _deleteTrip);
        await _processEntityChanges('activities', changes['activities'], _upsertActivity, _deleteEntity);
        await _processEntityChanges('expenses', changes['expenses'], _upsertExpense, _deleteEntity);
        await _processEntityChanges('memories', changes['memories'], _upsertMemory, _deleteEntity);
        await _processEntityChanges('documents', changes['documents'], _upsertDocument, _deleteEntity);
        await _processEntityChanges('packing_items', changes['packing_items'], _upsertPackingItem, _deleteEntity);
        await _processEntityChanges('trip_shares', changes['trip_shares'], _upsertTripShare, _deleteEntity);
        await _processEntityChanges('templates', changes['templates'], _upsertTemplate, _deleteEntity);

        applied = true;
      });

      if (!applied) return;

      // The watermark too: recording this pull against the next account would
      // make the app skip changes it has never actually seen.
      await scope.write(() => _db.syncQueueDao.setLastSyncAt(serverTime));
      AppLogger.info('Pull completed, server time: $serverTime');
    } catch (e) {
      AppLogger.error('Pull failed: $e');
      rethrow;
    }
  }

  Future<void> _processEntityChanges(
    String entityType,
    Map<String, dynamic>? changes,
    Future<void> Function(Map<String, dynamic>) upsertFn,
    Future<void> Function(String entityType, String id) deleteFn,
  ) async {
    if (changes == null) return;

    final upserted = (changes['upserted'] as List?) ?? [];
    final deleted = (changes['deleted'] as List?) ?? [];

    for (final item in upserted) {
      await upsertFn(item as Map<String, dynamic>);
    }

    for (final item in deleted) {
      final id = (item as Map<String, dynamic>)['id'] as String;
      await deleteFn(entityType, id);
    }
  }

  // ─── Upsert Handlers ─────────────────────────────────────────

  Future<void> _upsertTrip(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.tripsDao.getById(id);
    // A background pull must not clobber an unsynced local edit. An acknowledged
    // push is the exception: it is the response for this very row, so it carries
    // the server's normalisation and identity for it.
    if (!force && existing != null && existing.isDirty) return;

    await _db.tripsDao.upsert(LocalTripsCompanion(
      id: Value(id),
      userId: Value(data['user_id'] as String),
      title: Value(data['title'] as String),
      description: Value(data['description'] as String?),
      coverImageUrl: Value(data['cover_image_url'] as String?),
      startDate: Value(data['start_date'] as String),
      endDate: Value(data['end_date'] as String?),
      status: Value(data['status'] as String),
      tags: Value(jsonEncode(data['tags'] ?? [])),
      budget: Value((data['budget'] as num?)?.toDouble()),
      displayCurrency: Value(data['display_currency'] as String? ?? 'USD'),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertActivity(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.activitiesDao.getById(id);
    if (!force && existing != null && existing.isDirty) return;

    await _db.activitiesDao.upsert(LocalActivitiesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      title: Value(data['title'] as String),
      description: Value(data['description'] as String?),
      scheduledTime: Value(data['scheduled_time'] as String),
      category: Value(data['category'] as String),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      latitude: Value((data['latitude'] as num?)?.toDouble()),
      longitude: Value((data['longitude'] as num?)?.toDouble()),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertExpense(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.expensesDao.getById(id);
    if (!force && existing != null && existing.isDirty) return;

    await _db.expensesDao.upsert(LocalExpensesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      title: Value(data['title'] as String),
      amount: Value((data['amount'] as num).toDouble()),
      currency: Value(data['currency'] as String? ?? 'USD'),
      category: Value(data['category'] as String),
      date: Value(data['date'] as String),
      notes: Value(data['notes'] as String?),
      convertedAmount: Value((data['converted_amount'] as num?)?.toDouble()),
      convertedCurrency: Value(data['converted_currency'] as String?),
      exchangeRate: Value((data['exchange_rate'] as num?)?.toDouble()),
      convertedAt: Value(data['converted_at'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertMemory(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.memoriesDao.getById(id);
    if (!force && existing != null && existing.isDirty) return;

    await _db.memoriesDao.upsert(LocalMemoriesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      mediaItems: Value(jsonEncode(data['media_items'] ?? [])),
      photoUrl: Value(data['photo_url'] as String?),
      location: Value(data['location'] as String?),
      latitude: Value((data['latitude'] as num?)?.toDouble()),
      longitude: Value((data['longitude'] as num?)?.toDouble()),
      caption: Value(data['caption'] as String?),
      takenAt: Value(data['taken_at'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.now()),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertDocument(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.documentsDao.getById(id);
    if (!force && existing != null && existing.isDirty) return;

    await _db.documentsDao.upsert(LocalDocumentsCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      type: Value(data['type'] as String),
      name: Value(data['name'] as String),
      files: Value(jsonEncode(data['files'] ?? [])),
      fileUrl: Value(data['file_url'] as String?),
      fileType: Value(data['file_type'] as String?),
      notes: Value(data['notes'] as String?),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertPackingItem(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.packingDao.getById(id);
    if (!force && existing != null && existing.isDirty) return;

    await _db.packingDao.upsert(LocalPackingItemsCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      name: Value(data['name'] as String),
      category: Value(data['category'] as String),
      isPacked: Value(data['is_packed'] as bool? ?? false),
      quantity: Value(data['quantity'] as int? ?? 1),
      notes: Value(data['notes'] as String?),
      sortOrder: Value(data['sort_order'] as int? ?? 0),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  Future<void> _upsertTripShare(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.sharesDao.getById(id);
    // A background pull must not clobber an unsynced local edit. An acknowledged
    // push is the exception: it is the response for this very row, so it carries
    // the server's normalisation and identity for it.
    if (!force && existing != null && existing.isDirty) return;

    final companion = LocalTripSharesCompanion(
      id: Value(id),
      tripId: Value(data['trip_id'] as String),
      ownerId: Value(data['owner_id'] as String),
      sharedWithEmail: Value(data['shared_with_email'] as String),
      sharedWithUserId: Value(data['shared_with_user_id'] as String?),
      permission: Value(data['permission'] as String),
      inviteCode: Value(data['invite_code'] as String),
      status: Value(data['status'] as String),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      acceptedAt: Value(data['accepted_at'] as String?),
      inviteExpiresAt: Value(data['invite_expires_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    );
    await _db.sharesDao.upsert(companion);
  }

  Future<void> _upsertTemplate(Map<String, dynamic> data, {bool force = false}) async {
    final id = data['id'] as String;
    final existing = await _db.templatesDao.getById(id);
    // A background pull must not clobber an unsynced local edit. An acknowledged
    // push is the exception: it is the response for this very row, so it carries
    // the server's normalisation and identity for it.
    if (!force && existing != null && existing.isDirty) return;

    await _db.templatesDao.upsert(LocalTemplatesCompanion(
      id: Value(id),
      userId: Value(data['user_id'] as String),
      name: Value(data['name'] as String),
      description: Value(data['description'] as String?),
      structureJson: Value(jsonEncode(data['structure_json'] ?? {})),
      isPublic: Value(data['is_public'] as bool? ?? false),
      category: Value(data['category'] as String?),
      useCount: Value(data['use_count'] as int? ?? 0),
      createdAt: Value(DateTime.parse(data['created_at'] as String)),
      updatedAt: Value(DateTime.parse(data['updated_at'] as String)),
      // Verbatim: see model_converters. The base version sent back to the
      // server has to be byte-identical to what it issued.
      serverRevision: Value(data['updated_at'] as String?),
      isDirty: const Value(false),
      isLocalOnly: const Value(false),
      isDeleted: const Value(false),
    ));
  }

  // ─── Delete Handlers ──────────────────────────────────────────

  Future<void> _deleteTrip(String entityType, String id) async {
    await _db.tripsDao.hardDelete(id);
  }

  Future<void> _deleteEntity(String entityType, String id) async {
    switch (entityType) {
      case 'activities':
        await _db.activitiesDao.hardDelete(id);
      case 'expenses':
        await _db.expensesDao.hardDelete(id);
      case 'memories':
        await _db.memoriesDao.hardDelete(id);
      case 'documents':
        await _db.documentsDao.hardDelete(id);
      case 'packing_items':
        await _db.packingDao.hardDelete(id);
      case 'trip_shares':
        await _db.sharesDao.hardDelete(id);
      case 'templates':
        await _db.templatesDao.hardDelete(id);
    }
  }

  /// Applies the server's version of a conflicted record, then clears it.
  ///
  /// Recording a conflict deliberately writes **nothing** to the record - both
  /// versions are preserved and the local row keeps the user's edit, so nothing
  /// is lost while they decide. That means choosing "keep the server version"
  /// has real work to do: the local row still holds the local edit until this
  /// runs.
  ///
  /// The conflict is cleared only after the write succeeds. A failed write that
  /// still dismissed the conflict would lose the user's choice *and* the record
  /// of the disagreement, leaving them with the edit they rejected and no way
  /// back to it.
  ///
  /// Returns false when the server payload cannot be applied, leaving the
  /// conflict exactly as it was.
  Future<bool> resolveConflictWithServerVersion(SyncConflict conflict) async {
    try {
      final decoded = jsonDecode(conflict.serverPayload);

      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        AppLogger.error(
            'Conflict ${conflict.id} has no usable server version to apply');
        return false;
      }

      return await _db.transaction(() async {
        // Edits made *after* the conflict was detected are not part of what the
        // user is choosing between. "Use server version" discards the version
        // that was refused; it is not permission to erase what they typed
        // afterwards, which they may not even associate with this conflict.
        //
        // Read inside the transaction, with the write, so an edit landing
        // between the two is not silently overwritten.
        final all = await _db.syncQueueDao
            .getForEntity(conflict.entityType, conflict.entityId);

        // Compared by queue sequence, not by time. `detectedAt` is a Drift
        // DateTime - unix seconds - so an edit made in the same second as the
        // conflict would be judged by luck, and losing that coin toss means
        // silently discarding the thing the user most recently typed.
        //
        // A zero sequence means the conflict predates the column; the timestamp
        // is the only thing available for those, and it is used as a fallback
        // rather than pretending they are all newer or all older.
        // Sequence when both sides have one, timestamp otherwise. A zero means
        // "unknown", not "older": treating an unsequenced operation as older
        // would silently discard it, which is the failure this is here to
        // prevent. Rows predating the column were numbered by the migration, so
        // in practice only a hand-built row reaches the fallback.
        bool isNewer(SyncQueueData op) =>
            conflict.detectedSequence > 0 && op.sequence > 0
                ? op.sequence > conflict.detectedSequence
                : op.createdAt.isAfter(conflict.detectedAt);

        final newer = all.where(isNewer).toList()
          ..sort((a, b) => a.sequence != b.sequence
              ? a.sequence.compareTo(b.sequence)
              : a.createdAt.compareTo(b.createdAt));

        // The server's copy becomes the base, then anything newer is laid back
        // over it in the order it was made. A queued operation is a partial
        // patch, so merging is what re-applying one means.
        final merged = <String, dynamic>{...decoded};
        for (final op in newer) {
          try {
            final patch = jsonDecode(op.payload);
            if (patch is Map<String, dynamic>) merged.addAll(patch);
          } catch (_) {
            // An unreadable payload is handled by the queue itself; it must not
            // stop the resolution the user asked for.
          }
        }

        await _applyAcknowledgedServerData(
          conflict.entityType,
          conflict.entityId,
          merged,
        );

        if (newer.isEmpty) {
          // Nothing outstanding. The local edit is superseded by the user's own
          // choice, so the row is no longer dirty - leaving it dirty would
          // re-push the edit they just discarded and start the same argument
          // again.
          await _clearDirtyFlag(conflict.entityType, conflict.entityId);
        } else {
          // The forced upsert writes the server's copy as a clean row, which is
          // right for an acknowledgement and wrong here: the edits laid back
          // over it have not been sent. Left clean they would never be pushed
          // and would be overwritten by the next pull.
          await _markDirty(conflict.entityType, conflict.entityId);

          AppLogger.info(
              'Kept ${newer.length} edit(s) made after conflict '
              '${conflict.id} was detected');
        }

        await _db.syncQueueDao.resolveConflict(conflict.id);
        return true;
      });
    } catch (e, st) {
      AppLogger.error('Could not apply the server version', e, st);
      return false;
    }
  }

  /// Clears a conflict the user has finished with, without changing the record.
  ///
  /// Used after the local version has been exported, where the *record* keeps
  /// whatever it already held and only the outstanding disagreement goes away.
  Future<bool> dismissConflict(String conflictId) async {
    try {
      await _db.syncQueueDao.resolveConflict(conflictId);
      return true;
    } catch (e, st) {
      AppLogger.error('Could not dismiss a conflict', e, st);
      return false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Writes the server's copy of a record that we just pushed.
  ///
  /// Forces the write past the dirty guard: the background pull path skips dirty
  /// rows to protect unsynced edits, which meant server normalisation never
  /// reached the very records being synchronised. The caller has already
  /// established that the acknowledged revision is still the current one.
  Future<void> _applyAcknowledgedServerData(
    String entityType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    final payload = {...data, 'id': entityId};
    switch (entityType) {
      case 'trip':
        await _upsertTrip(payload, force: true);
      case 'activity':
        await _upsertActivity(payload, force: true);
      case 'expense':
        await _upsertExpense(payload, force: true);
      case 'memory':
        await _upsertMemory(payload, force: true);
      case 'document':
        await _upsertDocument(payload, force: true);
      case 'packing_item':
        await _upsertPackingItem(payload, force: true);
      case 'template':
        await _upsertTemplate(payload, force: true);
      case 'trip_share':
        await _upsertTripShare(payload, force: true);
    }
  }

  /// Marks a record as carrying unsent changes again.
  ///
  /// The counterpart to [_clearDirtyFlag], for the one case that needs it: a
  /// conflict resolved onto a record that still has newer edits queued.
  Future<void> _markDirty(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        await _db.tripsDao.markDirty(entityId);
      case 'activity':
        await _db.activitiesDao.markDirty(entityId);
      case 'expense':
        await _db.expensesDao.markDirty(entityId);
      case 'memory':
        await _db.memoriesDao.markDirty(entityId);
      case 'document':
        await _db.documentsDao.markDirty(entityId);
      case 'packing_item':
        await _db.packingDao.markDirty(entityId);
      case 'template':
        await _db.templatesDao.markDirty(entityId);
      case 'trip_share':
        await _db.sharesDao.markDirty(entityId);
    }
  }

  Future<void> _clearDirtyFlag(String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        await _db.tripsDao.clearDirty(entityId);
      case 'activity':
        await _db.activitiesDao.clearDirty(entityId);
      case 'expense':
        await _db.expensesDao.clearDirty(entityId);
      case 'memory':
        await _db.memoriesDao.clearDirty(entityId);
      case 'document':
        await _db.documentsDao.clearDirty(entityId);
      case 'packing_item':
        await _db.packingDao.clearDirty(entityId);
      case 'template':
        await _db.templatesDao.clearDirty(entityId);
      case 'trip_share':
        await _db.sharesDao.clearDirty(entityId);
    }
  }

  /// Tears the service down for good.
  ///
  /// Only for application shutdown. Signing out uses [stopSession], which leaves
  /// the state stream usable for the next account.
  Future<void> dispose() async {
    await stopSession();
    await _stateController.close();
  }

  /// Flushes the queue exactly as a sync cycle does.
  ///
  /// The push half is what batching changed, and driving it through
  /// [performSync] would drag a pull and a connectivity session in with it -
  /// neither of which has anything to say about how the outbox is split.
  @visibleForTesting
  Future<bool> pushQueueForTesting() => _pushChanges();
}

/// One queued operation, the change the server will be sent for it, and what
/// that change weighs on the wire.
///
/// The encoding is done once, when the batches are planned, and the same map is
/// handed to Dio. Encoding twice would leave the measurement and the request
/// free to disagree.
class _PushCandidate {
  _PushCandidate(this.op, this.change)
      : encodedBytes = encodedChangeBytes(change);

  final SyncQueueData op;
  final Map<String, dynamic> change;
  final int encodedBytes;
}

/// What became of one batch.
///
/// [reachedServer] and [allAcknowledged] are separate because they call for
/// different things. A batch that never reached the server stops the flush: what
/// follows it may depend on it. A batch that was answered with some operations
/// refused does not - those are already back in the queue, and the operations
/// behind them are no worse off for being sent.
class _BatchOutcome {
  const _BatchOutcome({
    required this.reachedServer,
    required this.allAcknowledged,
  });

  final bool reachedServer;
  final bool allAcknowledged;
}
