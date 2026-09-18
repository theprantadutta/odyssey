import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Exercises the queue DAO helpers coalescing depends on against real SQL,
/// rather than trusting the pure logic alone.

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insert(
    String id,
    String entityId,
    String operation, {
    String entityType = 'trip',
    String status = SyncStatus.pending,
    DateTime? createdAt,
  }) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: const Value('{}'),
      status: Value(status),
      createdAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
    ));
  }

  group('getForEntity', () {
    test('returns rows oldest first', () async {
      await insert('b', 't1', SyncOp.update,
          createdAt: DateTime.utc(2026, 1, 2));
      await insert('a', 't1', SyncOp.create,
          createdAt: DateTime.utc(2026, 1, 1));

      final rows = await db.syncQueueDao.getForEntity('trip', 't1');

      expect(rows.map((r) => r.id), ['a', 'b']);
    });

    test('includes in-flight rows so they can be left alone', () async {
      await insert('a', 't1', SyncOp.create, status: SyncStatus.inProgress);

      final rows = await db.syncQueueDao.getForEntity('trip', 't1');

      expect(rows, hasLength(1));
      expect(rows.single.status, SyncStatus.inProgress);
    });

    test('does not leak other entities or other types', () async {
      await insert('a', 't1', SyncOp.create);
      await insert('b', 't2', SyncOp.create);
      await insert('c', 't1', SyncOp.create, entityType: 'activity');

      final rows = await db.syncQueueDao.getForEntity('trip', 't1');

      expect(rows.map((r) => r.id), ['a']);
    });
  });

  group('removeByIds', () {
    test('removes only the named rows', () async {
      await insert('a', 't1', SyncOp.create);
      await insert('b', 't1', SyncOp.update);
      await insert('c', 't2', SyncOp.create);

      await db.syncQueueDao.removeByIds(['a', 'b']);

      final remaining = await db.syncQueueDao.getPending();
      expect(remaining.map((r) => r.id), ['c']);
    });

    test('is a no-op for an empty list', () async {
      await insert('a', 't1', SyncOp.create);

      await db.syncQueueDao.removeByIds([]);

      expect(await db.syncQueueDao.getPending(), hasLength(1));
    });
  });

  group('remapEntityId', () {
    test('repoints queued operations at the server ID', () async {
      // After a create returns a server-assigned ID, pending child work still
      // references the local one and would otherwise be sent to a dead ID.
      await insert('a', 'local-1', SyncOp.update);
      await insert('b', 'local-1', SyncOp.update, entityType: 'activity');

      await db.syncQueueDao.remapEntityId(
        entityType: 'trip',
        fromEntityId: 'local-1',
        toEntityId: 'server-1',
      );

      final trips = await db.syncQueueDao.getForEntity('trip', 'server-1');
      final activities =
          await db.syncQueueDao.getForEntity('activity', 'local-1');

      expect(trips.map((r) => r.id), ['a']);
      expect(activities.map((r) => r.id), ['b'],
          reason: 'only the named entity type is remapped');
    });
  });

  group('markCompleted', () {
    test('removes the row so it cannot be resent', () async {
      await insert('a', 't1', SyncOp.create);

      await db.syncQueueDao.markCompleted('a');

      expect(await db.syncQueueDao.getPending(), isEmpty);
    });
  });

  group('incrementRetryCount', () {
    test('records the error and returns the row to pending', () async {
      await insert('a', 't1', SyncOp.create, status: SyncStatus.inProgress);

      await db.syncQueueDao.incrementRetryCount('a', 'network down');

      final row = (await db.syncQueueDao.getPending()).single;
      expect(row.retryCount, 1);
      expect(row.lastError, 'network down');
      expect(row.status, SyncStatus.pending);
    });
  });
}
