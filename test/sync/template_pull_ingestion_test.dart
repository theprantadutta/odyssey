import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/core/sync/sync_service.dart';

/// A18: a template edited on one device reaching the others.
///
/// The client has always read `changes['templates']`, so this file is not the
/// half that was broken - the server simply never sent the key. What it pins
/// down is the other half of the same contract: that the response the server
/// now produces is one this ingestion path actually lands.
///
/// The fixture is therefore not hand-written. It is the byte output of
/// `PullChangesQueryHandler` serialised with the API's JsonSerializerOptions,
/// captured from the PostgreSQL-backed `TemplatePullSyncTests`. Invented sample
/// JSON is what let two applications disagree about field names for this long;
/// a fixture that came off the real serialiser cannot flatter either side.
class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

/// Answers the pull with [body] and nothing else.
class _PullAdapter implements HttpClientAdapter {
  _PullAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _upsertedId = '11111111-1111-1111-1111-111111111111';
const _deletedId = '22222222-2222-2222-2222-222222222222';
const _accountId = 'e9e2bc9e-b351-4a86-9813-47a63d85f53b';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String serverResponse;

  setUpAll(() async {
    serverResponse =
        await File('test/sync/fixtures/sync_pull_templates.json').readAsString();

    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    final dir = await Directory.systemTemp.createTemp('odyssey-template-pull-');
    PathProviderPlatform.instance = _Paths(dir.path);
    await DatabaseService().initialize();
    DioClient().init();
    DioClient().dio.interceptors.clear();
  });

  setUp(() async {
    await DatabaseService().database.clearAllData();
    AccountSession().end();
    AccountSession().begin(_accountId);
  });

  tearDown(() async {
    await SyncService().stopSession();
  });

  tearDownAll(() async {
    await DatabaseService().close();
  });

  AppDatabase db() => DatabaseService().database;

  /// A template this device already holds, as a previous pull would have left it.
  Future<void> seedLocal(String id, String name) {
    return db().templatesDao.upsert(LocalTemplatesCompanion.insert(
      id: id,
      userId: _accountId,
      name: name,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ));
  }

  Future<void> runPull() async {
    DioClient().dio.httpClientAdapter = _PullAdapter(serverResponse);

    await SyncService().startSession();
    await SyncService().performInitialSync();
  }

  test('a template created on another device lands in the local store',
      () async {
    await runPull();

    final row = await db().templatesDao.getById(_upsertedId);
    expect(row, isNotNull,
        reason: 'the server sent this template and the device did not keep it');
    expect(row!.name, 'Rome in three days');
    expect(row.userId, _accountId);
    expect(row.category, 'city-break');
    expect(row.useCount, 2);
    expect(row.isPublic, isFalse);

    // The structure arrives as a JSON object and is stored as text. Reading it
    // back is what the template screens do, so an escaped-string regression on
    // either side shows up here rather than as an empty itinerary.
    final structure = jsonDecode(row.structureJson) as Map<String, dynamic>;
    expect((structure['activities'] as List).first['title'], 'Colosseum');

    // Clean and server-owned: a row written from a pull must not queue itself
    // straight back to the server as a local change.
    expect(row.isDirty, isFalse);
    expect(row.isLocalOnly, isFalse);
    expect(row.isDeleted, isFalse);

    // Stored verbatim, because it goes back as the base version on the next push.
    expect(row.serverRevision, '2026-09-18T06:34:58.075107Z');
  });

  test('a template deleted on another device leaves the local store', () async {
    await seedLocal(_deletedId, 'Deleted elsewhere');
    expect(await db().templatesDao.getById(_deletedId), isNotNull);

    await runPull();

    expect(await db().templatesDao.getById(_deletedId), isNull,
        reason: 'the deletion was delivered and the row stayed behind');
  });

  // Not an A18 regression test: it passes with or without the server change,
  // because a server that sends no templates also overwrites nothing. It guards
  // the new traffic against the older mistake of a pull flattening unsent work.
  test('an unsent local edit survives the same pull', () async {
    // The upserted id, already here with the user's own unsent change. A pull
    // must not overwrite work that has not reached the server yet.
    await seedLocal(_upsertedId, 'My unsent rename');
    await db().templatesDao.markDirty(_upsertedId);

    await runPull();

    final row = await db().templatesDao.getById(_upsertedId);
    expect(row!.name, 'My unsent rename');
    expect(row.isDirty, isTrue);
  });
}
