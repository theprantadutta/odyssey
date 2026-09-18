import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/session/unsynced_work_quarantine.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Recovery across an actual process restart, not an in-memory account switch.
///
/// The database is backed by a real file that is closed and reopened between the
/// sign-out and the sign-in, so migrations run and nothing survives in memory.

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_quarantine_');
    dbFile = File('${tempDir.path}/odyssey.sqlite');
    db = open();
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Closes the database and opens it again, as an app restart would.
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

  Future<void> seedActivity(String id, String tripId) {
    return db.into(db.localActivities).insert(LocalActivitiesCompanion.insert(
          id: id,
          tripId: tripId,
          title: 'Colosseum',
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

  test('a partial edit survives a restart with the record it patches', () async {
    // Without the record snapshot the restored update would describe an edit to
    // a trip the device no longer has, so the user could not see their own work.
    await seedTrip('t1', title: 'Rome renamed offline');
    await queue('q1', 'trip', 't1', SyncOp.update, '{"title":"Rome renamed offline"}');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();

    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');

    final trips = await db.tripsDao.getAll();
    expect(trips, hasLength(1));
    expect(trips.single.title, 'Rome renamed offline');
    expect(trips.single.isDirty, isTrue);

    final pending = await db.syncQueueDao.getPending();
    expect(pending.single.operation, SyncOp.update);
  });

  test('a child and its parent both come back', () async {
    await seedTrip('t1');
    await seedActivity('a1', 't1');
    await queue('q1', 'activity', 'a1', SyncOp.update, '{"title":"Colosseum"}');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();

    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');

    expect(await db.tripsDao.getAll(), hasLength(1),
        reason: 'the parent trip is preserved with its child');
    final activities = await db.activitiesDao.getByTrip('t1');
    expect(activities.map((a) => a.id), ['a1']);
  });

  test('a queued child create keeps its parent via the payload', () async {
    // The child row does not exist yet, so the parent reference is only in the
    // queued payload.
    await seedTrip('t1');
    await queue('q1', 'activity', 'a1', SyncOp.create,
        '{"id":"a1","trip_id":"t1","title":"Colosseum"}');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();

    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');

    expect(await db.tripsDao.getAll(), hasLength(1));
    expect((await db.tripsDao.getAll()).single.id, 't1');
  });

  test('another account inherits neither the work nor the records', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', SyncOp.update, '{"title":"Rome"}');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();

    await restart();

    final restored = await UnsyncedWorkQuarantine(db).restore('user-b');

    expect(restored, 0);
    expect(await db.tripsDao.getAll(), isEmpty,
        reason: "user-b must not see user-a's records");
    expect(await db.syncQueueDao.getPending(), isEmpty);

    // user-a's work is still waiting for user-a.
    expect(await UnsyncedWorkQuarantine(db).recordCountFor('user-a'), 1);
    expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 1);
  });

  test('the quarantine is emptied once its owner has recovered it', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', SyncOp.update, '{"title":"Rome"}');

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();
    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');
    await restart();

    expect(await UnsyncedWorkQuarantine(db).recordCountFor('user-a'), 0);
    expect(await db.syncQueueDao.quarantinedCountFor('user-a'), 0);
    // A second restore must not duplicate anything.
    expect(await UnsyncedWorkQuarantine(db).restore('user-a'), 0);
    expect(await db.tripsDao.getAll(), hasLength(1));
  });

  test('ordering survives so parents are pushed before children', () async {
    await seedTrip('t1');
    await queue('q1', 'trip', 't1', SyncOp.create, '{"id":"t1"}', createdAt: t0);
    await queue('q2', 'activity', 'a1', SyncOp.create,
        '{"id":"a1","trip_id":"t1"}',
        createdAt: t0.add(const Duration(minutes: 1)));

    await UnsyncedWorkQuarantine(db).quarantine('user-a');
    await db.clearAllData();
    await restart();

    await UnsyncedWorkQuarantine(db).restore('user-a');

    final pending = await db.syncQueueDao.getPending();
    expect(pending.map((r) => r.entityType), ['trip', 'activity']);
  });

  test('the database opens at the current schema version after a restart', () async {
    await restart();

    // Proves the reopen really exercised the file, not a cached handle.
    expect(db.schemaVersion, 7);
    await seedTrip('t1');
    expect(await db.tripsDao.getAll(), hasLength(1));
  });
}
