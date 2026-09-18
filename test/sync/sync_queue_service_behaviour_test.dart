import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// End-to-end checks that coalescing, applied against real SQL, leaves the queue
/// in the state the repositories depend on.
///
/// [SyncQueueService] reaches the database through a singleton, so these drive
/// the same steps directly against an in-memory database: read the entity's
/// rows, coalesce, delete the merged ones, write the result.

void main() {
  late AppDatabase db;

  final t0 = DateTime.utc(2026, 1, 1, 10, 0);

  // Production uses a UUID; a counter keeps these rows distinct without one.
  var rowSeq = 0;

  setUp(() {
    rowSeq = 0;
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Mirrors SyncQueueService.enqueue against the test database.
  Future<bool> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    required DateTime now,
  }) async {
    return db.transaction(() async {
      final rows = await db.syncQueueDao.getForEntity(entityType, entityId);

      final existing = rows
          .map((row) => QueuedOperation(
                id: row.id,
                operation: row.operation,
                payload: jsonDecode(row.payload) as Map<String, dynamic>,
                createdAt: row.createdAt,
                status: row.status,
              ))
          .toList();

      final result = coalesceOperation(
        existing: existing,
        incomingOperation: operation,
        incomingPayload: payload,
        now: now,
      );

      if (result.idsToDelete.isNotEmpty) {
        await db.syncQueueDao.removeByIds(result.idsToDelete);
      }
      if (!result.writesOperation) return false;

      await db.syncQueueDao.enqueue(SyncQueueCompanion(
        id: Value('row-${rowSeq++}'),
        entityType: Value(entityType),
        entityId: Value(entityId),
        operation: Value(result.operation!),
        payload: Value(jsonEncode(result.payload)),
        createdAt: Value(result.createdAt),
      ));
      return true;
    });
  }

  test('offline create then edit leaves one create carrying the edit', () async {
    // The F02 scenario: go offline, create a trip, rename it. The queue used to
    // hold an update for an ID the server had never seen.
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'id': 't1', 'title': 'Rome'},
      now: t0,
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Rome 2026', kBaseVersionKey: 'v1'},
      now: t0.add(const Duration(minutes: 5)),
    );

    final pending = await db.syncQueueDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOp.create);

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['id'], 't1');
    expect(payload['title'], 'Rome 2026');
    expect(payload.containsKey(kBaseVersionKey), isFalse);
  });

  test('repeated partial edits all survive', () async {
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Rome', kBaseVersionKey: 'v1'},
      now: t0,
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'budget': 500, kBaseVersionKey: 'v2'},
      now: t0.add(const Duration(minutes: 1)),
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'description': 'Anniversary', kBaseVersionKey: 'v3'},
      now: t0.add(const Duration(minutes: 2)),
    );

    final pending = await db.syncQueueDao.getPending();
    expect(pending, hasLength(1));

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['title'], 'Rome');
    expect(payload['budget'], 500);
    expect(payload['description'], 'Anniversary');
    expect(payload[kBaseVersionKey], 'v1',
        reason: 'the merged patch is still relative to the first edit');
  });

  test('offline create then delete queues nothing at all', () async {
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'id': 't1', 'title': 'Rome'},
      now: t0,
    );

    final queued = await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.delete,
      payload: const {},
      now: t0.add(const Duration(minutes: 1)),
    );

    expect(queued, isFalse, reason: 'caller must purge the local row');
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('parent stays ahead of its child after the parent is edited', () async {
    // Dependency order: the trip create must still be sent before the activity
    // create, or the server receives a child for a trip it has never seen.
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'id': 't1', 'title': 'Rome'},
      now: t0,
    );
    await enqueue(
      entityType: 'activity',
      entityId: 'a1',
      operation: SyncOp.create,
      payload: {'id': 'a1', 'trip_id': 't1'},
      now: t0.add(const Duration(minutes: 1)),
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Rome 2026'},
      now: t0.add(const Duration(minutes: 2)),
    );

    final pending = await db.syncQueueDao.getPending();
    expect(pending.map((r) => r.entityType), ['trip', 'activity']);
  });

  test('an in-flight create is left alone and the edit queues behind it', () async {
    await db.syncQueueDao.enqueue(SyncQueueCompanion(
      id: const Value('inflight'),
      entityType: const Value('trip'),
      entityId: const Value('t1'),
      operation: const Value(SyncOp.create),
      payload: const Value('{"title":"Rome"}'),
      status: const Value(SyncStatus.inProgress),
      createdAt: Value(t0),
    ));

    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Rome 2026'},
      now: t0.add(const Duration(minutes: 1)),
    );

    final all = await db.syncQueueDao.getForEntity('trip', 't1');
    expect(all, hasLength(2));
    expect(all.first.id, 'inflight');
    expect(all.first.operation, SyncOp.create);
    expect(all.last.operation, SyncOp.update);
  });

  test('operations for other entities are untouched', () async {
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.create,
      payload: {'title': 'Rome'},
      now: t0,
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't2',
      operation: SyncOp.create,
      payload: {'title': 'Paris'},
      now: t0,
    );
    await enqueue(
      entityType: 'trip',
      entityId: 't1',
      operation: SyncOp.update,
      payload: {'title': 'Rome 2026'},
      now: t0,
    );

    final pending = await db.syncQueueDao.getPending();
    expect(pending, hasLength(2));
    expect(pending.map((r) => r.entityId).toSet(), {'t1', 't2'});
  });
}
