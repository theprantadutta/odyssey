import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/local_record_reconciler.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Regression tests for F03: an online create inserted a local row under a
/// client UUID, then inserted the server's differently-keyed row beside it and
/// left the first one stranded, so one trip showed up twice.

void main() {
  late AppDatabase db;
  late LocalRecordReconciler reconciler;

  final now = DateTime.utc(2026, 1, 1);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reconciler = LocalRecordReconciler(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTrip(String id) {
    return db.into(db.localTrips).insert(LocalTripsCompanion.insert(
          id: id,
          userId: 'u1',
          title: 'Rome',
          startDate: '2026-05-01',
          status: 'planned',
          createdAt: now,
          updatedAt: now,
          isLocalOnly: const Value(true),
        ));
  }

  Future<void> insertActivity(String id, String tripId) {
    return db.into(db.localActivities).insert(LocalActivitiesCompanion.insert(
          id: id,
          tripId: tripId,
          title: 'Colosseum',
          scheduledTime: '2026-05-02T10:00:00Z',
          category: 'explore',
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<void> queue(
    String id,
    String entityType,
    String entityId,
    String operation, {
    Map<String, dynamic> payload = const {},
  }) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(now),
    ));
  }

  group('matching IDs', () {
    test('does nothing when the server adopted our ID', () async {
      await insertTrip('same-id');

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'same-id',
        serverId: 'same-id',
      );

      final trips = await db.tripsDao.getAll();
      expect(trips, hasLength(1));
      expect(trips.single.id, 'same-id');
    });

    test('ignores an empty server ID rather than deleting the local row', () async {
      await insertTrip('local-1');

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: '',
      );

      expect(await db.tripsDao.getAll(), hasLength(1));
    });
  });

  group('differing IDs', () {
    test('removes the stranded local row so the trip appears once', () async {
      // Both rows exist at this point, which is exactly the duplicate users saw.
      await insertTrip('local-1');
      await insertTrip('server-1');

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: 'server-1',
      );

      final trips = await db.tripsDao.getAll();
      expect(trips, hasLength(1));
      expect(trips.single.id, 'server-1');
    });

    test('repoints children so they are not orphaned', () async {
      await insertTrip('local-1');
      await insertTrip('server-1');
      await insertActivity('a1', 'local-1');

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: 'server-1',
      );

      expect(await db.activitiesDao.getByTrip('local-1'), isEmpty);
      final moved = await db.activitiesDao.getByTrip('server-1');
      expect(moved.map((a) => a.id), ['a1']);
    });

    test('remaps queued operations for the entity itself', () async {
      await insertTrip('local-1');
      await insertTrip('server-1');
      await queue('q1', 'trip', 'local-1', SyncOp.update, payload: {'title': 'X'});

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: 'server-1',
      );

      expect(await db.syncQueueDao.getForEntity('trip', 'local-1'), isEmpty);
      final remapped = await db.syncQueueDao.getForEntity('trip', 'server-1');
      expect(remapped.map((r) => r.id), ['q1']);
    });

    test('rewrites the parent ID inside queued child payloads', () async {
      // A queued activity is keyed by its own ID, so remapping entity IDs never
      // reaches the trip_id buried in its payload. Left alone the activity would
      // be created against a trip ID the server never issued.
      await insertTrip('local-1');
      await insertTrip('server-1');
      await queue('q1', 'activity', 'a1', SyncOp.create,
          payload: {'trip_id': 'local-1', 'title': 'Colosseum'});

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: 'server-1',
      );

      final row = (await db.syncQueueDao.getForEntity('activity', 'a1')).single;
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      expect(payload['trip_id'], 'server-1');
      expect(payload['title'], 'Colosseum');
    });

    test('leaves unrelated queued children alone', () async {
      await insertTrip('local-1');
      await insertTrip('server-1');
      await queue('q1', 'activity', 'a1', SyncOp.create,
          payload: {'trip_id': 'other-trip'});

      await reconciler.reconcileCreatedId(
        entityType: 'trip',
        localId: 'local-1',
        serverId: 'server-1',
      );

      final row = (await db.syncQueueDao.getForEntity('activity', 'a1')).single;
      expect(jsonDecode(row.payload)['trip_id'], 'other-trip');
    });

    test('cleans up a child entity without touching trips', () async {
      await insertTrip('t1');
      await insertActivity('local-a', 't1');
      await insertActivity('server-a', 't1');

      await reconciler.reconcileCreatedId(
        entityType: 'activity',
        localId: 'local-a',
        serverId: 'server-a',
      );

      final activities = await db.activitiesDao.getByTrip('t1');
      expect(activities.map((a) => a.id), ['server-a']);
      expect(await db.tripsDao.getAll(), hasLength(1));
    });
  });

  group('withClientId', () {
    test('adds the local ID to the create payload', () {
      expect(
        withClientId('local-1', {'title': 'Rome'}),
        {'id': 'local-1', 'title': 'Rome'},
      );
    });

    test('lets an explicit payload id win over the generated one', () {
      expect(
        withClientId('local-1', {'id': 'explicit', 'title': 'Rome'})['id'],
        'explicit',
      );
    });
  });
}
