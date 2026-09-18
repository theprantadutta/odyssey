import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import '../services/logger_service.dart';
import '../services/token_refresh_service.dart';
import '../session/account_session.dart';
import '../utils/authenticated_media.dart';

/// The one HTTP path every private image, video frame and document takes.
///
/// Media does not go through `DioClient`, so it never met `AuthInterceptor` and
/// had no refresh of its own. A widget was handed a synchronous snapshot of the
/// bearer token when it built, and that snapshot was the whole story: with a
/// fifteen minute token lifetime, someone reading a trip out of the local
/// database for a while and then opening a photo sent an expired token and got a
/// broken image. Nothing retried, because nothing knew.
///
/// So this sits underneath the cache manager, where every media fetch already
/// passes, and gives them what API calls have always had: the current token, one
/// refresh on a 401, and one retry.
class AuthenticatedMediaFileService extends FileService {
  AuthenticatedMediaFileService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    // Captured before the request, not after. The account can change while the
    // bytes are in the air, and everything below - refreshing, and deciding
    // whether the answer still means anything - has to be judged against the
    // session that asked, not whichever one is signed in when it lands.
    final scope = AccountSession().capture();

    var response = await _send(url, headers);
    if (response.statusCode != 401) {
      return HttpGetResponse(response);
    }

    // The body of a 401 is an error page nobody reads, and the connection is
    // held until it is drained.
    await response.stream.drain<void>();

    if (!scope.isCurrent) {
      // This 401 belongs to an account that has since signed out. Refreshing
      // would spend the *current* account's refresh token on the previous
      // account's image, and a failure would clear the current account's
      // credentials. Neither is ours to do; the fetch simply fails.
      AppLogger.auth('Dropped a media 401 that outlived its session');
      return HttpGetResponse(response);
    }

    // The shared single-flight refresh, so a screenful of thumbnails all failing
    // at once produces one refresh between them rather than one each. It is
    // session-guarded itself, and will not write tokens for a dead session.
    final refreshed = await TokenRefreshService().refreshToken();

    if (!refreshed || !scope.isCurrent) {
      return HttpGetResponse(response);
    }

    // The rotated token reaches the synchronous cache the widgets read from.
    // `saveAccessToken` does this too; doing it here as well keeps this layer
    // correct on its own rather than by arrangement with the storage service.
    await AuthenticatedMedia.refresh();

    // Once. A second 401 after a successful refresh is not a stale token, it is
    // an access decision - a revoked collaborator, a deleted file - and retrying
    // it again would only produce a loop.
    return HttpGetResponse(await _send(url, headers));
  }

  /// One attempt, carrying whatever authorization the URL is entitled to now.
  ///
  /// The headers are recomputed per attempt rather than taken from the caller:
  /// the caller's copy was made when a widget built, which is the staleness this
  /// class exists to fix. [AuthenticatedMedia] decides whether the URL is ours
  /// to authenticate at all, so an external image still gets no credentials.
  Future<http.StreamedResponse> _send(
    String url,
    Map<String, String>? headers,
  ) {
    final request = http.Request('GET', Uri.parse(url));

    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.headers.addAll(AuthenticatedMedia.headersFor(url));

    return _httpClient.send(request);
  }
}

/// The cache manager every widget showing a private file must use.
///
/// Separate from `DefaultCacheManager` because the fetch layer is the point: a
/// widget left on the default manager keeps the old no-refresh behaviour, and
/// the failure looks like a broken image rather than a sign-in problem.
class AuthenticatedMediaCacheManager {
  AuthenticatedMediaCacheManager._();

  static const String cacheKey = 'odysseyAuthenticatedMedia';

  static CacheManager? _instance;

  static CacheManager get instance =>
      _instance ??= CacheManager(Config(
        cacheKey,
        fileService: AuthenticatedMediaFileService(),
      ));

  /// Empties the cache. Called on sign-out: cached photos, covers and PDFs are
  /// private content in a device-wide cache.
  ///
  /// Deliberately reaches through [instance] rather than bailing when the lazy
  /// field is still null. The cache lives on disk and outlives the process, so
  /// "nothing displayed media in *this* run" says nothing about what an earlier
  /// run left behind: a cold start, a restored session and a sign-out from the
  /// settings screen would otherwise clear nothing, and the next account could
  /// open the previous one's documents straight from disk.
  static Future<void> emptyCache() async {
    await instance.emptyCache();
  }

  /// Replaces the manager, for tests that must not touch the real cache.
  @visibleForTesting
  static set instanceForTesting(CacheManager? manager) => _instance = manager;
}
