import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/database/model_converters.dart';
import 'package:odyssey/src/core/sync/base_version.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_queue_service.dart';
import 'package:odyssey/src/features/trips/data/models/trip_model.dart';

/// Two failures with one cause: a clock that only counts seconds.
///
/// Drift stores a `DateTime` as unix **seconds**. Two things were resting on
/// that precision and should not have been:
///
///   * **A05** - the outbound `_base_version` came from the local `updatedAt`,
///     so a server revision ending `.321` went back as `.000`. The server read
///     its own row as newer and reported a conflict on a record nobody had
///     touched.
///   * **A06** - queue order came from `createdAt`, and coalescing deliberately
///     reuses the original timestamp, so ties are ordinary rather than rare. A
///     parent create and its child create in the same second could be read
///     child-first and pushed to a server that had never heard of the parent.
void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  AppDatabase open() => AppDatabase.forTesting(NativeDatabase(dbFile));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_revision_');
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

  // ------------------------------------------------------------------- A05

  group('the exact server revision', () {
    /// A revision with milliseconds, as PostgreSQL issues them.
    const serverRevision = '2026-05-01T10:00:00.321456Z';

    TripModel serverTrip() => TripModel(
          id: 't1',
          userId: 'user-a',
          title: 'Kyoto',
          startDate: '2026-05-01',
          endDate: '2026-05-10',
          status: 'planned',
          tags: const [],
          createdAt: '2026-05-01T09:00:00.000Z',
          updatedAt: serverRevision,
          displayCurrency: 'USD',
        );

    test('survives a round trip through the local row', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip()));

      final row = await db.tripsDao.getById('t1');

      // The truncation really happens - this is the defect, still present in
      // the timestamp column and now simply no longer relied upon.
      expect(row!.updatedAt.microsecond, 0);
      expect(row.updatedAt.millisecond, 0);

      // And the exact value is kept beside it.
      expect(row.serverRevision, serverRevision);
      expect(baseVersionOf(row), serverRevision);
    });

    test('an unchanged server record accepts an offline edit', () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip()));

      final existing = await db.tripsDao.getById('t1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {
          'title': 'Kyoto in autumn',
          kBaseVersionKey: baseVersionOf(existing),
        },
      );

      final queued = (await db.syncQueueDao.getPending()).single;
      final payload = jsonDecode(queued.payload) as Map<String, dynamic>;

      // Byte-identical to what the server issued. Anything less and the server
      // sees a base version older than its own row.
      expect(payload[kBaseVersionKey], serverRevision);
    });

    test('a locally created record falls back to its own timestamp', () async {
      // Never acknowledged, so there is no server revision to send - and the
      // server has nothing to compare against either.
      await db.into(db.localTrips).insert(LocalTripsCompanion.insert(
            id: 'local-only',
            userId: 'user-a',
            title: 'Drafted offline',
            startDate: '2026-05-01',
            status: 'planned',
            createdAt: DateTime.utc(2026, 5, 1),
            updatedAt: DateTime.utc(2026, 5, 1, 10),
            isLocalOnly: const Value(true),
          ));

      final row = await db.tripsDao.getById('local-only');

      expect(row!.serverRevision, isNull);

      // UTC, with the zone marker. Drift hands a DateTime back in the device's
      // local zone, so serialising it without converting produces a local time
      // that reads as UTC on the server - wrong by the user's offset.
      expect(baseVersionOf(row), '2026-05-01T10:00:00.000Z');
    });

    test('a competing server change still produces a different base version',
        () async {
      await db.tripsDao.upsert(tripToLocal(serverTrip()));
      final beforeEdit = baseVersionOf(await db.tripsDao.getById('t1'));

      // Somebody else edits it; the next pull brings a new revision.
      await db.tripsDao.upsert(tripToLocal(TripModel(
        id: 't1',
        userId: 'user-a',
        title: 'Renamed by somebody else',
        startDate: '2026-05-01',
        endDate: '2026-05-10',
        status: 'planned',
        tags: const [],
        createdAt: '2026-05-01T09:00:00.000Z',
        updatedAt: '2026-05-01T11:30:00.999888Z',
        displayCurrency: 'USD',
      )));

      final afterEdit = baseVersionOf(await db.tripsDao.getById('t1'));

      expect(afterEdit, isNot(beforeEdit),
          reason: 'a real server change must be distinguishable, or genuine '
              'conflicts stop being detected');
      expect(afterEdit, '2026-05-01T11:30:00.999888Z');
    });
  });

  // ------------------------------------------------------------------- A06

  group('dependency ordering within one second', () {
    final sameSecond = DateTime.utc(2026, 5, 1, 10, 0, 0);

    Future<void> seedTrip(String id) =>
        db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
              id: Value(id),
              userId: const Value('user-a'),
              title: const Value('Parent'),
              startDate: const Value('2026-05-01'),
              status: const Value('planned'),
              createdAt: Value(sameSecond),
              updatedAt: Value(sameSecond),
              isDirty: const Value(true),
            ));

    Future<void> seedActivity(String id, String tripId) =>
        db.into(db.localActivities).insertOnConflictUpdate(
              LocalActivitiesCompanion(
                id: Value(id),
                tripId: Value(tripId),
                title: const Value('Child'),
                scheduledTime: const Value('2026-05-02T10:00:00Z'),
                category: const Value('explore'),
                createdAt: Value(sameSecond),
                updatedAt: Value(sameSecond),
                isDirty: const Value(true),
              ),
            );

    Future<List<String>> pendingEntityTypes() async =>
        (await db.syncQueueDao.getPending()).map((r) => r.entityType).toList();

    test('a parent and child created in the same second stay in order',
        () async {
      await seedTrip('t1');
      await seedActivity('a1', 't1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.create,
        payload: {'id': 't1', 'title': 'Parent'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a1',
        operation: SyncOp.create,
        payload: {'id': 'a1', 'trip_id': 't1', 'title': 'Child'},
      );

      expect(await pendingEntityTypes(), ['trip', 'activity']);
    });

    test('renaming the parent does not move it behind its child', () async {
      await seedTrip('t1');
      await seedActivity('a1', 't1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.create,
        payload: {'id': 't1', 'title': 'Parent'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a1',
        operation: SyncOp.create,
        payload: {'id': 'a1', 'trip_id': 't1', 'title': 'Child'},
      );

      // Coalescing deletes the parent's row and writes a merged one. Carrying
      // the timestamp forward was not enough: the new row has to keep the
      // parent's place in line, or it lands behind the child that depends on
      // it.
      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.update,
        payload: {'title': 'Parent renamed'},
      );

      expect(await pendingEntityTypes(), ['trip', 'activity'],
          reason: 'renaming the parent pushed it behind its own child');

      final parent = (await db.syncQueueDao.getPending()).first;
      expect(parent.operation, SyncOp.create,
          reason: 'the merged operation must stay a create; the server has '
              'never seen this trip');
      expect(parent.payload, contains('Parent renamed'));
    });

    test('a retry does not reorder the queue', () async {
      await seedTrip('t1');
      await seedActivity('a1', 't1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.create,
        payload: {'id': 't1', 'title': 'Parent'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a1',
        operation: SyncOp.create,
        payload: {'id': 'a1', 'trip_id': 't1', 'title': 'Child'},
      );

      // The parent's push fails and returns to the queue.
      final parent = (await db.syncQueueDao.getPending()).first;
      await db.syncQueueDao.markInProgress(parent.id,
          sentRevision: sameSecond, sentAt: sameSecond);
      await SyncQueueService().markFailed(parent.id, 'temporary failure');

      expect(await pendingEntityTypes(), ['trip', 'activity'],
          reason: 'a failed parent came back behind its child');
    });

    test('the order survives an app restart', () async {
      await seedTrip('t1');
      await seedActivity('a1', 't1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.create,
        payload: {'id': 't1', 'title': 'Parent'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a1',
        operation: SyncOp.create,
        payload: {'id': 'a1', 'trip_id': 't1', 'title': 'Child'},
      );

      await restart();

      expect(await pendingEntityTypes(), ['trip', 'activity'],
          reason: 'ordering that lives only in memory is not ordering');
    });

    test('a third entity queued later goes to the back', () async {
      await seedTrip('t1');
      await seedActivity('a1', 't1');
      await seedActivity('a2', 't1');

      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: 't1',
        operation: SyncOp.create,
        payload: {'id': 't1'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a1',
        operation: SyncOp.create,
        payload: {'id': 'a1', 'trip_id': 't1'},
      );
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: 'a2',
        operation: SyncOp.create,
        payload: {'id': 'a2', 'trip_id': 't1'},
      );

      final ids =
          (await db.syncQueueDao.getPending()).map((r) => r.entityId).toList();
      expect(ids, ['t1', 'a1', 'a2']);
    });
  });
}
