import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';
import 'package:odyssey/src/core/sync/sync_push_limits.dart';
import 'package:odyssey/src/core/sync/sync_queue_service.dart';
import 'package:odyssey/src/core/sync/sync_service.dart';

/// Chunking the outbox so `POST /sync/push` is never sent a batch it refuses.
///
/// The endpoint now caps both the number of operations in one push and the size
/// of the body, and an over-sized batch is refused outright rather than
/// throttled. A client that flushed its whole queue in one request would
/// therefore be permanently unable to reconnect after a long offline session -
/// the very thing the queue exists for.
///
/// What chunking must not cost:
///
///   * **Dependency order.** `SyncQueue.sequence` exists so a parent create is
///     read before its child. Splitting the list in place keeps that; the
///     interesting case is a parent and child that land either side of a
///     boundary, which is built deliberately below.
///   * **Acknowledgement handling.** Each result still has to reach the exact
///     operation, and the exact revision, it was sent for.
///   * **Retry safety.** A batch that fails must not take the batches behind it
///     with it, and must not leave them half-sent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planPushBatches', () {
    // Sizes small enough that the maths is visible; the defaults are the
    // server's numbers and are exercised end to end further down.
    List<List<int>> plan(
      List<int> sizes, {
      int maxOperations = 3,
      int maxBytes = 1000,
    }) =>
        planPushBatches<int>(
          sizes,
          (size) => size,
          maxOperations: maxOperations,
          maxBytes: maxBytes,
        );

    test('an empty queue produces no batches', () {
      expect(plan(const []), isEmpty);
    });

    test('a queue at the operation limit stays one batch', () {
      expect(plan([10, 10, 10]), hasLength(1));
    });

    test('one operation more than the limit becomes two batches', () {
      final batches = plan([10, 10, 10, 10]);

      expect(batches.map((b) => b.length), [3, 1],
          reason: 'the overflow must start a new batch, not stretch this one');
    });

    test('order is preserved across the split', () {
      final batches = plan([1, 2, 3, 4, 5, 6, 7]);

      expect(batches.expand((b) => b).toList(), [1, 2, 3, 4, 5, 6, 7],
          reason: 'anything that reorders the queue can send a child create '
              'before the parent it depends on');
    });

    test('a byte budget splits a batch that is under the operation limit', () {
      // Two of these fit in a thousand bytes; three do not, and the operation
      // limit would never have noticed.
      final batches = plan([400, 400, 400], maxOperations: 100);

      expect(batches.map((b) => b.length), [2, 1]);
    });

    test('every batch it produces is one the server would accept', () {
      final batches = plan(List.filled(20, 300), maxOperations: 5);

      for (final batch in batches) {
        expect(batch.length, lessThanOrEqualTo(5));
        expect(batch.fold<int>(0, (sum, size) => sum + size),
            lessThanOrEqualTo(1000));
      }
    });

    test('an operation larger than the whole budget is sent on its own', () {
      // There is no batch that makes this one fit. Holding it back would block
      // every operation queued behind it for good, so it goes alone - the
      // smallest request that can carry it.
      final batches = plan([10, 5000, 10], maxOperations: 100);

      expect(batches.map((b) => b.length), [1, 1, 1]);
      expect(batches[1].single, 5000);
    });
  });

  group('flushing the queue', () {
    late Directory tempDir;
    late AppDatabase db;
    late _RecordingAdapter adapter;

    setUpAll(() {
      dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
      DioClient().init();
      // The auth interceptor would try to refresh a token against a server that
      // does not exist. What is being measured is the shape of the requests.
      DioClient().dio.interceptors.clear();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('odyssey_push_batch_');
      db = AppDatabase.forTesting(
          NativeDatabase(File('${tempDir.path}/odyssey.sqlite')));
      DatabaseService.overrideForTesting(db);

      adapter = _RecordingAdapter();
      DioClient().dio.httpClientAdapter = adapter;
    });

    tearDown(() async {
      DatabaseService.clearOverrideForTesting();
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final when = DateTime.utc(2026, 5, 1, 10);

    Future<void> seedTrip(String id) =>
        db.into(db.localTrips).insertOnConflictUpdate(LocalTripsCompanion(
              id: Value(id),
              userId: const Value('user-a'),
              title: Value('Trip $id'),
              startDate: const Value('2026-05-01'),
              status: const Value('planned'),
              createdAt: Value(when),
              updatedAt: Value(when),
              isDirty: const Value(true),
            ));

    Future<void> seedActivity(String id, String tripId) =>
        db.into(db.localActivities).insertOnConflictUpdate(
              LocalActivitiesCompanion(
                id: Value(id),
                tripId: Value(tripId),
                title: Value('Activity $id'),
                scheduledTime: const Value('2026-05-02T10:00:00Z'),
                category: const Value('explore'),
                createdAt: Value(when),
                updatedAt: Value(when),
                isDirty: const Value(true),
              ),
            );

    Future<void> queueTrip(String id, {String? notes}) async {
      await seedTrip(id);
      await SyncQueueService().enqueue(
        entityType: 'trip',
        entityId: id,
        operation: SyncOp.create,
        payload: {
          'id': id,
          'title': 'Trip $id',
          'description': ?notes,
        },
      );
    }

    Future<void> queueActivity(String id, String tripId) async {
      await seedActivity(id, tripId);
      await SyncQueueService().enqueue(
        entityType: 'activity',
        entityId: id,
        operation: SyncOp.create,
        payload: {'id': id, 'trip_id': tripId, 'title': 'Activity $id'},
      );
    }

    /// The entity ids in every request, in the order they were sent.
    List<String> sentIds() => adapter.requests
        .expand((batch) => batch.map((c) => c['entity_id'] as String))
        .toList();

    // ------------------------------------------------------------ the control

    test('an ordinary queue still goes in a single request', () async {
      await queueTrip('t1');
      await queueActivity('a1', 't1');
      await queueActivity('a2', 't1');

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isTrue);
      expect(adapter.requests, hasLength(1),
          reason: 'a queue well inside the limit must not be split up');
      expect(adapter.requests.single, hasLength(3));
      expect(await db.syncQueueDao.getPending(), isEmpty);
    });

    // ------------------------------------------------- spanning several batches

    test(
        'a queue past the operation limit lands exactly once, in order, '
        'with a parent and its child either side of the boundary', () async {
      // Filler first, so the parent trip is the very last operation that fits in
      // batch one and its child is the first of batch two. That is the case a
      // naive chunker gets wrong: the child is pushed to a server that has not
      // yet been told about the parent.
      await seedTrip('filler-trip');
      for (var i = 0; i < kMaxOperationsPerBatch - 1; i++) {
        await queueActivity('filler-$i', 'filler-trip');
      }
      await queueTrip('parent');
      await queueActivity('child', 'parent');

      final queued = await db.syncQueueDao.getPending();
      expect(queued, hasLength(kMaxOperationsPerBatch + 1),
          reason: 'the queue has to straddle the boundary or this proves '
              'nothing');

      final clean = await SyncService().pushQueueForTesting();
      expect(clean, isTrue);

      // Two requests, split at the documented limit.
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0], hasLength(kMaxOperationsPerBatch));
      expect(adapter.requests[1], hasLength(1));

      // The parent closes the first batch; the child opens the second. A parent
      // create in a *later* batch than its child is the failure this ordering
      // exists to prevent.
      expect(adapter.requests[0].last['entity_id'], 'parent');
      expect(adapter.requests[1].single['entity_id'], 'child');

      // Every operation sent once, and in the order the queue held them.
      final sent = sentIds();
      expect(sent, queued.map((row) => row.entityId).toList());
      expect(sent.toSet(), hasLength(sent.length),
          reason: 'an operation sent in two batches would be applied twice');

      // And the acknowledgements were applied: nothing is left queued or in
      // flight.
      expect(await db.syncQueueDao.getPending(), isEmpty);
      expect(await db.syncQueueDao.getInProgress(), isEmpty);
    });

    test('no batch it builds is one the server would refuse', () async {
      await seedTrip('filler-trip');
      for (var i = 0; i < kMaxOperationsPerBatch + 20; i++) {
        await queueActivity('filler-$i', 'filler-trip');
      }

      await SyncService().pushQueueForTesting();

      expect(adapter.requests.length, greaterThan(1));
      for (final batch in adapter.requests) {
        expect(batch.length, lessThanOrEqualTo(kMaxOperationsPerBatch));
      }
      for (final body in adapter.bodyBytes) {
        expect(body, lessThanOrEqualTo(kMaxPushBodyBytes));
      }
    });

    test('a queue of heavy payloads is split on size, not on count', () async {
      // Ten operations is nowhere near the operation limit, but a third of a
      // megabyte each is past the body limit. Counting alone would build a
      // request the server refuses.
      final bulky = 'x' * (300 * 1024);
      for (var i = 0; i < 10; i++) {
        await queueTrip('heavy-$i', notes: bulky);
      }

      await SyncService().pushQueueForTesting();

      expect(adapter.requests.length, greaterThan(1),
          reason: 'ten heavy operations were sent as one over-sized body');
      for (final batch in adapter.requests) {
        expect(batch.length, lessThan(kMaxOperationsPerBatch));
      }
      for (final body in adapter.bodyBytes) {
        expect(body, lessThanOrEqualTo(kMaxPushBodyBytes));
      }
      expect(sentIds(), hasLength(10));
      expect(await db.syncQueueDao.getPending(), isEmpty);
    });

    // -------------------------------------------------------- retry safety

    test('a failed first batch leaves the whole queue pending and unsent',
        () async {
      await seedTrip('filler-trip');
      for (var i = 0; i < kMaxOperationsPerBatch + 5; i++) {
        await queueActivity('filler-$i', 'filler-trip');
      }
      adapter.failFrom = 0;

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isFalse);
      expect(adapter.requests, hasLength(1),
          reason: 'the batches behind a failed one must not be sent; their '
              'parents may be in the batch that just failed');

      // Nothing lost, nothing stranded in flight.
      final pending = await db.syncQueueDao.getPending();
      expect(pending, hasLength(kMaxOperationsPerBatch + 5));
      expect(await db.syncQueueDao.getInProgress(), isEmpty);
    });

    test('a failure part way through leaves only the remainder queued',
        () async {
      await seedTrip('filler-trip');
      for (var i = 0; i < kMaxOperationsPerBatch + 5; i++) {
        await queueActivity('filler-$i', 'filler-trip');
      }
      adapter.failFrom = 1;

      final clean = await SyncService().pushQueueForTesting();

      expect(clean, isFalse);
      expect(adapter.requests, hasLength(2));

      // The acknowledged batch is settled and is not queued again; the batch
      // that failed is back in the queue, with nothing duplicated either way.
      final pending = await db.syncQueueDao.getPending();
      expect(pending, hasLength(5));
      expect(await db.syncQueueDao.getInProgress(), isEmpty);

      final acknowledged = adapter.requests[0]
          .map((c) => c['entity_id'] as String)
          .toSet();
      expect(pending.where((row) => acknowledged.contains(row.entityId)),
          isEmpty,
          reason: 'operations the server acknowledged were queued again');
    });
  });
}

/// A transport that answers every change with `ok` and keeps what it was sent.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <List<Map<String, dynamic>>>[];
  final bodyBytes = <int>[];

  /// The index of the first request to fail, if any.
  int? failFrom;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data as Map<String, dynamic>;
    final changes = (body['changes'] as List).cast<Map<String, dynamic>>();

    requests.add(changes);
    bodyBytes.add(utf8.encode(jsonEncode(body)).length);

    if (failFrom != null && requests.length - 1 >= failFrom!) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'unavailable'}),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'server_time': DateTime.now().toUtc().toIso8601String(),
        'results': [
          for (final change in changes)
            {
              'entity_type': change['entity_type'],
              'entity_id': change['entity_id'],
              'status': 'ok',
            },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
