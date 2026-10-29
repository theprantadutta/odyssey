import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/database/model_converters.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/features/activities/data/models/activity_model.dart';
import 'package:odyssey/src/features/activities/data/repositories/activity_repository.dart';
import 'package:odyssey/src/features/packing/data/models/packing_model.dart';
import 'package:odyssey/src/features/packing/data/repositories/packing_repository.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

/// Records every request that reaches the network.
class _RecordingAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ActivityModel _activity(String id, int sortOrder) => ActivityModel(
      id: id,
      tripId: 'trip',
      title: id,
      scheduledTime: '2026-09-01T10:00:00Z',
      category: 'activity',
      sortOrder: sortOrder,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    );

PackingItemModel _item(String id, int sortOrder, {bool packed = false}) =>
    PackingItemModel(
      id: id,
      tripId: 'trip',
      name: id,
      category: 'clothing',
      isPacked: packed,
      quantity: 1,
      sortOrder: sortOrder,
      createdAt: '2026-09-01T10:00:00Z',
      updatedAt: '2026-09-01T10:00:00Z',
    );

/// Reordering and bulk-ticking are edits like any other: they go through the
/// sync queue. They used to call a bulk endpoint directly and queue nothing,
/// so anything done offline, or whose request failed, never reached the
/// server - and the dirty rows left behind were skipped by every later pull.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingAdapter adapter;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    final dir = await Directory.systemTemp.createTemp('odyssey-bulk-');
    PathProviderPlatform.instance = _Paths(dir.path);
    await DatabaseService().initialize();
    DioClient().init();
    DioClient().dio.interceptors.clear();
  });

  setUp(() async {
    await DatabaseService().database.clearAllData();
    adapter = _RecordingAdapter();
    DioClient().dio.httpClientAdapter = adapter;
    // Signed in and online: exactly when the old code went to the network
    // directly. No sync session is started, so anything that reaches the
    // network here was sent by the repository itself.
    AccountSession().end();
    AccountSession().begin('account-a');
  });

  tearDownAll(() async {
    AccountSession().end();
    await DatabaseService().close();
  });

  Future<List<Map<String, Object?>>> queued() async {
    final rows =
        await DatabaseService().database.syncQueueDao.getAllOperations();
    return [
      for (final row in rows)
        {
          'type': row.entityType,
          'id': row.entityId,
          'op': row.operation,
          ...(jsonDecode(row.payload) as Map<String, dynamic>)
            ..remove('_base_version'),
        },
    ];
  }

  test('reordering activities queues an update for each one that moved',
      () async {
    final db = DatabaseService().database;
    for (final a in [_activity('a', 0), _activity('b', 1), _activity('c', 2)]) {
      await db.activitiesDao.upsert(activityToLocal(a));
    }

    await ActivityRepository().reorderActivities(
      tripId: 'trip',
      activityOrders: [
        ActivityOrder(id: 'c', sortOrder: 0),
        ActivityOrder(id: 'a', sortOrder: 1),
        ActivityOrder(id: 'b', sortOrder: 2),
      ],
    );

    expect(await queued(), unorderedEquals([
      {'type': 'activity', 'id': 'c', 'op': 'update', 'sort_order': 0},
      {'type': 'activity', 'id': 'a', 'op': 'update', 'sort_order': 1},
      {'type': 'activity', 'id': 'b', 'op': 'update', 'sort_order': 2},
    ]));
    expect((await db.activitiesDao.getById('c'))!.sortOrder, 0);
    expect(adapter.paths, isEmpty, reason: 'the sync service sends it');
  });

  test('an activity that kept its place is not queued', () async {
    final db = DatabaseService().database;
    for (final a in [_activity('a', 0), _activity('b', 1), _activity('c', 2)]) {
      await db.activitiesDao.upsert(activityToLocal(a));
    }

    await ActivityRepository().reorderActivities(
      tripId: 'trip',
      activityOrders: [
        ActivityOrder(id: 'b', sortOrder: 0),
        ActivityOrder(id: 'a', sortOrder: 1),
        ActivityOrder(id: 'c', sortOrder: 2),
      ],
    );

    expect((await queued()).map((op) => op['id']), unorderedEquals(['a', 'b']));
  });

  test('bulk-ticking queues only the items that change', () async {
    final db = DatabaseService().database;
    await db.packingDao.upsert(packingItemToLocal(_item('socks', 0)));
    await db.packingDao.upsert(packingItemToLocal(_item('hat', 1, packed: true)));

    await PackingRepository().bulkTogglePacked(
      tripId: 'trip',
      itemIds: ['socks', 'hat'],
      isPacked: true,
    );

    expect(await queued(), [
      {'type': 'packing_item', 'id': 'socks', 'op': 'update', 'is_packed': true},
    ]);
    expect((await db.packingDao.getById('socks'))!.isPacked, isTrue);
    expect(adapter.paths, isEmpty);
  });

  test('reordering packing items queues an update for each one that moved',
      () async {
    final db = DatabaseService().database;
    await db.packingDao.upsert(packingItemToLocal(_item('socks', 0)));
    await db.packingDao.upsert(packingItemToLocal(_item('hat', 1)));

    await PackingRepository().reorderPackingItems(
      tripId: 'trip',
      itemOrders: [
        ItemOrderData(id: 'hat', sortOrder: 0),
        ItemOrderData(id: 'socks', sortOrder: 1),
      ],
    );

    expect(await queued(), unorderedEquals([
      {'type': 'packing_item', 'id': 'hat', 'op': 'update', 'sort_order': 0},
      {'type': 'packing_item', 'id': 'socks', 'op': 'update', 'sort_order': 1},
    ]));
    expect(adapter.paths, isEmpty);
  });

  test('queued reorders survive having no connection or account at all',
      () async {
    AccountSession().end();
    final db = DatabaseService().database;
    await db.activitiesDao.upsert(activityToLocal(_activity('a', 0)));
    await db.activitiesDao.upsert(activityToLocal(_activity('b', 1)));

    await ActivityRepository().reorderActivities(
      tripId: 'trip',
      activityOrders: [
        ActivityOrder(id: 'b', sortOrder: 0),
        ActivityOrder(id: 'a', sortOrder: 1),
      ],
    );

    expect(await queued(), hasLength(2),
        reason: 'waiting for the next sync, not lost');
  });
}
