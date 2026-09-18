import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_service.dart';

/// Choosing the server version, when the user has kept typing since.
///
/// "Use server version" answers one question: which of the two versions in
/// front of me should win. It is not permission to erase an edit made after
/// that disagreement was recorded - the user may not even connect the two, and
/// from their side the later edit is simply the thing they most recently wrote.
///
/// Resolution used to overwrite the row with the server copy and clear the
/// dirty flag unconditionally, so a newer edit disappeared from the screen
/// while its queued operation stayed behind to be pushed.
void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  final detectedAt = DateTime.utc(2026, 1, 1, 10, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_conflict_');
    dbFile = File('${tempDir.path}/odyssey.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    DatabaseService.overrideForTesting(db);
  });

  tearDown(() async {
    DatabaseService.clearOverrideForTesting();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedTrip(String id, String title, {bool dirty = true}) {
    return db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
          id: Value(id),
          userId: const Value('user-a'),
          title: Value(title),
          startDate: const Value('2026-05-01'),
          status: const Value('planned'),
          createdAt: Value(detectedAt),
          updatedAt: Value(detectedAt),
          isDirty: Value(dirty),
        ));
  }

  SyncConflict conflictFor(String entityId) => SyncConflict(
        id: 'c1',
        entityType: 'trip',
        entityId: entityId,
        localPayload: '{"title":"My version"}',
        serverPayload: '{"title":"Their version","user_id":"user-a",'
            '"start_date":"2026-05-01","status":"planned",'
            '"created_at":"2026-01-01T10:00:00Z",'
            '"updated_at":"2026-01-01T11:00:00Z"}',
        detectedAt: detectedAt,
        detectedSequence: 1,
        isResolved: false,
      );

  test('with no newer edit, the server version wins and the row settles',
      () async {
    await seedTrip('t1', 'My version');
    await db.syncQueueDao.recordConflict(SyncConflictsCompanion(
      id: const Value('c1'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      localPayload: const Value('{"title":"My version"}'),
      serverPayload: const Value('{"title":"Their version"}'),
      detectedAt: Value(detectedAt),
      isResolved: const Value(false),
    ));

    final applied =
        await SyncService().resolveConflictWithServerVersion(conflictFor('t1'));

    expect(applied, isTrue);

    final trip = await db.tripsDao.getById('t1');
    expect(trip!.title, 'Their version');
    expect(trip.isDirty, isFalse,
        reason: 'a settled record left dirty re-pushes the discarded edit');

    expect(await db.syncQueueDao.getUnresolvedConflicts(), isEmpty);
  });

  test('an edit made after the conflict survives choosing the server version',
      () async {
    await seedTrip('t1', 'My version');
    await db.syncQueueDao.recordConflict(SyncConflictsCompanion(
      id: const Value('c1'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      localPayload: const Value('{"title":"My version"}'),
      serverPayload: const Value('{"title":"Their version"}'),
      detectedAt: Value(detectedAt),
      isResolved: const Value(false),
    ));

    // The user keeps working. This edit is newer than the disagreement and is
    // not one of the two versions being chosen between.
    await seedTrip('t1', 'Third thing I typed');
    await db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: const Value('q-later'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      operation: const Value(SyncOp.update),
      payload: const Value('{"title":"Third thing I typed"}'),
      createdAt: Value(detectedAt.add(const Duration(minutes: 5))),
    ));

    final applied =
        await SyncService().resolveConflictWithServerVersion(conflictFor('t1'));

    expect(applied, isTrue);

    final trip = await db.tripsDao.getById('t1');
    expect(trip!.title, 'Third thing I typed',
        reason: 'the edit made after the conflict was silently erased');

    // Other fields come from the server copy: that is what was chosen.
    expect(trip.startDate, '2026-05-01');

    // Still dirty, and still queued, because that newer edit has not been sent.
    expect(trip.isDirty, isTrue,
        reason: 'the surviving edit was marked clean and will never be pushed');
    expect(await db.syncQueueDao.getForEntity('trip', 't1'), hasLength(1));

    expect(await db.syncQueueDao.getUnresolvedConflicts(), isEmpty);
  });

  test('an edit older than the conflict is not treated as newer', () async {
    await seedTrip('t1', 'My version');
    await db.syncQueueDao.recordConflict(SyncConflictsCompanion(
      id: const Value('c1'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      localPayload: const Value('{"title":"My version"}'),
      serverPayload: const Value('{"title":"Their version"}'),
      detectedAt: Value(detectedAt),
      isResolved: const Value(false),
    ));

    // The operation that caused the conflict in the first place. Re-applying it
    // would restore exactly the version the user just rejected.
    await db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: const Value('q-original'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      operation: const Value(SyncOp.update),
      payload: const Value('{"title":"My version"}'),
      createdAt: Value(detectedAt.subtract(const Duration(minutes: 5))),
    ));

    await SyncService().resolveConflictWithServerVersion(conflictFor('t1'));

    final trip = await db.tripsDao.getById('t1');
    expect(trip!.title, 'Their version',
        reason: 'the rejected version was re-applied over the server copy');
    expect(trip.isDirty, isFalse);
  });

  group('two edits in the same stored second', () {
    // Drift stores a DateTime as unix seconds, so a conflict detected at
    // 10:00:00.2 and an edit made at 10:00:00.8 are the same instant as far as
    // the database is concerned. Deciding by timestamp means deciding by luck,
    // and losing the toss silently discards whatever the user typed last.
    //
    // The queue sequence is exact, so these cases are decided rather than
    // guessed.

    Future<void> recordConflictAt(int sequence) {
      return db.syncQueueDao.recordConflict(SyncConflictsCompanion(
        id: const Value('c1'),
        entityType: const Value('trip'),
        entityId: const Value('t1'),
        localPayload: const Value('{"title":"My version"}'),
        serverPayload: const Value('{"title":"Their version"}'),
        detectedAt: Value(detectedAt),
        detectedSequence: Value(sequence),
        isResolved: const Value(false),
      ));
    }

    Future<void> queueAt(int sequence, String operation, String payload) {
      return db.syncQueueDao.enqueue(SyncQueueCompanion(
        id: Value('q$sequence'),
        entityType: const Value('trip'),
        entityId: const Value('t1'),
        operation: Value(operation),
        payload: Value(payload),
        // Deliberately the *same* stored second as the conflict.
        createdAt: Value(detectedAt),
        sequence: Value(sequence),
      ));
    }

    SyncConflict conflictWithSequence(int sequence) => SyncConflict(
          id: 'c1',
          entityType: 'trip',
          entityId: 't1',
          localPayload: '{"title":"My version"}',
          serverPayload: '{"title":"Their version","user_id":"user-a",'
              '"start_date":"2026-05-01","status":"planned",'
              '"created_at":"2026-01-01T10:00:00Z",'
              '"updated_at":"2026-01-01T11:00:00Z"}',
          detectedAt: detectedAt,
          detectedSequence: sequence,
          isResolved: false,
        );

    test('an update in the same second is still recognised as newer', () async {
      await seedTrip('t1', 'My version');
      await recordConflictAt(5);
      await seedTrip('t1', 'Typed a moment later');
      await queueAt(6, SyncOp.update, '{"title":"Typed a moment later"}');

      await SyncService()
          .resolveConflictWithServerVersion(conflictWithSequence(5));

      final trip = await db.tripsDao.getById('t1');
      expect(trip!.title, 'Typed a moment later',
          reason: 'an edit made in the same second as the conflict was '
              'discarded on a timestamp comparison that cannot separate them');
      expect(trip.isDirty, isTrue);
    });

    test('the refused edit in the same second is not treated as newer',
        () async {
      await seedTrip('t1', 'My version');
      await recordConflictAt(5);

      // The operation that caused the conflict: same second, earlier sequence.
      // Re-applying it would restore the very version the user rejected.
      await queueAt(4, SyncOp.update, '{"title":"My version"}');

      await SyncService()
          .resolveConflictWithServerVersion(conflictWithSequence(5));

      final trip = await db.tripsDao.getById('t1');
      expect(trip!.title, 'Their version',
          reason: 'the rejected version was re-applied over the server copy');
      expect(trip.isDirty, isFalse);
    });

    test('a delete queued while the conflict is unresolved survives', () async {
      await seedTrip('t1', 'My version');
      await recordConflictAt(5);

      // The user gives up on the argument and deletes the record instead.
      // Choosing the server version must not resurrect it as a live row.
      await queueAt(6, SyncOp.delete, '{}');

      await SyncService()
          .resolveConflictWithServerVersion(conflictWithSequence(5));

      final pending = await db.syncQueueDao.getForEntity('trip', 't1');
      expect(pending, hasLength(1),
          reason: 'the pending delete was dropped by the resolution');
      expect(pending.single.operation, SyncOp.delete);

      expect(await db.syncQueueDao.getUnresolvedConflicts(), isEmpty);

      final trip = await db.tripsDao.getById('t1');
      expect(trip!.isDirty, isTrue,
          reason: 'the row was marked clean, so the delete will never be sent');
    });
  });

  test('a conflict with an unusable server version changes nothing', () async {
    await seedTrip('t1', 'My version');

    final applied = await SyncService().resolveConflictWithServerVersion(
      SyncConflict(
        id: 'c1',
        entityType: 'trip',
        entityId: 't1',
        localPayload: '{"title":"My version"}',
        serverPayload: '{}',
        detectedAt: detectedAt,
        detectedSequence: 1,
        isResolved: false,
      ),
    );

    expect(applied, isFalse);

    final trip = await db.tripsDao.getById('t1');
    expect(trip!.title, 'My version');
    expect(trip.isDirty, isTrue);
  });
}
