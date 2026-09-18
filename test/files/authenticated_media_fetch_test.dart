import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:odyssey/src/core/config/api_config.dart';
import 'package:odyssey/src/core/network/authenticated_media_fetch.dart';
import 'package:odyssey/src/core/services/storage_service.dart';
import 'package:odyssey/src/core/services/token_refresh_service.dart';
import 'package:odyssey/src/core/session/account_session.dart';
import 'package:odyssey/src/core/utils/authenticated_media.dart';

/// What a media fetch does when the token it was given has expired (audit A22).
///
/// Images, video and PDFs are fetched by the cache manager, not by `DioClient`,
/// so they never passed through `AuthInterceptor` and had no refresh of their
/// own. A widget carried a synchronous snapshot of the bearer token taken when
/// it built; with a fifteen minute token lifetime, reading locally cached trip
/// data for a while and then opening a photo sent an expired token, got a 401,
/// and showed a broken image that nothing ever retried.
///
/// These drive the real fetch layer against the real `TokenRefreshService` and
/// the real `StorageService`. Only the two transports are substituted, so what
/// the refresh actually writes - and, in the last test, does not write - is
/// observable.
///
/// The last test guards the fix rather than the defect: before this layer
/// existed nothing refreshed, so nothing could refresh for the wrong account
/// either. It fails against the obvious wrong version of the fix - refresh on
/// any 401 - which is what it is here to stop.

/// Records what the media layer asked for and answers with a queued reply.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._replies);

  final List<int> _replies;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    final status = _replies.isEmpty
        ? 500
        : _replies.removeAt(0);

    final body = status == 200 ? 'image-bytes' : 'denied';

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
      headers: const {'content-type': 'image/jpeg'},
    );
  }
}

/// The refresh endpoint, answering whatever the test tells it to.
class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter(this.body);

  final Map<String, dynamic> body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String? _authorizationOf(http.BaseRequest request) =>
    request.headers['Authorization'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  late String mediaUrl;

  setUpAll(() {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.test.invalid');
    mediaUrl = '${ApiConfig.fullBaseUrl}${ApiConfig.files}/photo-1';
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    AccountSession().end();
    AccountSession().begin('account-a');
    AuthenticatedMedia.clear();
  });

  test('a 401 refreshes once, retries once, and succeeds on the retry',
      () async {
    final refresh = _RefreshAdapter({
      'access_token': 'fresh-token',
      'refresh_token': 'rotated-refresh',
      'expires_in': 900,
    });
    TokenRefreshService().refreshDioForTesting.httpClientAdapter = refresh;

    await storage.saveAccessToken('expired-token');
    await storage.saveRefreshToken('account-a-refresh');

    final client = _RecordingClient([401, 200]);
    final service = AuthenticatedMediaFileService(httpClient: client);

    final response = await service.get(mediaUrl);

    expect(response.statusCode, 200,
        reason: 'the retry after refresh did not reach the caller');

    // Exactly two attempts: the one that expired and the one after the refresh.
    // A third would mean a loop, which is the failure mode this has to avoid on
    // a file that is genuinely forbidden.
    expect(client.requests.length, 2,
        reason: 'the media request was not retried exactly once');
    expect(refresh.calls, 1, reason: 'the token was refreshed more than once');

    expect(_authorizationOf(client.requests[0]), 'Bearer expired-token');
    expect(_authorizationOf(client.requests[1]), 'Bearer fresh-token',
        reason: 'the retry was sent with the token that had just failed');

    // The synchronous cache the widgets read from carries the new token too, so
    // the next thumbnail does not repeat the whole dance.
    expect(AuthenticatedMedia.headersFor(mediaUrl),
        {'Authorization': 'Bearer fresh-token'});
  });

  test('a second 401 after a successful refresh is not retried again',
      () async {
    final refresh = _RefreshAdapter({
      'access_token': 'fresh-token',
      'refresh_token': 'rotated-refresh',
      'expires_in': 900,
    });
    TokenRefreshService().refreshDioForTesting.httpClientAdapter = refresh;

    await storage.saveAccessToken('expired-token');
    await storage.saveRefreshToken('account-a-refresh');

    // A revoked collaborator: the token is fine, the access is not.
    final client = _RecordingClient([401, 401]);
    final service = AuthenticatedMediaFileService(httpClient: client);

    final response = await service.get(mediaUrl);

    expect(response.statusCode, 401);
    expect(client.requests.length, 2,
        reason: 'a refused file was retried more than once');
    expect(refresh.calls, 1);
  });

  test('a 401 that outlives its account refreshes nothing and writes nothing',
      () async {
    final refresh = _RefreshAdapter({
      'access_token': 'should-never-be-stored',
      'refresh_token': 'should-never-be-stored',
      'expires_in': 900,
    });
    TokenRefreshService().refreshDioForTesting.httpClientAdapter = refresh;

    await storage.saveAccessToken('account-a-access');
    await storage.saveRefreshToken('account-a-refresh');

    // The request is in the air when the account changes. The adapter completes
    // it only after B has signed in with its own tokens.
    final switched = Completer<void>();
    final client = _SwitchingClient(switched);
    final service = AuthenticatedMediaFileService(httpClient: client);

    final fetching = service.get(mediaUrl);
    await client.firstRequest.future;

    AccountSession().end();
    AccountSession().begin('account-b');
    await storage.saveAccessToken('account-b-access');
    await storage.saveRefreshToken('account-b-refresh');
    switched.complete();

    final response = await fetching;

    expect(response.statusCode, 401,
        reason: 'the fetch should simply fail, not be rescued');

    // Nothing was refreshed: spending account B's refresh token on account A's
    // image would rotate B's credentials, and a rejected refresh would clear
    // them - signing B out because A's photo failed.
    expect(refresh.calls, 0, reason: 'a dead session triggered a refresh');
    expect(client.requests.length, 1,
        reason: 'a dead session retried the media request');

    expect(await storage.getAccessToken(), 'account-b-access');
    expect(await storage.getRefreshToken(), 'account-b-refresh');
    expect(AuthenticatedMedia.headersFor(mediaUrl),
        {'Authorization': 'Bearer account-b-access'});
  });
}

/// Answers 401 only once the test has switched accounts, so the failure lands
/// in a session that no longer exists.
class _SwitchingClient extends http.BaseClient {
  _SwitchingClient(this._switched);

  final Completer<void> _switched;
  final Completer<void> firstRequest = Completer<void>();
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    if (!firstRequest.isCompleted) {
      firstRequest.complete();
    }

    await _switched.future;

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('denied')),
      401,
    );
  }
}
