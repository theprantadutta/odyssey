import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/session/unsynced_work_quarantine.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Revoked trips versus recoverable work.
///
/// These are two obligations that pull in opposite directions, and the previous
/// implementation satisfied the second by breaking the first:
///
///   * a trip whose access was revoked must leave normal browsing and stay out
///     of it - that is the entire point of eviction;
///   * the unsent edits the user made in it are still theirs, and deleting them
///     because the trip went away throws away work only they could recreate.
///
/// Snapshotting the trip unconditionally and restoring every snapshot into the
/// ordinary tables met the second and quietly undid the first.
///
/// Backed by a real file that is closed and reopened, so migrations run and
/// nothing survives in memory - the audit's failures are about what is left on
/// disk after a restart.
void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_revoked_');
    dbFile = File('${tempDir.path}/odyssey.sqlite');
    db = open();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> restart() async {
    await db.close();
    db = open();
  }

  Future<void> seedTrip(String id, {String title = 'Rome'}) {
    return db.into(db.localTrips).insert(LocalTripsCompanion.insert(
          id: id,
          userId: 'user-a',
          title: title,
          startDate: '2026-05-01',
          status: 'planned',
          createdAt: t0,
          updatedAt: t0,
          isDirty: const Value(true),
        ));
  }

  Future<void> seedActivity(String id, String tripId,
      {String title = 'Colosseum'}) {
    return db.into(db.localActivities).insert(LocalActivitiesCompanion.insert(
          id: id,
          tripId: tripId,
          title: title,
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
    String operation,
    String payload, {
    DateTime? createdAt,
  }) {
    return db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      createdAt: Value(createdAt ?? t0),
    ));
  }

  Future<void> recordConflict(
    String id,
    String entityType,
    String entityId, {
    String local = '{"title":"My version"}',
    String server = '{"title":"Their version"}',
  }) {
    return db.syncQueueDao.recordConflict(SyncConflictsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      localPayload: Value(local),
      serverPayload: Value(server),
      detectedAt: Value(t0),
      isResolved: const Value(false),
    ));
  }

  // ------------------------------------------------- A07: revoked stays gone

  test('a revoked trip with no unsent work does not come back', () async {
    await seedTrip('t1');

    // Revocation, with nothing outstanding. There is no edit to recover, so
    // there is nothing to justify keeping a copy of the trip at all.
    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    await db.delete(db.localTrips).go(); // the eviction that follows

    await restart();
    await UnsyncedWorkQuarantine(db).restore('user-a');

    expect(await db.tripsDao.getAll(), isEmpty,
        reason: 'a trip this account may no longer see reappeared in browsing');
  });

  test('a revoked trip with unsent work still does not come back', () async {
    await seedTrip('t1', title: 'Rome renamed offline');
    await queue('q1', 'trip', 't1', SyncOp.update,
        '{"title":"Rome renamed offline"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    await db.delete(db.localTrips).go();

    await restart();
    await UnsyncedWorkQuarantine(db).restore('user-a');

    // The edit is kept - but as recovery, not as a trip.
    expect(await db.tripsDao.getAll(), isEmpty,
        reason: 'the revoked trip was restored into normal browsing');
    expect(await db.syncQueueDao.getPending(), isEmpty,
        reason: 'work for a revoked trip was put back on the queue, where it '
            'would be pushed to a server that has already refused it');

    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.operations, hasLength(1));
    expect(recovery.operations.single.payload, contains('Rome renamed offline'));
    expect(recovery.records.any((r) => r.entityType == 'trip'), isTrue,
        reason: 'the trip snapshot is needed to show what the edit applied to');
  });

  test('an ordinary patch with no trip_id in its payload is still preserved',
      () async {
    await seedTrip('t1');
    await seedActivity('a1', 't1');

    // A title patch carries the field being changed and has no reason to repeat
    // trip_id. Matching on the payload alone missed it, and the eviction then
    // deleted the row it patched - stranding the user's edit with nothing left
    // to apply to.
    await queue('q1', 'activity', 'a1', SyncOp.update, '{"title":"Forum"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    expect(await db.syncQueueDao.getPending(), isEmpty,
        reason: 'the patch was left in the queue for a deleted row');

    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.operations, hasLength(1));
    expect(recovery.operations.single.entityId, 'a1');
    expect(recovery.records.any((r) => r.entityId == 'a1'), isTrue);
  });

  test('a delete with no trip_id in its payload is preserved too', () async {
    await seedTrip('t1');
    await seedActivity('a1', 't1');
    await queue('q1', 'activity', 'a1', SyncOp.delete, '{}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.operations, hasLength(1));
    expect(recovery.operations.single.operation, SyncOp.delete);
  });

  test('another trip\'s work is left alone', () async {
    await seedTrip('t1');
    await seedTrip('t2', title: 'Lisbon');
    await seedActivity('a2', 't2');
    await queue('q2', 'activity', 'a2', SyncOp.update, '{"title":"Belem"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    // t2 was not revoked, so its queued edit must still be pending.
    final pending = await db.syncQueueDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, 'a2');

    expect((await UnsyncedWorkQuarantine(db).revokedWork('user-a')).isEmpty,
        isTrue);
  });

  // --------------------------------- A08: conflicts survive sign-out/restart

  test('an unresolved conflict with no queue row survives sign-out', () async {
    await seedTrip('t1', title: 'My version');

    // This is the shape the queue-driven quarantine could never see:
    // acknowledging a conflict removes its queue row, so the conflict is the
    // only remaining copy of the rejected edit.
    await recordConflict('c1', 'trip', 't1');
    expect(await db.syncQueueDao.getPending(), isEmpty);

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();

    await restart();
    await UnsyncedWorkQuarantine(db).restore('user-a');

    final conflicts = await db.syncQueueDao.getUnresolvedConflicts();
    expect(conflicts, hasLength(1),
        reason: 'the only copy of the rejected edit was cleared on sign-out');
    expect(conflicts.single.localPayload, contains('My version'));
    expect(conflicts.single.serverPayload, contains('Their version'));
    expect(conflicts.single.isResolved, isFalse,
        reason: 'signing out silently resolved a conflict on the user\'s '
            'behalf');

    // And the record it refers to came back, so the screen has something to
    // show for both versions.
    expect(await db.tripsDao.getById('t1'), isNotNull);
  });

  test('a conflict on a revoked trip is recovered, not restored', () async {
    await seedTrip('t1', title: 'My version');
    await seedActivity('a1', 't1');
    await recordConflict('c1', 'activity', 'a1');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    await db.delete(db.localTrips).go();
    await db.delete(db.localActivities).go();

    await restart();
    await UnsyncedWorkQuarantine(db).restore('user-a');

    // Not put back into the live conflict list: the trip is gone, so there is
    // nothing to resolve against.
    expect(await db.syncQueueDao.getUnresolvedConflicts(), isEmpty);
    expect(await db.tripsDao.getAll(), isEmpty);

    // Kept as recovery, with both versions intact.
    final recovery = await UnsyncedWorkQuarantine(db).revokedWork('user-a');
    expect(recovery.conflicts, hasLength(1));
    expect(recovery.conflicts.single.localPayload, contains('My version'));
    expect(recovery.conflicts.single.serverPayload, contains('Their version'));
  });

  test('restoring twice does not duplicate or lose anything', () async {
    await seedTrip('t1', title: 'Rome renamed offline');
    await queue('q1', 'trip', 't1', SyncOp.update,
        '{"title":"Rome renamed offline"}');
    await recordConflict('c1', 'trip', 't1');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();
    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');
    await UnsyncedWorkQuarantine(db).restore('user-a');

    expect(await db.syncQueueDao.getPending(), hasLength(1));
    expect(await db.syncQueueDao.getUnresolvedConflicts(), hasLength(1));
    expect(await db.tripsDao.getAll(), hasLength(1));
  });

  test('recovered work can be discarded once the user is done with it',
      () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', SyncOp.update, '{"title":"Renamed"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');
    expect((await UnsyncedWorkQuarantine(db).revokedWork('user-a')).isEmpty,
        isFalse);

    await UnsyncedWorkQuarantine(db).discardRevoked('user-a');

    expect((await UnsyncedWorkQuarantine(db).revokedWork('user-a')).isEmpty,
        isTrue);
  });

  test('one account cannot see another account\'s recovered work', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', SyncOp.update, '{"title":"Renamed"}');

    await UnsyncedWorkQuarantine(db).quarantineTrip('user-a', 't1');

    expect((await UnsyncedWorkQuarantine(db).revokedWork('user-b')).isEmpty,
        isTrue);

    await UnsyncedWorkQuarantine(db).restore('user-b');
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  // ------------------------------------------- sign-out work still restores

  test('sign-out work is still restored in full', () async {
    // The control. Keeping revoked work out of the ordinary tables must not
    // stop ordinary sign-out recovery from working.
    await seedTrip('t1', title: 'Rome renamed offline');
    await seedActivity('a1', 't1');
    await queue('q1', 'trip', 't1', SyncOp.update,
        '{"title":"Rome renamed offline"}');
    await queue('q2', 'activity', 'a1', SyncOp.update, '{"title":"Forum"}',
        createdAt: t0.add(const Duration(minutes: 1)));

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();
    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');

    expect((await db.tripsDao.getAll()).single.title, 'Rome renamed offline');
    expect(await db.activitiesDao.getById('a1'), isNotNull);
    expect((await db.syncQueueDao.getPending()).map((r) => r.entityType),
        ['trip', 'activity']);
  });
}
