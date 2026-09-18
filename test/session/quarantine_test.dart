import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Regression tests for F07: signing out cleared the whole database, so work
/// made offline and never pushed was deleted outright. It is now set aside under
/// the account that made it and restored if that account returns.

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> queue(String id, String entityId, {DateTime? createdAt}) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: const Value('trip'),
      entityId: Value(entityId),
      operation: const Value(SyncOp.create),
      payload: Value('{"id":"$entityId","title":"Rome"}'),
      createdAt: Value(createdAt ?? t0),
    ));
  }

  group('quarantine on sign-out', () {
    test('moves unsynced work out of the live queue', () async {
      await queue('q1', 't1');
      await queue('q2', 't2');

      final moved = await db.syncQueueDao.quarantinePendingFor('user-a');

      expect(moved, 2);
      expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 2);
    });

    test('survives the database being cleared', () async {
      // This is the whole point: clearAllData used to take the queue with it.
      await queue('q1', 't1');
      await db.syncQueueDao.quarantinePendingFor('user-a');

      await db.clearAllData();

      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 1);
    });

    test('is a no-op when nothing is queued', () async {
      expect(await db.syncQueueDao.quarantinePendingFor('user-a'), 0);
    });
  });

  group('restore on sign-in', () {
    test('puts the account\'s own work back on the queue', () async {
      await queue('q1', 't1');
      await db.syncQueueDao.quarantinePendingFor('user-a');
      await db.clearAllData();

      final restored = await db.syncQueueDao.restoreQuarantinedFor('user-a');

      expect(restored, 1);
      final pending = await db.syncQueueDao.getPending();
      expect(pending.single.entityId, 't1');
      expect(pending.single.payload, contains('Rome'));
    });

    test('never hands one account another account\'s work', () async {
      await queue('q1', 't1');
      await db.syncQueueDao.quarantinePendingFor('user-a');
      await db.clearAllData();

      final restored = await db.syncQueueDao.restoreQuarantinedFor('user-b');

      expect(restored, 0);
      expect(await db.syncQueueDao.getPending(), isEmpty,
          reason: "user-b must not inherit user-a's queued changes");
      expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 1,
          reason: "user-a's work is still waiting for user-a");
    });

    test('empties the quarantine so work is not restored twice', () async {
      await queue('q1', 't1');
      await db.syncQueueDao.quarantinePendingFor('user-a');
      await db.clearAllData();

      await db.syncQueueDao.restoreQuarantinedFor('user-a');
      final second = await db.syncQueueDao.restoreQuarantinedFor('user-a');

      expect(second, 0);
      expect(await db.syncQueueDao.getPending(), hasLength(1));
    });

    test('preserves queue order so parents still precede children', () async {
      await queue('q1', 't1', createdAt: t0);
      await queue('q2', 'a1', createdAt: t0.add(const Duration(minutes: 1)));
      await db.syncQueueDao.quarantinePendingFor('user-a');
      await db.clearAllData();

      await db.syncQueueDao.restoreQuarantinedFor('user-a');

      final pending = await db.syncQueueDao.getPending();
      expect(pending.map((r) => r.entityId), ['t1', 'a1']);
    });

    test('a full sign-out and sign-in round trip loses nothing', () async {
      await queue('q1', 't1');

      // Sign out.
      await db.syncQueueDao.quarantinePendingFor('user-a');
      await db.clearAllData();
      expect(await db.syncQueueDao.getPending(), isEmpty);

      // Sign back in.
      await db.syncQueueDao.restoreQuarantinedFor('user-a');

      final pending = await db.syncQueueDao.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.operation, SyncOp.create);
      expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 0);
    });
  });
}
