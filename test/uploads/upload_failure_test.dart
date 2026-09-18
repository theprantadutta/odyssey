import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/memories/data/models/upload_outcome.dart';

/// Telling a retryable failure from one that will never succeed.
///
/// Without the distinction the app either retries a quota refusal forever -
/// spending the user's data and battery on a request that cannot work - or gives
/// up on a network hiccup that one more attempt would have cleared.

void main() {
  group('classifying the server response', () {
    test('a permission refusal is not retryable', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 403,
        body: {'code': 'FORBIDDEN', 'error': 'No permission'},
      );

      expect(failure.kind, UploadFailureKind.forbidden);
      expect(failure.isRetryable, isFalse);
    });

    test('access changing mid-upload is not retryable', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 403,
        body: {'code': 'ACCESS_CHANGED', 'error': 'Access changed'},
      );

      expect(failure.kind, UploadFailureKind.forbidden);
      expect(failure.isRetryable, isFalse);
    });

    test('a full plan needs the user to act, not a retry', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 413,
        body: {'code': 'QUOTAEXCEEDED', 'error': 'No room'},
      );

      expect(failure.kind, UploadFailureKind.quotaExceeded);
      expect(failure.isRetryable, isFalse);
      expect(failure.needsUserAction, isTrue);
    });

    test('an invalid batch needs the user to act', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 400,
        body: {'code': 'BATCH_TOO_LARGE', 'error': 'Too many files'},
      );

      expect(failure.kind, UploadFailureKind.invalid);
      expect(failure.isRetryable, isFalse);
      expect(failure.needsUserAction, isTrue);
    });

    test('a storage failure is retryable', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 502,
        body: {'code': 'STORAGE_FAILED', 'error': 'Storage unavailable'},
      );

      expect(failure.kind, UploadFailureKind.transient);
      expect(failure.isRetryable, isTrue);
    });

    test('a processing failure is retryable', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 500,
        body: {'code': 'PROCESSING_FAILED', 'error': 'Could not process'},
      );

      expect(failure.isRetryable, isTrue);
    });

    test('the server message is shown rather than a generic one', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 413,
        body: {'code': 'QUOTAEXCEEDED', 'error': "This trip's plan has no room."},
      );

      expect(failure.message, "This trip's plan has no room.");
    });
  });

  group('falling back when there is no code', () {
    // An older server, or a proxy that swallowed the body.
    test('403 is read as a permission problem', () {
      final failure = UploadFailure.fromResponse(statusCode: 403);
      expect(failure.kind, UploadFailureKind.forbidden);
    });

    test('413 is read as out of space', () {
      final failure = UploadFailure.fromResponse(statusCode: 413);
      expect(failure.kind, UploadFailureKind.quotaExceeded);
    });

    test('400 is read as an invalid batch', () {
      final failure = UploadFailure.fromResponse(statusCode: 400);
      expect(failure.kind, UploadFailureKind.invalid);
    });

    test('an unknown status defaults to retryable', () {
      // Better to offer a retry that fails than to refuse one that would work.
      final failure = UploadFailure.fromResponse(statusCode: 503);
      expect(failure.kind, UploadFailureKind.transient);
      expect(failure.isRetryable, isTrue);
    });

    test('no response at all defaults to retryable', () {
      final failure = UploadFailure.fromResponse();
      expect(failure.isRetryable, isTrue);
      expect(failure.message, isNotEmpty);
    });

    test('an unrecognised code falls back to the status', () {
      final failure = UploadFailure.fromResponse(
        statusCode: 403,
        body: {'code': 'SOMETHING_NEW', 'error': 'Refused'},
      );

      expect(failure.kind, UploadFailureKind.forbidden);
    });
  });

  group('progress reporting', () {
    test('describes one file within the batch', () {
      const progress = UploadProgress(
        fileName: 'beach.jpg',
        fileIndex: 2,
        fileCount: 5,
        sentBytes: 512,
        totalBytes: 1024,
      );

      expect(progress.fraction, 0.5);
      expect(progress.fileIndex, 2);
      expect(progress.fileCount, 5);
    });

    test('an empty file does not divide by zero', () {
      const progress = UploadProgress(
        fileName: 'empty.jpg',
        fileIndex: 0,
        fileCount: 1,
        sentBytes: 0,
        totalBytes: 0,
      );

      expect(progress.fraction, 0);
    });
  });
}
