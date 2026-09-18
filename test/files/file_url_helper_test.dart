import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/utils/authenticated_media.dart';
import 'package:odyssey/src/core/utils/file_url_helper.dart';

/// Regression tests for F01.
///
/// The app used to append a bundled storage API key to any URL whose text
/// contained the storage hostname. That check was a substring match, so a URL
/// merely mentioning the host in its path or query received the key too - and the
/// key itself shipped inside the app for anyone to extract.

void main() {
  setUpAll(() {
    // ApiConfig reads these; dotenv must be loaded before they are touched.
    dotenv.loadFromString(envString: '''
DEV_URL=http://localhost:8546
PROD_URL=https://odyssey.pranta.dev
FILE_STORAGE_BASE_URL=https://filerunner.pranta.dev
''');
  });

  group('recognising our own storage URLs', () {
    test('accepts a genuine storage URL', () {
      expect(
        FileUrlHelper.tryExtractFileId(
            'https://filerunner.pranta.dev/api/files/abc123'),
        'abc123',
      );
    });

    test('is case-insensitive about the host', () {
      expect(
        FileUrlHelper.tryExtractFileId(
            'https://FILERUNNER.PRANTA.DEV/api/files/abc123'),
        'abc123',
      );
    });

    test('ignores a query string', () {
      expect(
        FileUrlHelper.tryExtractFileId(
            'https://filerunner.pranta.dev/api/files/abc123?v=2'),
        'abc123',
      );
    });
  });

  group('hostname spoofing', () {
    // Each of these contains the storage hostname somewhere, so the old
    // substring check accepted every one of them.
    const spoofed = [
      'https://evil.example.com/filerunner.pranta.dev/api/files/abc',
      'https://evil.example.com/api/files/abc?next=filerunner.pranta.dev',
      'https://filerunner.pranta.dev.evil.example.com/api/files/abc',
      'https://filerunner.pranta.dev@evil.example.com/api/files/abc',
      'https://evil.example.com/#filerunner.pranta.dev/api/files/abc',
    ];

    for (final url in spoofed) {
      test('rejects $url', () {
        expect(FileUrlHelper.tryExtractFileId(url), isNull);
        expect(FileUrlHelper.isStorageUrl(url), isFalse);
      });
    }

    test('rejects the right host over the wrong scheme', () {
      // Plaintext against a service reached over TLS.
      expect(
        FileUrlHelper.tryExtractFileId(
            'http://filerunner.pranta.dev/api/files/abc'),
        isNull,
      );
    });

    test('rejects the right host with the wrong path shape', () {
      expect(
        FileUrlHelper.tryExtractFileId(
            'https://filerunner.pranta.dev/api/other/abc'),
        isNull,
      );
      expect(
        FileUrlHelper.tryExtractFileId('https://filerunner.pranta.dev/api/files/'),
        isNull,
      );
    });

    test('rejects nonsense', () {
      expect(FileUrlHelper.tryExtractFileId('not a url'), isNull);
      expect(FileUrlHelper.tryExtractFileId(''), isNull);
      expect(FileUrlHelper.tryExtractFileId(null), isNull);
    });
  });

  group('resolving to the authenticated endpoint', () {
    test('rewrites a storage URL to our own API', () {
      final resolved = FileUrlHelper.resolve(
          'https://filerunner.pranta.dev/api/files/abc123');

      expect(resolved, contains('/api/v1/files/abc123'));
      expect(resolved, isNot(contains('filerunner.pranta.dev')));
    });

    test('never carries a credential in the URL', () {
      final resolved = FileUrlHelper.resolve(
          'https://filerunner.pranta.dev/api/files/abc123');

      // The old behaviour put the shared key in a query parameter, where it
      // spread through URL logs and caches.
      expect(resolved, isNot(contains('api_key')));
      expect(resolved, isNot(contains('?')));
    });

    test('leaves an external URL untouched', () {
      const external = 'https://images.unsplash.com/photo-123';
      expect(FileUrlHelper.resolve(external), external);
    });

    test('maps an empty URL to an empty string', () {
      expect(FileUrlHelper.resolve(null), '');
      expect(FileUrlHelper.resolve(''), '');
    });
  });

  group('where the session token may be sent', () {
    test('no headers for an external host', () {
      // A redirect or an attacker-supplied address must never collect a bearer
      // token.
      expect(
        AuthenticatedMedia.headersFor('https://evil.example.com/api/v1/files/a'),
        isEmpty,
      );
    });

    test('no headers for a host that merely mentions ours', () {
      expect(
        AuthenticatedMedia.headersFor(
            'https://evil.example.com/?next=odyssey.pranta.dev'),
        isEmpty,
      );
    });

    test('no headers for the storage host itself', () {
      // The app no longer talks to storage directly and holds nothing for it.
      expect(
        AuthenticatedMedia.headersFor(
            'https://filerunner.pranta.dev/api/files/abc'),
        isEmpty,
      );
    });

    test('no headers when there is no session', () {
      AuthenticatedMedia.clear();
      expect(
        AuthenticatedMedia.headersFor(FileUrlHelper.resolve(
            'https://filerunner.pranta.dev/api/files/abc')),
        isEmpty,
      );
    });
  });
}
