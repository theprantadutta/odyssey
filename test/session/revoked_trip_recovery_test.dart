import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/session/unsynced_work_quarantine.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Losing access to a trip has to do two things at once: the trip must leave
/// normal browsing, because the user cannot see it any more, and the edits they
/// made and never sent must survive, because only they could have written them.
///
/// The first version kept the whole trip visible whenever it had unsent edits,
/// which got the first half exactly backwards.

void main() {
  late AppDatabase db;
  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedTrip(String id) {
    return db.into(db.localTrips).insert(LocalTripsCompanion.insert(
          id: id,
          userId: 'user-a',
          title: 'Shared trip',
          startDate: '2026-05-01',
          status: 'planned',
          createdAt: t0,
          updatedAt: t0,
          isDirty: const Value(true),
        ));
  }

  Future<void> seedActivity(String id, String tripId) {
    return db.into(db.localActivities).insert(LocalActivitiesCompanion.insert(
          id: id,
          tripId: tripId,
          title: 'My note',
          scheduledTime: '2026-05-02T10:00:00Z',
          category: 'explore',
          createdAt: t0,
          updatedAt: t0,
          isDirty: const Value(true),
        ));
  }

  Future<void> queue(
    String id,
    String entityType,
    String entityId,
    String payload,
  ) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: const Value(SyncOp.update),
      payload: Value(payload),
      createdAt: Value(t0),
    ));
  }

  test('unsent edits for a revoked trip move into recovery storage', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', '{"title":"My rename"}');

    final preserved = await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    expect(preserved, 1);
    expect(await db.syncQueueDao.getPending(), isEmpty,
        reason: 'the operation no longer belongs on the live queue');

    // Counted as recovery, not as work waiting to be restored.
    // `quarantinedCountFor` answers "what comes back when this account signs in
    // again", and revoked work deliberately never does.
    expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 0);

    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.operations, hasLength(1));
    expect(recovery.records, isNotEmpty,
        reason: 'the record the edit applies to is preserved with it');
  });

  test('a child edit naming the trip is preserved too', () async {
    await seedTrip('t1');
    await seedActivity('a1', 't1');
    await queue('q1', 'activity', 'a1', '{"trip_id":"t1","title":"My note"}');

    final preserved = await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    expect(preserved, 1);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('work for other trips is left alone', () async {
    await seedTrip('t1');
    await seedTrip('t2');
    await queue('q1', 'trip', 't1', '{"title":"Revoked"}');
    await queue('q2', 'trip', 't2', '{"title":"Still mine"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    final pending = await db.syncQueueDao.getPending();
    expect(pending.map((r) => r.entityId), ['t2']);
  });

  test('the preserved work is readable by its own account, without returning '
      'the trip', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', '{"title":"My rename"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    await db.delete(db.localTrips).go(); // the eviction that follows
    await UnsyncedWorkQuarantine(db).restore('user-a');

    // Signing back in must not put this on the live queue. The server revoked
    // access, so pushing the edit again would be refused on every cycle, and
    // the row it patches is deliberately no longer here.
    expect(await db.syncQueueDao.getPending(), isEmpty);
    expect(await db.tripsDao.getAll(), isEmpty,
        reason: 'the revoked trip returned to normal browsing');

    // The user's work is still theirs, and still legible.
    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.operations, hasLength(1));
    expect(recovery.operations.single.payload, contains('My rename'));
  });

  test('another account cannot recover it', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', '{"title":"My rename"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    final restored = await UnsyncedWorkQuarantine(db).restore('user-b');

    expect(restored, 0);
    expect(await db.syncQueueDao.getPending(), isEmpty);

    expect((await UnsyncedWorkQuarantine(db).revokedWork('user-b')).isEmpty,
        isTrue);
    expect(
        (await UnsyncedWorkQuarantine(db).revokedWork('user-a')).operations,
        hasLength(1),
        reason: 'it is still held for the account that made it');
  });

  test('a revoked trip with no unsent work preserves nothing', () async {
    await seedTrip('t1');

    final preserved = await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    expect(preserved, 0);
  });
}
