import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper class for handling FileRunner URLs with authentication
class FileUrlHelper {
  FileUrlHelper._(); // Private constructor

  /// Get the FileRunner API key from environment
  static String get _apiKey => dotenv.env['FILERUNNER_API_KEY'] ?? '';

  /// Converts a FileRunner URL to an authenticated URL with API key
  ///
  /// If the URL is from filerunner.pranta.dev, appends the api_key query param.
  /// Otherwise, returns the URL unchanged.
  static String getAuthenticatedUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    if (url.contains('filerunner.pranta.dev')) {
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        return url;
      }
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}api_key=$apiKey';
    }

    return url;
  }

  /// Check if a URL is a FileRunner URL
  static bool isFileRunnerUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.contains('filerunner.pranta.dev');
  }
}
