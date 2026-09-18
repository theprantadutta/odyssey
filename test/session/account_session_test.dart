import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/session/account_session.dart';

/// Regression tests for F07: work started under one account could land after
/// another had signed in, writing the previous user's data into the new user's
/// database.

void main() {
  late AccountSession session;

  setUp(() {
    session = AccountSession();
    session.end();
  });

  group('session boundaries', () {
    test('signing in opens a session', () {
      final generation = session.begin('user-a');

      expect(session.isSignedIn, isTrue);
      expect(session.userId, 'user-a');
      expect(session.isCurrent(generation), isTrue);
    });

    test('signing out invalidates the previous generation', () {
      final generation = session.begin('user-a');

      session.end();

      expect(session.isSignedIn, isFalse);
      expect(session.isCurrent(generation), isFalse);
    });

    test('switching account invalidates the previous generation', () {
      final first = session.begin('user-a');
      final second = session.begin('user-b');

      expect(session.isCurrent(first), isFalse);
      expect(session.isCurrent(second), isTrue);
      expect(session.userId, 'user-b');
    });

    test('re-opening for the same account is the same session', () {
      final first = session.begin('user-a');
      final again = session.begin('user-a');

      expect(again, first);
      expect(session.isCurrent(first), isTrue);
    });

    test('signing out and back in as the same account is a new session', () {
      // The database was cleared in between, so anything still in flight from
      // before must not be allowed to write.
      final first = session.begin('user-a');
      session.end();
      final second = session.begin('user-a');

      expect(session.isCurrent(first), isFalse);
      expect(session.isCurrent(second), isTrue);
    });

    test('ending an already-ended session does not churn the generation', () {
      session.begin('user-a');
      session.end();
      final afterFirstEnd = session.generation;

      session.end();

      expect(session.generation, afterFirstEnd);
    });
  });

  group('isCurrentFor', () {
    test('accepts the live session for the right account', () {
      final generation = session.begin('user-a');

      expect(session.isCurrentFor(generation, 'user-a'), isTrue);
    });

    test('rejects the right generation for the wrong account', () {
      final generation = session.begin('user-a');

      expect(session.isCurrentFor(generation, 'user-b'), isFalse);
    });
  });

  group('guard', () {
    test('runs work belonging to the live session', () async {
      final generation = session.begin('user-a');
      var ran = false;

      await session.guard(generation, () async => ran = true);

      expect(ran, isTrue);
    });

    test('drops a late response from a signed-out session', () async {
      final generation = session.begin('user-a');
      var ran = false;

      session.end();
      await session.guard(generation, () async => ran = true);

      expect(ran, isFalse);
    });

    test('drops a late response from the previous account', () async {
      // Account A's request lands after account B has signed in; writing it
      // would put A's data in B's database.
      final generationA = session.begin('user-a');
      session.begin('user-b');
      var ran = false;

      await session.guard(generationA, () async => ran = true);

      expect(ran, isFalse);
    });
  });
}
