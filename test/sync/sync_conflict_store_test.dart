import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Regression tests for the durable side of F05: conflicts must survive as data
/// the user can still act on, and an in-flight operation must be recoverable
/// after the process dies.

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> queue(String id, String entityId, {String status = SyncStatus.pending}) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: const Value('trip'),
      entityId: Value(entityId),
      operation: const Value(SyncOp.update),
      payload: const Value('{"title":"Local"}'),
      status: Value(status),
      createdAt: Value(t0),
    ));
  }

  Future<void> conflict(String entityId) {
    return db.syncQueueDao.recordConflict(SyncConflictsCompanion(
      id: Value('trip:$entityId'),
      entityType: const Value('trip'),
      entityId: Value(entityId),
      localPayload: const Value('{"title":"Mine"}'),
      serverPayload: const Value('{"title":"Theirs"}'),
      detectedAt: Value(t0),
    ));
  }

  group('conflict records', () {
    test('keep both the local and the server version', () async {
      await conflict('t1');

      final stored = (await db.syncQueueDao.getUnresolvedConflicts()).single;
      expect(stored.localPayload, contains('Mine'));
      expect(stored.serverPayload, contains('Theirs'));
      expect(stored.isResolved, isFalse);
    });

    test('are keyed per record, so a repeat does not pile up', () async {
      await conflict('t1');
      await conflict('t1');

      expect(await db.syncQueueDao.getUnresolvedConflicts(), hasLength(1));
    });

    test('are reported so the user can be told something needs attention', () async {
      expect(await db.syncQueueDao.watchUnresolvedConflictCount().first, 0);

      await conflict('t1');
      await conflict('t2');

      expect(await db.syncQueueDao.watchUnresolvedConflictCount().first, 2);
    });

    test('a later successful push for the record settles it', () async {
      await conflict('t1');
      await conflict('t2');

      await db.syncQueueDao.resolveConflictsFor('trip', 't1');

      final remaining = await db.syncQueueDao.getUnresolvedConflicts();
      expect(remaining.map((c) => c.entityId), ['t2']);
    });

    test('resolving one record does not touch another entity type', () async {
      await conflict('t1');
      await db.syncQueueDao.recordConflict(SyncConflictsCompanion(
        id: const Value('activity:t1'),
        entityType: const Value('activity'),
        entityId: const Value('t1'),
        localPayload: const Value('{}'),
        serverPayload: const Value('{}'),
        detectedAt: Value(t0),
      ));

      await db.syncQueueDao.resolveConflictsFor('trip', 't1');

      final remaining = await db.syncQueueDao.getUnresolvedConflicts();
      expect(remaining.map((c) => c.entityType), ['activity']);
    });
  });

  group('in-flight operations', () {
    test('record the revision they were sent for', () async {
      await queue('q1', 't1');

      await db.syncQueueDao.markInProgress('q1', sentRevision: t0, sentAt: t0);

      final row = (await db.syncQueueDao.getInProgress()).single;
      expect(row.status, SyncStatus.inProgress);
      // Drift stores datetimes as epoch seconds and reads them back in local
      // time, so compare instants rather than the DateTime objects.
      expect(row.sentRevision!.toUtc(), t0);
      expect(row.sentAt!.toUtc(), t0);
    });

    test('are excluded from the pending set while in flight', () async {
      await queue('q1', 't1');
      await db.syncQueueDao.markInProgress('q1', sentRevision: t0, sentAt: t0);

      expect(await db.syncQueueDao.getPending(), isEmpty);
    });

    test('return to the queue cleanly when released', () async {
      // Process killed after the push was sent; the next launch recovers it.
      await queue('q1', 't1');
      await db.syncQueueDao.markInProgress('q1', sentRevision: t0, sentAt: t0);

      await db.syncQueueDao.releaseInProgress('q1');

      final row = (await db.syncQueueDao.getPending()).single;
      expect(row.status, SyncStatus.pending);
      expect(row.sentRevision, isNull,
          reason: 'the next send captures a fresh revision');
      expect(row.sentAt, isNull);
    });
  });

  group('clearAll', () {
    test('drops conflicts along with the queue', () async {
      await queue('q1', 't1');
      await conflict('t1');

      await db.syncQueueDao.clearAll();

      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await db.syncQueueDao.getUnresolvedConflicts(), isEmpty);
    });
  });
}
