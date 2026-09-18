import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/sync/sync_acknowledgement.dart';

/// Regression tests for F05.
///
/// Acknowledgement used to mark the operation complete, call the background
/// upsert (which returns early on dirty rows, so the server's copy never landed
/// on the very records being synchronised), and then clear the dirty flag for the
/// whole entity - including edits the user had made while the push was in flight.

final t0 = DateTime.utc(2026, 1, 1, 10, 0);
final t1 = DateTime.utc(2026, 1, 1, 10, 5);

void main() {
  group('successful push, revision unchanged', () {
    test('applies the server copy and marks the record clean', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: true,
      );

      expect(outcome.action, AckAction.applyServerData);
      expect(outcome.applyServerPayload, isTrue,
          reason: 'server normalisation must reach the synced record');
      expect(outcome.clearDirtyFlag, isTrue);
      expect(outcome.removeQueueEntry, isTrue);
    });

    test('still clears dirty when the server returned no body', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: false,
      );

      expect(outcome.applyServerPayload, isFalse);
      expect(outcome.clearDirtyFlag, isTrue);
      expect(outcome.removeQueueEntry, isTrue);
    });
  });

  group('edit made while the previous revision was in flight', () {
    test('keeps the newer local edit pending', () {
      // The user edited the record after the push was sent. Clearing the dirty
      // flag here would strand that edit; writing the server's older copy would
      // visibly undo their typing.
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: t1,
        serverDataAvailable: true,
      );

      expect(outcome.action, AckAction.keepNewerLocalEdit);
      expect(outcome.clearDirtyFlag, isFalse);
      expect(outcome.applyServerPayload, isFalse);
      expect(outcome.removeQueueEntry, isTrue,
          reason: 'the sent operation is finished; the newer edit has its own');
    });

    test('an acknowledgement arriving after a newer operation is queued is stale',
        () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: t1,
        serverDataAvailable: false,
      );

      expect(outcome.action, AckAction.keepNewerLocalEdit);
      expect(outcome.clearDirtyFlag, isFalse);
    });
  });

  group('a newer queued operation', () {
    test('supersedes the acknowledgement even when timestamps match', () {
      // Local revisions are stored to the second, so an edit made moments after
      // the push shares its timestamp. The queued operation is the exact signal.
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: true,
        hasNewerQueuedOperation: true,
      );

      expect(outcome.action, AckAction.keepNewerLocalEdit);
      expect(outcome.clearDirtyFlag, isFalse);
      expect(outcome.applyServerPayload, isFalse);
    });

    test('does not stop a conflict from being recorded', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.conflict,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: true,
        hasNewerQueuedOperation: true,
      );

      expect(outcome.action, AckAction.recordConflict);
    });
  });

  group('unprovable revisions', () {
    test('a missing sent revision never clears the dirty flag', () {
      // Queue entries written before revision tracking existed.
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: null,
        currentRevision: t0,
        serverDataAvailable: true,
      );

      expect(outcome.clearDirtyFlag, isFalse);
      expect(outcome.applyServerPayload, isFalse);
    });

    test('a record deleted locally is not resurrected by its acknowledgement', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.ok,
        sentRevision: t0,
        currentRevision: null,
        serverDataAvailable: true,
      );

      expect(outcome.applyServerPayload, isFalse);
      expect(outcome.clearDirtyFlag, isFalse);
    });
  });

  group('conflicts', () {
    test('preserve the local edit rather than accepting the server copy', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.conflict,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: true,
      );

      expect(outcome.action, AckAction.recordConflict);
      expect(outcome.applyServerPayload, isFalse,
          reason: 'overwriting would discard the user work with no way back');
      expect(outcome.clearDirtyFlag, isFalse,
          reason: 'the record still differs from the server');
      expect(outcome.removeQueueEntry, isTrue);
    });

    test('a conflict on a record edited again is still preserved', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.conflict,
        sentRevision: t0,
        currentRevision: t1,
        serverDataAvailable: true,
      );

      expect(outcome.action, AckAction.recordConflict);
      expect(outcome.clearDirtyFlag, isFalse);
    });
  });

  group('errors', () {
    test('leave the operation queued for retry', () {
      final outcome = resolveAcknowledgement(
        status: PushResultStatus.error,
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: false,
      );

      expect(outcome.action, AckAction.retry);
      expect(outcome.removeQueueEntry, isFalse);
      expect(outcome.clearDirtyFlag, isFalse);
    });

    test('an unrecognised status is treated as a failure, not a success', () {
      final outcome = resolveAcknowledgement(
        status: 'something_new',
        sentRevision: t0,
        currentRevision: t0,
        serverDataAvailable: true,
      );

      expect(outcome.action, AckAction.retry);
      expect(outcome.clearDirtyFlag, isFalse);
    });
  });

  group('in-flight recovery', () {
    test('an operation sent moments ago is left alone', () {
      expect(
        isStuckInFlight(sentAt: t0, now: t0.add(const Duration(seconds: 30))),
        isFalse,
      );
    });

    test('an operation abandoned by a process kill is recovered', () {
      // App terminated after the server committed but before the local
      // acknowledgement; the operation would otherwise sit in flight forever.
      expect(
        isStuckInFlight(sentAt: t0, now: t0.add(const Duration(minutes: 10))),
        isTrue,
      );
    });

    test('an in-flight row with no send timestamp is recovered', () {
      expect(isStuckInFlight(sentAt: null, now: t0), isTrue);
    });

    test('the staleness window is configurable', () {
      expect(
        isStuckInFlight(
          sentAt: t0,
          now: t0.add(const Duration(seconds: 90)),
          staleAfter: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });
  });
}
