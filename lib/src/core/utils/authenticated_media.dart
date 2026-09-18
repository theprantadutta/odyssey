import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'file_url_helper.dart';

/// Supplies the headers image and video widgets need to fetch private files.
///
/// Private files come from Odyssey's own API now, which authorizes each request
/// against the caller's session. Image and video widgets therefore have to send
/// the session token the way every other request does.
///
/// Headers are only ever attached to our own endpoint. An externally hosted URL
/// gets none, so a redirect or an attacker-supplied address cannot be turned into
/// a way of collecting the token.
class AuthenticatedMedia {
  AuthenticatedMedia._();

  /// Cached so image widgets, which rebuild constantly, do not hit secure
  /// storage on every frame. Refreshed whenever the token changes.
  static String? _cachedToken;

  /// Prepares the token for synchronous header lookups.
  ///
  /// Called after sign-in and on every session change; widgets build
  /// synchronously and cannot await secure storage mid-frame.
  static Future<void> refresh() async {
    try {
      _cachedToken = await StorageService().getAccessToken();
    } catch (e) {
      AppLogger.error('Could not read the access token for media requests: $e');
      _cachedToken = null;
    }
  }

  /// Forgets the cached token. Called when a session ends, so media requests
  /// cannot keep using the previous account's credentials.
  static void clear() {
    _cachedToken = null;
  }

  /// Headers for [url], or an empty map when it is not ours to authenticate.
  static Map<String, String> headersFor(String? url) {
    if (!_isOwnEndpoint(url)) return const {};

    final token = _cachedToken;
    if (token == null || token.isEmpty) return const {};

    return {'Authorization': 'Bearer $token'};
  }

  /// Whether [url] is this app's own API, and therefore may carry the session.
  ///
  /// Compared as parsed components against the configured API origin. Substring
  /// matching would let `https://evil.example.com/?x=odyssey.pranta.dev` collect
  /// a bearer token.
  static bool _isOwnEndpoint(String? url) {
    if (url == null || url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) return false;

    final api = Uri.tryParse(FileUrlHelper.apiOrigin);
    if (api == null || !api.isAbsolute) return false;

    return uri.scheme.toLowerCase() == api.scheme.toLowerCase() &&
        uri.host.toLowerCase() == api.host.toLowerCase() &&
        uri.port == api.port;
  }
}
