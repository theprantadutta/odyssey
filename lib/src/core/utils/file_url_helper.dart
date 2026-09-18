import '../config/api_config.dart';

/// Turns stored file URLs into URLs this app is allowed to fetch.
///
/// Files used to be fetched straight from the storage service with a shared API
/// key appended to the URL. The key shipped inside the app, so anyone who
/// extracted it held whatever authority it carried, and putting it in a query
/// string spread it through URL logs and caches besides.
///
/// Files now come from Odyssey's own API, which checks the caller's session and
/// the owning trip's permissions on every request and applies the storage
/// credential itself. Nothing secret reaches the device.
class FileUrlHelper {
  FileUrlHelper._();

  /// Rewrites a stored file URL to this app's authenticated file endpoint.
  ///
  /// Returns the URL unchanged when it is not one of ours - an externally hosted
  /// cover image is fetched directly, and carries no credentials of any kind.
  static String resolve(String? url) {
    if (url == null || url.isEmpty) return '';

    final fileId = tryExtractFileId(url);
    if (fileId == null) return url;

    return '${ApiConfig.fullBaseUrl}${ApiConfig.files}/$fileId';
  }

  /// The storage id inside a file URL, or null if this is not a storage URL.
  ///
  /// Parsed rather than substring-matched. `url.contains(host)` would accept
  /// `https://evil.example.com/?next=files.example.com`, and matching the host
  /// without the scheme would accept `http://` on a service reached over TLS.
  static String? tryExtractFileId(String? url) {
    if (url == null || url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) return null;

    if (!_isStorageHost(uri)) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    if (segments[segments.length - 2].toLowerCase() != 'files') return null;

    final fileId = segments.last;
    return fileId.isEmpty ? null : fileId;
  }

  /// The API origin private files are fetched from.
  static String get apiOrigin => ApiConfig.baseUrl;

  /// Whether a URL points at our own file storage.
  static bool isStorageUrl(String? url) => tryExtractFileId(url) != null;

  static bool _isStorageHost(Uri uri) {
    final expected = Uri.tryParse(ApiConfig.fileStorageBaseUrl);
    if (expected == null || !expected.isAbsolute) return false;

    // Scheme, host and port compared as parsed components, never as substrings.
    return uri.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
        uri.host.toLowerCase() == expected.host.toLowerCase() &&
        uri.port == expected.port;
  }
}
