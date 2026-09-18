import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../services/logger_service.dart';

/// Recovery storage for work an account made but never synced.
///
/// Signing out clears the local database. Keeping only the queue is not enough:
/// a queued operation is usually a partial patch, so without the row it patches
/// the restored edit is invisible to the user, and a restored child has no
/// parent. This preserves the operations, the records they act on, and the
/// unresolved conflicts - which the queue cannot lead to at all, because
/// acknowledging a conflict removes its queue row.
///
/// Two kinds of work live here, and the difference decides what happens next:
///
///   * **[QuarantineReason.signOut]** - the account's own work, set aside
///     because the database was about to be emptied. Restored into the ordinary
///     tables when that account signs back in.
///
///   * **[QuarantineReason.revoked]** - work belonging to a trip this account
///     may no longer see. Kept, because the user made it and only they could
///     recreate it, but **never restored into the ordinary tables**: the trip
///     was evicted precisely so it would leave normal browsing, and restoring
///     its rows would quietly put it back. It is read through [revokedWork] and
///     surfaced as recovery, not as a trip.
class UnsyncedWorkQuarantine {
  const UnsyncedWorkQuarantine(this._db);

  final AppDatabase _db;

  /// Entity types that belong to a trip, so the parent is preserved with them.
  static const Set<String> _tripScoped = {
    'activity',
    'expense',
    'packing_item',
    'document',
    'memory',
  };

  /// Preserves every queued operation and the rows it touches.
  ///
  /// Returns how many operations were set aside.
  Future<int> quarantine(String userId) async {
    return _db.transaction(() async {
      final operations = await _db.syncQueueDao.getAllOperations();

      // Conflicts are found in their own right, not through the queue. An
      // acknowledged conflict has already had its queue row removed, so an
      // account whose only unsynced work is a conflict used to look, from here,
      // like an account with nothing to preserve - and the clear that followed
      // took both versions of their edit with it.
      final conflicts = await _db.syncQueueDao.getUnresolvedConflicts();

      if (operations.isEmpty && conflicts.isEmpty) return 0;

      // Snapshot the records first: once the queue is copied the database is
      // cleared, and anything not captured here is gone.
      final snapshots = <String, QuarantinedRecordsCompanion>{};

      for (final op in operations) {
        await _captureRecord(snapshots, userId, op.entityType, op.entityId,
            QuarantineReason.signOut);

        // Preserve the parent as well, so a restored child is not orphaned.
        if (_tripScoped.contains(op.entityType)) {
          final tripId = await _tripIdFor(op.entityType, op.entityId) ??
              _tripIdFromPayload(op.payload);
          if (tripId != null) {
            await _captureRecord(
                snapshots, userId, 'trip', tripId, QuarantineReason.signOut);
          }
        }
      }

      // The conflicted row itself, and its parent, on the same terms.
      for (final conflict in conflicts) {
        await _captureRecord(snapshots, userId, conflict.entityType,
            conflict.entityId, QuarantineReason.signOut);

        if (_tripScoped.contains(conflict.entityType)) {
          final tripId =
              await _tripIdFor(conflict.entityType, conflict.entityId);
          if (tripId != null) {
            await _captureRecord(
                snapshots, userId, 'trip', tripId, QuarantineReason.signOut);
          }
        }
      }

      if (snapshots.isNotEmpty) {
        await _db.batch((b) => b.insertAll(
              _db.quarantinedRecords,
              snapshots.values,
              mode: InsertMode.insertOrReplace,
            ));
      }

      await _captureConflicts(userId, conflicts, QuarantineReason.signOut);
      await _db.syncQueueDao.quarantinePendingFor(userId);

      AppLogger.info(
          'Set aside ${operations.length} operation(s), '
          '${conflicts.length} conflict(s) and '
          '${snapshots.length} record(s) for this account');
      return operations.length;
    });
  }

  /// Preserves the unsynced work for one trip, then removes it from the queue.
  ///
  /// Used when access to a trip is revoked. The trip has to leave normal browsing
  /// - the user cannot see it any more - but the edits they made and never sent
  /// are still theirs. They are set aside under this account so they can be
  /// recovered, rather than deleted because the trip they belonged to went away.
  ///
  /// Returns how many operations were preserved.
  Future<int> quarantineTrip(String userId, String tripId) async {
    return _db.transaction(() async {
      final all = await _db.syncQueueDao.getAllOperations();

      // The trip's own operations, plus any child operation belonging to it.
      //
      // The parent is resolved from the local child row first and only then
      // from the payload. Reading the payload alone missed every ordinary
      // update and delete: a patch carries the fields being changed, and a
      // title patch has no reason to repeat `trip_id`. Those operations were
      // left in the queue while the eviction deleted the row they patched,
      // stranding work that had nothing left to apply to.
      final owned = <SyncQueueData>[];
      for (final op in all) {
        if (op.entityType == 'trip' && op.entityId == tripId) {
          owned.add(op);
          continue;
        }
        if (!_tripScoped.contains(op.entityType)) continue;

        final parent = await _tripIdFor(op.entityType, op.entityId) ??
            _tripIdFromPayload(op.payload);
        if (parent == tripId) owned.add(op);
      }

      // Conflicts belonging to this trip, found independently of the queue.
      final conflicts = <SyncConflict>[];
      for (final conflict in await _db.syncQueueDao.getUnresolvedConflicts()) {
        if (conflict.entityType == 'trip' && conflict.entityId == tripId) {
          conflicts.add(conflict);
          continue;
        }
        if (!_tripScoped.contains(conflict.entityType)) continue;

        final parent =
            await _tripIdFor(conflict.entityType, conflict.entityId);
        if (parent == tripId) conflicts.add(conflict);
      }

      // Nothing unsent, nothing to recover. Snapshotting the trip anyway meant
      // every revoked trip was copied into recovery storage and handed back by
      // the next restore - so a trip the server had removed access to reappeared
      // in normal browsing, with no edit to justify keeping it.
      if (owned.isEmpty && conflicts.isEmpty) {
        AppLogger.info(
            'Revoked trip $tripId had no unsent work; nothing to recover');
        return 0;
      }

      final snapshots = <String, QuarantinedRecordsCompanion>{};
      await _captureRecord(
          snapshots, userId, 'trip', tripId, QuarantineReason.revoked);

      for (final op in owned) {
        await _captureRecord(snapshots, userId, op.entityType, op.entityId,
            QuarantineReason.revoked);
      }

      for (final conflict in conflicts) {
        await _captureRecord(snapshots, userId, conflict.entityType,
            conflict.entityId, QuarantineReason.revoked);
      }

      if (snapshots.isNotEmpty) {
        await _db.batch((b) => b.insertAll(
              _db.quarantinedRecords,
              snapshots.values,
              mode: InsertMode.insertOrReplace,
            ));
      }

      if (owned.isNotEmpty) {
        final now = DateTime.now();
        await _db.batch((b) {
          b.insertAll(
            _db.quarantinedOperations,
            owned.map((row) => QuarantinedOperationsCompanion.insert(
                  id: row.id,
                  userId: userId,
                  entityType: row.entityType,
                  entityId: row.entityId,
                  operation: row.operation,
                  payload: row.payload,
                  createdAt: row.createdAt,
                  quarantinedAt: now,
                  reason: const Value(QuarantineReason.revoked),
                )),
            mode: InsertMode.insertOrReplace,
          );
        });

        await _db.syncQueueDao.removeByIds(owned.map((o) => o.id).toList());
      }

      await _captureConflicts(userId, conflicts, QuarantineReason.revoked);

      if (conflicts.isNotEmpty) {
        await (_db.delete(_db.syncConflicts)
              ..where((c) => c.id.isIn(conflicts.map((x) => x.id).toList())))
            .go();
      }

      AppLogger.info(
          'Preserved ${owned.length} unsent operation(s), '
          '${conflicts.length} conflict(s) and ${snapshots.length} record(s) '
          'from revoked trip $tripId');

      return owned.length;
    });
  }

  /// Sets [operations] aside under [reason] and takes them off the queue.
  ///
  /// For work the server will never accept however many times it is sent - an
  /// operation whose body is over the push limit, which comes back 413 every
  /// time. Two things must not happen to it, and doing nothing does both: left
  /// on the queue it is re-sent on every cycle and every operation behind it
  /// waits for a request that cannot succeed, and dropped outright it takes
  /// with it something only the user could have written.
  ///
  /// So the operation is moved here, whole, and the queue moves on. Unlike the
  /// eviction paths this takes no snapshot of the local row: the row is still
  /// in the app, untouched and still dirty. What was lost is the push, not the
  /// data, and the payload preserved here is the record of it.
  ///
  /// Nothing restores these automatically - [restore] takes sign-out work only.
  ///
  /// Returns how many operations were set aside.
  Future<int> quarantineOperations(
    String userId,
    List<SyncQueueData> operations, {
    required String reason,
  }) async {
    if (operations.isEmpty) return 0;

    return _db.transaction(() async {
      final now = DateTime.now();

      await _db.batch((b) {
        b.insertAll(
          _db.quarantinedOperations,
          operations.map((row) => QuarantinedOperationsCompanion.insert(
                id: row.id,
                userId: userId,
                entityType: row.entityType,
                entityId: row.entityId,
                operation: row.operation,
                payload: row.payload,
                createdAt: row.createdAt,
                quarantinedAt: now,
                reason: Value(reason),
              )),
          mode: InsertMode.insertOrReplace,
        );
      });

      await _db.syncQueueDao
          .removeByIds(operations.map((row) => row.id).toList());

      AppLogger.warning('Set aside ${operations.length} operation(s) as '
          '$reason; they will not be sent again');
      return operations.length;
    });
  }

  /// Work kept because it is too large for one push to carry.
  ///
  /// Read the same way [revokedWork] is, and for the same purpose: the user can
  /// see what could not be sent rather than being told everything synced.
  Future<RevokedWork> unsendableWork(String userId) =>
      _workFor(userId, QuarantineReason.tooLarge);

  /// Puts an account's own preserved work back.
  ///
  /// Records are restored before operations, so a replayed patch has something
  /// to apply to and parents exist before their children.
  Future<int> restore(String userId) async {
    return _db.transaction(() async {
      // Sign-out work only. Revoked work stays where it is: the trip left
      // normal browsing because the server said this account may not see it,
      // and restoring its rows here would hand it straight back - offline, with
      // nothing to evict it again until the next successful pull.
      final records = await (_db.select(_db.quarantinedRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.reason.equals(QuarantineReason.signOut)))
          .get();

      // Parents first: a child row referencing a missing trip would be orphaned
      // for as long as it took the next pull to arrive.
      records.sort((a, b) {
        if (a.entityType == b.entityType) return 0;
        if (a.entityType == 'trip') return -1;
        if (b.entityType == 'trip') return 1;
        return 0;
      });

      for (final record in records) {
        await _restoreRecord(record);
      }

      final restored = await _db.syncQueueDao.restoreQuarantinedFor(userId);

      // Conflicts go back unresolved, so the user is asked again rather than
      // having one version silently chosen for them by a sign-out.
      final conflicts = await (_db.select(_db.quarantinedConflicts)
            ..where((c) =>
                c.userId.equals(userId) &
                c.reason.equals(QuarantineReason.signOut)))
          .get();

      for (final conflict in conflicts) {
        await _db.syncQueueDao.recordConflict(SyncConflictsCompanion(
          id: Value(conflict.conflictId),
          entityType: Value(conflict.entityType),
          entityId: Value(conflict.entityId),
          localPayload: Value(conflict.localPayload),
          serverPayload: Value(conflict.serverPayload),
          detectedAt: Value(conflict.detectedAt),
          detectedSequence: Value(conflict.detectedSequence),
          isResolved: const Value(false),
        ));
      }

      await (_db.delete(_db.quarantinedRecords)
            ..where((r) =>
                r.userId.equals(userId) &
                r.reason.equals(QuarantineReason.signOut)))
          .go();

      await (_db.delete(_db.quarantinedConflicts)
            ..where((c) =>
                c.userId.equals(userId) &
                c.reason.equals(QuarantineReason.signOut)))
          .go();

      if (restored > 0 || records.isNotEmpty || conflicts.isNotEmpty) {
        AppLogger.info('Restored $restored operation(s), '
            '${conflicts.length} conflict(s) and ${records.length} record(s)');
      }
      return restored;
    });
  }

  /// Work kept because access to its trip was revoked.
  ///
  /// Never restored automatically. This is what a recovery screen reads: the
  /// user can see what they wrote and copy it out, without the trip itself
  /// coming back into the app.
  Future<RevokedWork> revokedWork(String userId) =>
      _workFor(userId, QuarantineReason.revoked);

  /// Everything set aside for [userId] under one [where] reason.
  Future<RevokedWork> _workFor(String userId, String where) async {
    final operations = await (_db.select(_db.quarantinedOperations)
          ..where((o) => o.userId.equals(userId) & o.reason.equals(where))
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
        .get();

    final records = await (_db.select(_db.quarantinedRecords)
          ..where((r) => r.userId.equals(userId) & r.reason.equals(where)))
        .get();

    final conflicts = await (_db.select(_db.quarantinedConflicts)
          ..where((c) => c.userId.equals(userId) & c.reason.equals(where)))
        .get();

    return RevokedWork(
        operations: operations, records: records, conflicts: conflicts);
  }

  /// Forgets recovered work the user has finished with.
  Future<void> discardRevoked(String userId) async {
    await _db.transaction(() async {
      final where = QuarantineReason.revoked;

      await (_db.delete(_db.quarantinedOperations)
            ..where((o) => o.userId.equals(userId) & o.reason.equals(where)))
          .go();
      await (_db.delete(_db.quarantinedRecords)
            ..where((r) => r.userId.equals(userId) & r.reason.equals(where)))
          .go();
      await (_db.delete(_db.quarantinedConflicts)
            ..where((c) => c.userId.equals(userId) & c.reason.equals(where)))
          .go();
    });
  }

  Future<void> _captureConflicts(
    String userId,
    List<SyncConflict> conflicts,
    String reason,
  ) async {
    if (conflicts.isEmpty) return;

    final now = DateTime.now();
    await _db.batch((b) => b.insertAll(
          _db.quarantinedConflicts,
          conflicts.map((c) => QuarantinedConflictsCompanion.insert(
                id: '$userId:${c.id}',
                userId: userId,
                conflictId: c.id,
                entityType: c.entityType,
                entityId: c.entityId,
                localPayload: c.localPayload,
                serverPayload: c.serverPayload,
                detectedAt: c.detectedAt,
                detectedSequence: Value(c.detectedSequence),
                quarantinedAt: now,
                reason: Value(reason),
              )),
          mode: InsertMode.insertOrReplace,
        ));
  }

  Future<int> recordCountFor(String userId) async {
    final rows = await (_db.select(_db.quarantinedRecords)
          ..where((r) => r.userId.equals(userId)))
        .get();
    return rows.length;
  }

  Future<void> _captureRecord(
    Map<String, QuarantinedRecordsCompanion> into,
    String userId,
    String entityType,
    String entityId,
    String reason,
  ) async {
    final key = '$userId:$entityType:$entityId';
    if (into.containsKey(key)) return;

    final json = await _rowAsJson(entityType, entityId);
    if (json == null) return;

    into[key] = QuarantinedRecordsCompanion.insert(
      id: key,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      rowJson: jsonEncode(json),
      quarantinedAt: DateTime.now(),
      reason: Value(reason),
    );
  }

  Future<Map<String, dynamic>?> _rowAsJson(
      String entityType, String entityId) async {
    switch (entityType) {
      case 'trip':
        return (await _db.tripsDao.getById(entityId))?.toJson();
      case 'activity':
        return (await _db.activitiesDao.getById(entityId))?.toJson();
      case 'expense':
        return (await _db.expensesDao.getById(entityId))?.toJson();
      case 'packing_item':
        return (await _db.packingDao.getById(entityId))?.toJson();
      case 'document':
        return (await _db.documentsDao.getById(entityId))?.toJson();
      case 'memory':
        return (await _db.memoriesDao.getById(entityId))?.toJson();
      case 'template':
        return (await _db.templatesDao.getById(entityId))?.toJson();
      default:
        return null;
    }
  }

  Future<void> _restoreRecord(QuarantinedRecord record) async {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(record.rowJson) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Could not decode quarantined record ${record.id}: $e');
      return;
    }

    try {
      // Written through the tables rather than the DAOs: the DAO upserts take
      // companions, and a snapshot is a complete row.
      switch (record.entityType) {
        case 'trip':
          await _db.into(_db.localTrips)
              .insertOnConflictUpdate(LocalTrip.fromJson(json));
        case 'activity':
          await _db.into(_db.localActivities)
              .insertOnConflictUpdate(LocalActivity.fromJson(json));
        case 'expense':
          await _db.into(_db.localExpenses)
              .insertOnConflictUpdate(LocalExpense.fromJson(json));
        case 'packing_item':
          await _db.into(_db.localPackingItems)
              .insertOnConflictUpdate(LocalPackingItem.fromJson(json));
        case 'document':
          await _db.into(_db.localDocuments)
              .insertOnConflictUpdate(LocalDocument.fromJson(json));
        case 'memory':
          await _db.into(_db.localMemories)
              .insertOnConflictUpdate(LocalMemory.fromJson(json));
        case 'template':
          await _db.into(_db.localTemplates)
              .insertOnConflictUpdate(LocalTemplate.fromJson(json));
      }
    } catch (e) {
      AppLogger.error('Could not restore quarantined ${record.entityType}: $e');
    }
  }

  Future<String?> _tripIdFor(String entityType, String entityId) async {
    switch (entityType) {
      case 'activity':
        return (await _db.activitiesDao.getById(entityId))?.tripId;
      case 'expense':
        return (await _db.expensesDao.getById(entityId))?.tripId;
      case 'packing_item':
        return (await _db.packingDao.getById(entityId))?.tripId;
      case 'document':
        return (await _db.documentsDao.getById(entityId))?.tripId;
      case 'memory':
        return (await _db.memoriesDao.getById(entityId))?.tripId;
      default:
        return null;
    }
  }

  /// For a queued create whose local row is already gone, the parent reference
  /// still lives in the payload.
  String? _tripIdFromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['trip_id'] is String) {
        return decoded['trip_id'] as String;
      }
    } catch (_) {
      // Unreadable payloads are handled elsewhere.
    }
    return null;
  }
}

/// What is sitting in recovery storage for trips this account lost access to.
class RevokedWork {
  const RevokedWork({
    required this.operations,
    required this.records,
    required this.conflicts,
  });

  final List<QuarantinedOperation> operations;
  final List<QuarantinedRecord> records;
  final List<QuarantinedConflict> conflicts;

  bool get isEmpty =>
      operations.isEmpty && records.isEmpty && conflicts.isEmpty;

  int get itemCount => operations.length + conflicts.length;
}
