import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/database/model_converters.dart';
import 'package:odyssey/src/core/session/unsynced_work_quarantine.dart';
import 'package:odyssey/src/core/sync/base_version.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_queue_service.dart';
import 'package:odyssey/src/features/trips/data/models/trip_model.dart';

/// A save the server refuses must not look like a save that worked.
///
/// Removing the repositories' own immediate request (audit A04) means a save
/// now returns as soon as the local write and the queue entry are done. That is
/// the local-first contract, and it is only honest if a later refusal is still
/// visible: the record must stay dirty, the operation must stay queued carrying
/// the server's reason, and the cycle must not report a clean idle state.
///
/// The failure being guarded against is the one that reads as success forever -
/// a queued edit the server will never accept, sitting behind a tick.
void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_rejected_');
    dbFile = File('${tempDir.path}/odyssey.sqlite');
    db = open();
    DatabaseService.overrideForTesting(db);
  });

  tearDown(() async {
    DatabaseService.clearOverrideForTesting();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> restart() async {
    await db.close();
    db = open();
    DatabaseService.overrideForTesting(db);
  }

  Future<void> seedTrip(String id, String title, {bool dirty = true}) {
    return db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
          id: Value(id),
          userId: const Value('user-a'),
          title: Value(title),
          startDate: const Value('2026-05-01'),
          status: const Value('planned'),
          createdAt: Value(DateTime.utc(2026, 1, 1)),
          updatedAt: Value(DateTime.utc(2026, 1, 1)),
          isDirty: Value(dirty),
        ));
  }

  group('a refused save stays visible', () {
    test('the operation stays queued carrying the reason', () async {
      await seedTrip('t1', 'Renamed offline');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Renamed offline'},
      );

      final queued = (await db.syncQueueDao.getPending()).single;

      // The shape of a refusal the user has to act on: over a plan limit, which
      // no amount of retrying can clear.
      await SyncQueueService().markFailed(
        queued.id,
        "The trip owner's plan has no room for another activity.");

      final after = await db.syncQueueDao.getForEntity('trip', 't1');
      expect(after, hasLength(1),
          reason: 'a refused operation was dropped, so the edit is lost and '
              'the user is never told');
      expect(after.single.lastError, contains('no room'),
          reason: 'the reason must survive, or the UI can only say '
              '"something went wrong"');
    });

    test('the record stays dirty so it is not shown as saved', () async {
      await seedTrip('t1', 'Renamed offline');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Renamed offline'},
      );

      final queued = (await db.syncQueueDao.getPending()).single;
      await SyncQueueService().markFailed(queued.id, 'Rejected');

      expect((await db.tripsDao.getById('t1'))!.isDirty, isTrue);
    });

    test('the refusal survives a restart', () async {
      await seedTrip('t1', 'Renamed offline');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Renamed offline'},
      );

      final queued = (await db.syncQueueDao.getPending()).single;
      await SyncQueueService().markFailed(queued.id, 'Rejected by the server');

      await restart();

      final after = await db.syncQueueDao.getForEntity('trip', 't1');
      expect(after.single.lastError, 'Rejected by the server');
      expect((await db.tripsDao.getById('t1'))!.isDirty, isTrue);
    });

    test('the pending count keeps reporting the unsent work', () async {
      await seedTrip('t1', 'Renamed offline');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Renamed offline'},
      );

      final queued = (await db.syncQueueDao.getPending()).single;
      await SyncQueueService().markFailed(queued.id, 'Rejected');

      // What the status indicator counts. Zero here is the state that reads as
      // "everything saved".
      expect(await db.syncQueueDao.getPendingCount(), 1);
    });
  });

  // --------------------------------------------- serverRevision end to end

  group('the exact server revision', () {
    const revision = '2026-05-01T10:00:00.321456Z';

    TripModel serverTrip(String title, String updatedAt) => TripModel(
          id: 't1',
          userId: 'user-a',
          title: title,
          startDate: '2026-05-01',
          endDate: '2026-05-10',
          status: 'planned',
          tags: const [],
          createdAt: '2026-05-01T09:00:00.000Z',
          updatedAt: updatedAt,
          displayCurrency: 'USD',
        );

    test('survives a pull', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip('Kyoto', revision)));

      expect(baseVersionOf(await db.tripsDao.getById('t1')), revision);
    });

    test('survives an acknowledgement that rewrites the row', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip('Kyoto', revision)));

      // The server's normalised copy coming back on a push acknowledgement,
      // with a new revision. The new one must replace the old one exactly.
      const acknowledged = '2026-05-01T12:34:56.987654Z';
      await db.tripsDao.upsert(
          tripToLocal(serverTrip('Kyoto normalised', acknowledged)));

      expect(baseVersionOf(await db.tripsDao.getById('t1')), acknowledged);
    });

    test('survives a local edit, which does not invent a revision', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip('Kyoto', revision)));

      // An offline edit touches updatedAt and isDirty. It must not touch the
      // server's revision: the next push still has to say which server version
      // the edit was made against.
      await (db.update(db.localTrips)..where((t) => t.id.equals('t1'))).write(
        LocalTripsCompanion(
          title: const Value('Renamed offline'),
          updatedAt: Value(DateTime.utc(2026, 6, 1)),
          isDirty: const Value(true),
        ),
      );

      final row = await db.tripsDao.getById('t1');
      expect(row!.title, 'Renamed offline');
      expect(baseVersionOf(row), revision,
          reason: 'a local edit overwrote the server revision, so the push '
              'would claim to be based on something the server never issued');
    });

    test('survives quarantine, sign-out and restore', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip('Kyoto', revision)));

      await (db.update(db.localTrips)..where((t) => t.id.equals('t1')))
          .write(const LocalTripsCompanion(isDirty: Value(true)));

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Renamed offline', kBaseVersionKey: revision},
      );

      final quarantine = UnsyncedWorkQuarantineForTest(db);
      await quarantine.quarantine('user-a');
      await db.clearAllData();

      await restart();
      await UnsyncedWorkQuarantineForTest(db).restore('user-a');

      expect(baseVersionOf(await db.tripsDao.getById('t1')), revision,
          reason: 'the snapshot dropped the server revision, so the restored '
              'edit would conflict against a record nobody changed');
    });

    test('survives a restart on its own', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip('Kyoto', revision)));

      await restart();

      expect(baseVersionOf(await db.tripsDao.getById('t1')), revision);
    });
  });
}

/// Thin alias so the quarantine import stays beside its use.
typedef UnsyncedWorkQuarantineForTest = UnsyncedWorkQuarantine;
