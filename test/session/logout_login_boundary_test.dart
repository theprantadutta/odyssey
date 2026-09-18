import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/core/services/storage_service.dart';
import 'package:odyssey/src/core/services/token_refresh_service.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/core/sync/sync_service.dart';
import 'package:odyssey/src/features/trips/data/repositories/trip_repository.dart';

/// Signing out and straight back in as somebody else.
///
/// The interesting window is narrow and entirely realistic: an account switch
/// on one screen while a refresh, an initial sync and a couple of ordinary
/// requests are still outstanding. Each of those ends in a write, and each
/// write goes to storage shared by whoever is signed in - the token store, the
/// database, the sync watermark.
///
/// The refresh is the worst of them. Its writes are the credentials every later
/// request is sent with, so a stale one does not merely corrupt data, it hands
/// the new session the previous account's identity.
class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

class _Pending {
  _Pending(this.options);

  final RequestOptions options;
  final Completer<ResponseBody> response = Completer<ResponseBody>();

  void complete(Map<String, dynamic> body, {int status = 200}) {
    response.complete(ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    ));
  }
}

class _HeldAdapter implements HttpClientAdapter {
  final List<_Pending> requests = <_Pending>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final pending = _Pending(options);
    requests.add(pending);
    return pending.response.future;
  }

  @override
  void close({bool force = false}) {}

  Future<_Pending> request(int index) async {
    for (var i = 0; i < 500 && requests.length <= index; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return requests[index];
  }

  Future<_Pending> matching(String path) async {
    for (var i = 0; i < 500; i++) {
      for (final r in requests) {
        if (r.options.path.contains(path) && !r.response.isCompleted) return r;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw StateError('no request for $path');
  }
}

Map<String, dynamic> _tripJson(String title) => {
      'id': 'trip',
      'user_id': 'account-a',
      'title': title,
      'start_date': '2026-09-01',
      'end_date': '2026-09-02',
      'status': 'planned',
      'tags': <String>[],
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
      'display_currency': 'USD',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeldAdapter adapter;
  final storage = StorageService();

  setUpAll(() async {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    final dir = await Directory.systemTemp.createTemp('odyssey-boundary-');
    PathProviderPlatform.instance = _Paths(dir.path);
    await DatabaseService().initialize();
    DioClient().init();
    DioClient().dio.interceptors.clear();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await DatabaseService().database.clearAllData();
    adapter = _HeldAdapter();
    DioClient().dio.httpClientAdapter = adapter;
    AccountSession().end();
    AccountSession().begin('account-a');
  });

  tearDownAll(() async {
    await DatabaseService().close();
  });

  /// Signs out and immediately signs in as [next], as the app does on a switch.
  Future<void> switchTo(String next) async {
    AccountSession().end();
    await DatabaseService().clearAllData();
    AccountSession().begin(next);
  }

  group('a token refresh that outlives its session', () {
    test('does not overwrite the next account\'s tokens', () async {
      TokenRefreshService().refreshDioForTesting.httpClientAdapter = adapter;

      await storage.saveRefreshToken('account-a-refresh');
      await storage.saveAccessToken('account-a-access');

      final refreshing = TokenRefreshService().refreshToken();
      final request = await adapter.matching('refresh');

      // The switch happens while A's refresh is still in the air, and B signs
      // in with its own tokens.
      await switchTo('account-b');
      await storage.saveAccessToken('account-b-access');
      await storage.saveRefreshToken('account-b-refresh');

      request.complete({
        'access_token': 'account-a-rotated',
        'refresh_token': 'account-a-rotated-refresh',
        'expires_in': 900,
      });

      expect(await refreshing, isFalse,
          reason: 'a refresh for a dead session reported success');

      expect(await storage.getAccessToken(), 'account-b-access',
          reason: "account A's refreshed token replaced account B's");
      expect(await storage.getRefreshToken(), 'account-b-refresh');
    });

    test('does not sign the next account out when rejected', () async {
      TokenRefreshService().refreshDioForTesting.httpClientAdapter = adapter;

      await storage.saveRefreshToken('account-a-refresh');

      final refreshing = TokenRefreshService().refreshToken();
      final request = await adapter.matching('refresh');

      await switchTo('account-b');
      await storage.saveAccessToken('account-b-access');
      await storage.saveRefreshToken('account-b-refresh');

      // A's refresh token was revoked by the sign-out. The 401 belongs to A.
      request.complete({'error': 'invalid refresh token'}, status: 401);

      expect(await refreshing, isFalse);

      // clearAuthData() here would have signed B out of an app they just
      // signed in to.
      expect(await storage.getAccessToken(), 'account-b-access',
          reason: "a 401 for account A cleared account B's session");
      expect(await storage.getRefreshToken(), 'account-b-refresh');
    });

    test('still stores its tokens when the session has not changed', () async {
      // The control: the guard must not break ordinary refresh.
      TokenRefreshService().refreshDioForTesting.httpClientAdapter = adapter;

      await storage.saveRefreshToken('account-a-refresh');
      await storage.saveAccessToken('account-a-access');

      final refreshing = TokenRefreshService().refreshToken();
      (await adapter.matching('refresh')).complete({
        'access_token': 'account-a-rotated',
        'refresh_token': 'account-a-rotated-refresh',
        'expires_in': 900,
      });

      expect(await refreshing, isTrue);
      expect(await storage.getAccessToken(), 'account-a-rotated');
      expect(await storage.getRefreshToken(), 'account-a-rotated-refresh');
    });
  });

  group('an initial sync that outlives its session', () {
    test('writes nothing into the next account\'s database', () async {
      await SyncService().startSession();

      final syncing = SyncService().performInitialSync();
      final pull = await adapter.matching('sync/pull');

      await switchTo('account-b');

      pull.complete({
        'server_time': '2026-09-17T10:00:00Z',
        'changes': {
          'trips': {
            'upserted': [_tripJson('Account A private title')],
            'deleted': <String>[],
          },
        },
      });

      await syncing;

      final db = DatabaseService().database;
      expect(await db.tripsDao.getById('trip'), isNull,
          reason: "a full pull for account A populated account B's database");

      // The watermark too - recording this pull against B would make B skip
      // changes it has never seen.
      expect(await db.syncQueueDao.getLastSyncAt(), isNull,
          reason: "account A's sync watermark was recorded against account B");

      await SyncService().stopSession();
    });

    test('is awaited by stopSession, so teardown does not race it', () async {
      await SyncService().startSession();

      var finished = false;
      unawaited(SyncService().performInitialSync().then((_) {
        finished = true;
      }));

      final pull = await adapter.matching('sync/pull');

      final stopping = SyncService().stopSession();

      // stopSession must not return while the pull is still outstanding; if it
      // does, the database is cleared underneath a write that is still coming.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(finished, isFalse);

      pull.complete({
        'server_time': '2026-09-17T10:00:00Z',
        'changes': <String, dynamic>{},
      });

      await stopping;
      expect(finished, isTrue,
          reason: 'stopSession returned without awaiting the initial sync');
    });
  });

  group('a repository response that outlives its session', () {
    test('is dropped across an immediate logout and login', () async {
      final operation = TripRepository().getTripById('trip');
      final request = await adapter.request(0);

      await switchTo('account-b');

      request.complete(_tripJson('Account A private title'));

      try {
        await operation;
      } catch (_) {}

      expect(await DatabaseService().database.tripsDao.getById('trip'), isNull);
    });
  });
}
