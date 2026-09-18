import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Regression tests for F10: revoking a share used to physically remove the row,
/// leaving the recipient's device no way to learn its access had gone. The cached
/// trip simply stopped being refreshed while staying fully readable.

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedTripWithContent(String tripId) async {
    await db.into(db.localTrips).insert(LocalTripsCompanion.insert(
          id: tripId,
          userId: 'owner',
          title: 'Rome',
          startDate: '2026-05-01',
          status: 'planned',
          createdAt: t0,
          updatedAt: t0,
        ));
    await db.into(db.localActivities).insert(LocalActivitiesCompanion.insert(
          id: 'a-$tripId',
          tripId: tripId,
          title: 'Colosseum',
          scheduledTime: '2026-05-02T10:00:00Z',
          category: 'explore',
          createdAt: t0,
          updatedAt: t0,
        ));
    await db.into(db.localExpenses).insert(LocalExpensesCompanion.insert(
          id: 'e-$tripId',
          tripId: tripId,
          title: 'Dinner',
          amount: 40,
          category: 'food',
          date: '2026-05-02',
          createdAt: t0,
          updatedAt: t0,
        ));
  }

  group('evicting a revoked trip', () {
    test('removes the trip and everything under it', () async {
      // A revoked collaborator keeping a readable copy of the itinerary and
      // budget is the whole problem revocation is meant to solve.
      await seedTripWithContent('t1');

      await db.activitiesDao.deleteByTrip('t1');
      await db.expensesDao.deleteByTrip('t1');
      await db.tripsDao.hardDelete('t1');

      expect(await db.tripsDao.getAll(), isEmpty);
      expect(await db.activitiesDao.getByTrip('t1'), isEmpty);
      expect(await db.expensesDao.getByTrip('t1'), isEmpty);
    });

    test('leaves other trips untouched', () async {
      await seedTripWithContent('t1');
      await seedTripWithContent('t2');

      await db.activitiesDao.deleteByTrip('t1');
      await db.tripsDao.hardDelete('t1');

      final remaining = await db.tripsDao.getAll();
      expect(remaining.map((t) => t.id), ['t2']);
      expect(await db.activitiesDao.getByTrip('t2'), hasLength(1));
    });
  });

  group('queued operations for a revoked trip', () {
    Future<void> queueChild(String id, String tripId, {String type = 'activity'}) {
      return db.syncQueueDao.enqueue(SyncQueueCompanion(
        id: Value(id),
        entityType: Value(type),
        entityId: Value('child-$id'),
        operation: const Value(SyncOp.update),
        payload: Value('{"trip_id":"$tripId","title":"Edit"}'),
        createdAt: Value(t0),
      ));
    }

    test('are dropped, since they would only ever be refused', () async {
      await queueChild('q1', 't1');
      await queueChild('q2', 't2');

      await db.syncQueueDao.removeForTripPayload('activity', 't1');

      final pending = await db.syncQueueDao.getPending();
      expect(pending.map((r) => r.id), ['q2']);
    });

    test('a similar-looking id is not mistaken for the revoked trip', () async {
      await queueChild('q1', 't1');
      await queueChild('q2', 't10');

      await db.syncQueueDao.removeForTripPayload('activity', 't1');

      final pending = await db.syncQueueDao.getPending();
      expect(pending.map((r) => r.id), ['q2'],
          reason: 't10 must not match a t1 revocation');
    });

    test('only the named entity type is affected', () async {
      await queueChild('q1', 't1', type: 'activity');
      await queueChild('q2', 't1', type: 'expense');

      await db.syncQueueDao.removeForTripPayload('activity', 't1');

      final pending = await db.syncQueueDao.getPending();
      expect(pending.map((r) => r.entityType), ['expense']);
    });
  });
}
