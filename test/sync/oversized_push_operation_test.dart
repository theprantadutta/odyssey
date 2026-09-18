import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/core/session/unsynced_work_quarantine.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_push_limits.dart';
import 'package:odyssey/src/core/sync/sync_queue_service.dart';
import 'package:odyssey/src/core/sync/sync_service.dart';

/// One operation too big for any push, and the queue behind it.
///
/// Chunking the outbox is what stops the client building a batch the server
/// refuses - but chunking has nothing to offer a single operation that is over
/// the limit on its own. A request carrying only that operation is the smallest
/// one that can carry it, and it is still too large, so `POST /sync/push`
/// answers 413. A 413 is a verdict on the body: the next attempt sends the same
/// bytes and is refused in the same way, and the one after that.
///
/// That is the failure these tests exist for, and it is not a slow sync. It is a
/// queue that never drains again. The flush stops at a batch that did not land,
/// so every change the user makes afterwards queues up behind an operation that
/// can never be delivered - a trip renamed, an expense logged, a memory written,
/// none of them ever reaching the server, and the app reporting only that sync
/// did not finish. One over-long note, and the device is offline forever.
///
/// Three things have to be true of the fix, and each is asserted separately
/// below, because two of the three are satisfied by simply deleting the
/// operation - which is the other way to lose the user's work:
///
///   * the operation is not sent again, ever;
///   * the operations behind it go through;
///   * what could not be sent is kept, durably, rather than dropped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late _ServerStub server;

  const user = 'user-a';
  final when = DateTime.utc(2026, 5, 1, 10);

  setUpAll(() {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    DioClient().init();
    // The auth interceptor would try to refresh a token against a server that
    // does not exist. What is being measured is which operations are sent.
    DioClient().dio.interceptors.clear();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_oversized_');
    db = AppDatabase.forTesting(
        NativeDatabase(File('${tempDir.path}/odyssey.sqlite')));
    DatabaseService.overrideForTesting(db);

    // Recovery storage is per account, and a push only ever happens inside a
    // session, so this is the ordinary state rather than a convenience.
    AccountSession().begin(user);

    server = _ServerStub();
    DioClient().dio.httpClientAdapter = server;
  });

  tearDown(() async {
    AccountSession().end();
    DatabaseService.clearOverrideForTesting();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedTrip(String id) =>
      db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
            id: Value(id),
            userId: const Value(user),
            title: Value('Trip $id'),
            startDate: const Value('2026-05-01'),
            status: const Value('planned'),
            createdAt: Value(when),
            updatedAt: Value(when),
            isDirty: const Value(true),
          ));

  Future<void> queueTrip(String id, {String? notes}) async {
    await seedTrip(id);
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: id,
      operation: SyncOp.create,
      payload: {
        'id': id,
        'title': 'Trip $id',
        'description': ?notes,
      },
    );
  }

  /// A description that makes one operation larger than a whole push body.
  ///
  /// Sized from the limit rather than from a round number, so retuning the
  /// policy moves this with it.
  String tooLongToSend() => 'x' * (kMaxPushBodyBytes + 1024);

  /// The entity ids in every request, in the order they were sent.
  List<String> sentIds() => server.requests
      .expand((batch) => batch.map((c) => c['entity_id'] as String))
      .toList();

  Future<List<QuarantinedOperation>> setAside() =>
      (db.select(db.quarantinedOperations)
            ..where((o) => o.reason.equals(QuarantineReason.tooLarge)))
          .get();

  // ------------------------------------------------- refused before it is sent

  group('an operation larger than one push body', () {
    test('is recognised as unsendable rather than merely over the batch budget',
        () {
      // The distinction the whole fix rests on. An operation that overflows the
      // batch being filled starts a new batch and is sent; one that overflows an
      // empty batch has no request that can carry it.
      expect(exceedsPushBodyLimit(kMaxPushBodyBytes ~/ 2), isFalse);
      expect(exceedsPushBodyLimit(kMaxPushBodyBytes + 1), isTrue);

      // The envelope and the punctuation count, because the server measures the
      // body and not the element. An operation of exactly the limit does not fit
      // in a body of exactly the limit.
      expect(exceedsPushBodyLimit(kMaxPushBodyBytes), isTrue);
    });

    test('is never put on the wire', () async {
      await queueTrip('huge', notes: tooLongToSend());

      await SyncService().pushQueueForTesting();

      expect(server.requests, isEmpty,
          reason: 'a request the server can only refuse was sent anyway');
    });

    test('does not stop the operations queued behind it', () async {
      // The order that matters: the unsendable operation is in front. Before the
      // fix the flush stopped here and neither of the two behind it was ever
      // sent, on this cycle or on any later one.
      await queueTrip('huge', notes: tooLongToSend());
      await queueTrip('behind-1');
      await queueTrip('behind-2');

      await SyncService().pushQueueForTesting();

      expect(sentIds(), ['behind-1', 'behind-2']);
      expect(await db.syncQueueDao.getPending(), isEmpty,
          reason: 'the queue behind the unsendable operation must drain');
    });

    test('is not re-sent on the next sync, or the one after that', () async {
      await queueTrip('huge', notes: tooLongToSend());
      await queueTrip('behind');

      for (var cycle = 0; cycle < 3; cycle++) {
        await SyncService().pushQueueForTesting();
      }

      // Three cycles, one operation sent - the one that could be. The failure
      // being guarded against is an identical refused request on every cycle
      // forever, which is what a queue that never drains looks like from the
      // server's side.
      expect(sentIds(), ['behind']);
      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await db.syncQueueDao.getInProgress(), isEmpty);
    });

    test('is kept in recovery storage, not dropped', () async {
      final note = tooLongToSend();
      await queueTrip('huge', notes: note);

      await SyncService().pushQueueForTesting();

      final kept = await setAside();
      expect(kept, hasLength(1),
          reason: 'the only copy of work the user typed was deleted');

      final row = kept.single;
      expect(row.userId, user);
      expect(row.entityType, 'trip');
      expect(row.entityId, 'huge');
      expect(row.operation, SyncOp.create);

      // The payload is preserved whole. A record that says an operation failed
      // without saying what was in it is a log line, not recovery.
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      expect(payload['description'], note);
    });

    test('is not restored to the queue when the account signs back in',
        () async {
      await queueTrip('huge', notes: tooLongToSend());
      await SyncService().pushQueueForTesting();

      // Restoring it would put the identical body back in front of the queue and
      // start the stall again on the next cycle. Recovery storage holds it; only
      // sign-out work comes back.
      final restored = await UnsyncedWorkQuarantine(db).restore(user);

      expect(restored, 0);
      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await setAside(), hasLength(1));
    });

    test('leaves the local record on screen and still dirty', () async {
      await queueTrip('huge', notes: tooLongToSend());

      await SyncService().pushQueueForTesting();

      // What could not be sent is the push. The user's trip is still their trip:
      // removing the row, or marking it clean, would each be a way of telling
      // them their unsent work was saved.
      final trip = await db.tripsDao.getById('huge');
      expect(trip, isNotNull);
      expect(trip!.isDirty, isTrue,
          reason: 'a record whose change never reached the server is not clean');
    });

    test('reports the cycle as unclean rather than silently succeeding',
        () async {
      await queueTrip('huge', notes: tooLongToSend());
      await queueTrip('behind');

      final clean = await SyncService().pushQueueForTesting();

      // Everything that could be sent was, and the cycle still must not read as
      // idle: one of the user's changes did not land.
      expect(clean, isFalse);
    });

    test('a queue of only sendable operations is unaffected', () async {
      // The control. Screening for unsendable operations must not cost the
      // ordinary case a request or an operation.
      await queueTrip('t1');
      await queueTrip('t2');

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isTrue);
      expect(server.requests, hasLength(1));
      expect(sentIds(), ['t1', 't2']);
      expect(await setAside(), isEmpty);
    });
  });

  // ------------------------------------------- refused after it has been sent

  group('a batch the server itself refuses with 413', () {
    // Reachable only if the limits mirrored on the two sides drift apart, since
    // the client sizes every batch from the server's own numbers. It is still
    // the case that must not stall: a refusal the client did not predict is
    // exactly the one it would otherwise retry forever.

    test('a single refused operation is set aside and the flush carries on',
        () async {
      server.refuseEntityId = 'unwelcome';

      await queueTrip('ahead');
      await queueTrip('unwelcome');
      await queueTrip('behind');

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isFalse);

      // Both neighbours landed, in order, even though the refusal sat between
      // them.
      final applied = server.applied;
      expect(applied, ['ahead', 'behind']);

      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await db.syncQueueDao.getInProgress(), isEmpty);

      final kept = await setAside();
      expect(kept.single.entityId, 'unwelcome');
    });

    test('a refused batch is split instead of being retried whole', () async {
      // A server that will not take more than two operations at a time, against
      // a client that believes it may send five hundred.
      server.maxOperationsPerRequest = 2;

      for (var i = 0; i < 5; i++) {
        await queueTrip('t$i');
      }

      final clean = await SyncService().pushQueueForTesting();

      // Everything arrived, in queue order, and nothing was set aside: the whole
      // batch was sendable, just not in one request.
      expect(clean, isTrue);
      expect(server.applied, ['t0', 't1', 't2', 't3', 't4']);
      expect(await setAside(), isEmpty);
      expect(await db.syncQueueDao.getPending(), isEmpty);

      // And the retries were halvings, not repetitions. A client that re-sent
      // the refused body would show the same five-operation request twice.
      final refused = server.requests.where((batch) => batch.length > 2);
      expect(refused.map((batch) => batch.length).toList(), [5, 3],
          reason: 'an identical refused request was sent more than once');
    });

    test('an ordinary failure still stops the flush', () async {
      // The distinction being drawn. A 503 may well succeed next time and the
      // batches behind it may depend on the one that failed, so the flush stops
      // and everything stays queued. Only a refusal is treated as final.
      server.failWith = 503;

      await queueTrip('t1');
      await queueTrip('t2');

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isFalse);
      expect(server.requests, hasLength(1));
      expect(await db.syncQueueDao.getPending(), hasLength(2));
      expect(await setAside(), isEmpty);
    });
  });
}

/// A stand-in for `POST /sync/push` that can refuse what it is sent.
class _ServerStub implements HttpClientAdapter {
  /// Every request's changes, in the order they were sent.
  final requests = <List<Map<String, dynamic>>>[];

  /// The entity ids the stub answered `ok` for.
  final applied = <String>[];

  /// Refuses any request carrying this entity, however small.
  String? refuseEntityId;

  /// Refuses any request carrying more operations than this.
  int? maxOperationsPerRequest;

  /// Fails every request with this status, whatever it carries.
  int? failWith;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data as Map<String, dynamic>;
    final changes = (body['changes'] as List).cast<Map<String, dynamic>>();

    requests.add(changes);

    if (failWith != null) {
      return _error(failWith!, 'unavailable');
    }

    final tooMany = maxOperationsPerRequest != null &&
        changes.length > maxOperationsPerRequest!;
    final unwelcome = refuseEntityId != null &&
        changes.any((c) => c['entity_id'] == refuseEntityId);

    if (tooMany || unwelcome) {
      // What the endpoint answers an over-sized body with, and the reason a
      // retry of it is pointless: the verdict is on the body.
      return _error(413, 'payload too large');
    }

    for (final change in changes) {
      applied.add(change['entity_id'] as String);
    }

    return ResponseBody.fromString(
      jsonEncode({
        'server_time': DateTime.now().toUtc().toIso8601String(),
        'results': [
          for (final change in changes)
            {
              'entity_type': change['entity_type'],
              'entity_id': change['entity_id'],
              'status': 'ok',
            },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  ResponseBody _error(int status, String message) => ResponseBody.fromString(
        jsonEncode({'error': message}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
