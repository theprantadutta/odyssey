import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_queue_service.dart';

/// A second edit made while the first is still in flight (audit A04).
///
/// Repositories used to enqueue an operation and *also* issue the request
/// themselves, then overwrite the local row from that response and call
/// `removeForEntity` - which deletes every queued operation for the entity, not
/// just the one that was acknowledged. Edit 1 returning success therefore erased
/// edit 2 from the row and from the queue, and edit 2's own request failing did
/// not bring it back, because there was nothing left to retry.
///
/// There is now one write transport. These drive the real
/// [SyncQueueService] and the real database; what they assert is that a second
/// edit survives in the queue whatever happens to the first request.
void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_lost_edit_');
    dbFile = File('${tempDir.path}/odyssey.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    DatabaseService.overrideForTesting(db);
  });

  tearDown(() async {
    DatabaseService.clearOverrideForTesting();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedTrip(String id, String title) {
    return db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
          id: Value(id),
          userId: const Value('user-a'),
          title: Value(title),
          startDate: const Value('2026-05-01'),
          status: const Value('planned'),
          createdAt: Value(DateTime.utc(2026, 1, 1)),
          updatedAt: Value(DateTime.utc(2026, 1, 1)),
          isDirty: const Value(true),
        ));
  }

  test('a second edit survives the first request succeeding', () async {
    await seedTrip('t1', 'Original');

    // Edit 1 is queued and handed to the transport.
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Edit one'},
    );

    final inFlight = (await db.syncQueueDao.getPending()).single;
    await db.syncQueueDao.markInProgress(inFlight.id, sentRevision: DateTime.utc(2026, 1, 1), sentAt: DateTime.utc(2026, 1, 1));

    // Edit 2 is made while edit 1 is still out. It must not merge into the row
    // that is already being sent - that operation's acknowledgement is for the
    // older payload.
    await seedTrip('t1', 'Edit two');
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Edit two'},
    );

    // Edit 1 comes back successful and is settled, exactly as the sync service
    // settles it: by id, not by entity.
    await db.syncQueueDao.removeByIds([inFlight.id]);

    final remaining = await db.syncQueueDao.getForEntity('trip', 't1');
    expect(remaining, hasLength(1),
        reason: 'settling edit one removed edit two from the queue');
    expect(remaining.single.payload, contains('Edit two'));

    expect((await db.tripsDao.getById('t1'))!.title, 'Edit two',
        reason: 'the local row was overwritten by the older response');
  });

  test('a second edit survives its own request failing', () async {
    await seedTrip('t1', 'Original');

    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Edit one'},
    );
    final first = (await db.syncQueueDao.getPending()).single;
    await db.syncQueueDao.markInProgress(first.id, sentRevision: DateTime.utc(2026, 1, 1), sentAt: DateTime.utc(2026, 1, 1));

    await seedTrip('t1', 'Edit two');
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Edit two'},
    );

    await db.syncQueueDao.removeByIds([first.id]);

    // Edit 2's own attempt fails transiently. A failure must leave it queued to
    // retry, not drop it.
    final second = (await db.syncQueueDao.getPending()).single;
    await SyncQueueService().markFailed(second.id, 'network unreachable');

    final stillQueued = await db.syncQueueDao.getForEntity('trip', 't1');
    expect(stillQueued, hasLength(1));
    expect(stillQueued.single.payload, contains('Edit two'));
    expect((await db.tripsDao.getById('t1'))!.title, 'Edit two');
    expect((await db.tripsDao.getById('t1'))!.isDirty, isTrue,
        reason: 'an unsent edit must stay dirty so it is pushed again');
  });

  test('create then edit while the create is in flight stays a create',
      () async {
    await seedTrip('t1', 'New trip');

    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'id': 't1', 'title': 'New trip'},
    );
    final create = (await db.syncQueueDao.getPending()).single;
    await db.syncQueueDao.markInProgress(create.id, sentRevision: DateTime.utc(2026, 1, 1), sentAt: DateTime.utc(2026, 1, 1));

    // Renamed before the create has been acknowledged. The server has never
    // heard of this entity, so the follow-up cannot be sent as an update.
    await seedTrip('t1', 'Renamed before it landed');
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Renamed before it landed'},
    );

    await db.syncQueueDao.removeByIds([create.id]);

    final remaining = await db.syncQueueDao.getForEntity('trip', 't1');
    expect(remaining, hasLength(1));
    expect(remaining.single.payload, contains('Renamed before it landed'));
  });

  test('create then delete while the create is in flight leaves no orphan',
      () async {
    await seedTrip('t1', 'New trip');

    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'id': 't1', 'title': 'New trip'},
    );
    final create = (await db.syncQueueDao.getPending()).single;
    await db.syncQueueDao.markInProgress(create.id, sentRevision: DateTime.utc(2026, 1, 1), sentAt: DateTime.utc(2026, 1, 1));

    // Deleted while the create is out. The create may well have committed on
    // the server, so the delete has to be sent - dropping both would leave a
    // record the user deleted alive on the server and invisible here.
    final queued = await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.delete,
      payload: {},
    );

    await db.syncQueueDao.removeByIds([create.id]);

    expect(queued, isTrue,
        reason: 'a delete racing an in-flight create was cancelled outright, '
            'so the server keeps a record the user deleted');

    final remaining = await db.syncQueueDao.getForEntity('trip', 't1');
    expect(remaining, hasLength(1));
    expect(remaining.single.operation, SyncOp.delete);
  });
}
