import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/common/errors/failure_message.dart';

/// The rule this file exists to hold: nothing a user sees is quoted from a
/// thrown object.
///
/// A real user was shown
/// `SqliteException(1): while executing, duplicate column name: reason, SQL
/// logic error (code 1)` - the storage engine, the schema, a column name, and
/// the fact that a migration was running. The tests below are written against
/// the actual strings this app is capable of throwing, not invented ones.
void main() {
  /// Text that must never reach a screen, taken from things this app throws.
  const leaks = <String>[
    'SqliteException(1): while executing, duplicate column name: reason, '
        'SQL logic error (code 1)',
    "LateInitializationError: Field '_repository' has already been initialized.",
    'FileSystemException: Cannot open file, path = '
        "'/data/user/0/dev.pranta.odyssey/app_flutter/odyssey.db' "
        '(OS Error: No such file or directory, errno = 2)',
    'DioException [bad response]: https://odyssey.pranta.dev/api/v1/trips',
    "PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10, null, null)",
    'type Null is not a subtype of type String in type cast',
    'Bad state: No element',
  ];

  group('nothing is quoted back to the user', () {
    for (final leak in leaks) {
      test('"${leak.substring(0, leak.length.clamp(0, 44))}..."', () {
        final shown = FailureMessage.of(leak, fallback: 'That did not load.');
        expect(shown, 'That did not load.');
        // Not just unequal - none of it survives in any form.
        for (final word in const [
          'Sqlite',
          'Exception',
          'errno',
          'odyssey.db',
          'pranta.dev',
          'PlatformException',
          '_repository',
          'subtype',
        ]) {
          expect(
            shown.toLowerCase(),
            isNot(contains(word.toLowerCase())),
            reason: 'the fallback leaked "$word" from the original',
          );
        }
      });
    }

    test('an object, not just its string form', () {
      final shown = FailureMessage.of(
        StateError('database is locked at /data/odyssey.db'),
        fallback: 'That did not load.',
      );
      expect(shown, 'That did not load.');
    });
  });

  group('failures a user can act on are explained', () {
    test('offline', () {
      expect(
        FailureMessage.of(const SocketException('Failed host lookup')),
        contains('offline'),
      );
    });

    test('timed out', () {
      expect(FailureMessage.of(TimeoutException('x')), contains('too long'));
    });

    test('a dropped connection, through Dio', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/trips'),
        type: DioExceptionType.connectionError,
      );
      expect(FailureMessage.of(e), contains('offline'));
    });

    test('an expired session', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/trips'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/trips'),
          statusCode: 401,
        ),
      );
      expect(FailureMessage.of(e), contains('Sign in again'));
    });

    test('a server fault says our side, not which server', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/trips'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/trips'),
          statusCode: 500,
          data: {'stackTrace': 'at Odyssey.Api.TripsController.Get() line 88'},
        ),
      );
      final shown = FailureMessage.of(e);
      expect(shown, contains('our side'));
      expect(shown, isNot(contains('TripsController')));
    });
  });

  test("our own exceptions keep the words we wrote for them", () {
    expect(
      FailureMessage.of(const _Ours('Invitations need a connection.')),
      'Invitations need a connection.',
    );
  });

  test('a null failure still says something', () {
    expect(FailureMessage.of(null, fallback: 'Nope.'), 'Nope.');
  });

  group('detail', () {
    test('is available in a debug build, where these tests run', () {
      expect(FailureMessage.detailFor(StateError('boom')), contains('boom'));
    });

    test('is never invented for a null failure', () {
      expect(FailureMessage.detailFor(null), isNull);
    });
  });
}

class _Ours implements UserFacingException {
  const _Ours(this.userMessage);
  @override
  final String userMessage;
}
