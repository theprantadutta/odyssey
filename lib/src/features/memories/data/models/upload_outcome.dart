import '../../../../common/errors/failure_message.dart';

/// Why an upload failed, and whether trying again could possibly help.
///
/// The distinction is what stops the app burning the user's data allowance and
/// battery retrying a request that can never succeed. A quota or permission
/// refusal needs the user to do something; a storage hiccup does not.
enum UploadFailureKind {
  /// Network or storage trouble. Retrying is reasonable.
  transient,

  /// The caller may not write to this trip, or access changed mid-upload.
  forbidden,

  /// The batch breaks a rule: too many files, wrong type, a file too large.
  invalid,

  /// The trip owner's plan has no room.
  quotaExceeded,
}

/// A failed upload, described well enough for the UI to say something true.
class UploadFailure implements UserFacingException {
  @override
  String get userMessage => message;

  const UploadFailure({
    required this.kind,
    required this.message,
    this.failedFileName,
  });

  final UploadFailureKind kind;
  final String message;

  /// Which file the batch stopped on, when the server said.
  final String? failedFileName;

  /// Whether offering "try again" makes sense.
  bool get isRetryable => kind == UploadFailureKind.transient;

  /// Whether the user has to change something before it could work.
  bool get needsUserAction =>
      kind == UploadFailureKind.quotaExceeded || kind == UploadFailureKind.invalid;

  @override
  String toString() => message;

  /// Reads the server's classification.
  ///
  /// The server sends a stable `code` precisely so the client does not have to
  /// guess from an HTTP status or, worse, from the wording of a message.
  static UploadFailure fromResponse({
    int? statusCode,
    Map<String, dynamic>? body,
    String? fallbackMessage,
  }) {
    final code = body?['code'] as String?;
    final message = body?['error'] as String? ??
        fallbackMessage ??
        'The upload could not be completed.';

    final kind = switch (code) {
      'FORBIDDEN' || 'ACCESS_CHANGED' => UploadFailureKind.forbidden,
      'QUOTAEXCEEDED' => UploadFailureKind.quotaExceeded,
      'INVALID' || 'INVALID_FILE' || 'BATCH_TOO_LARGE' => UploadFailureKind.invalid,
      'STORAGE_FAILED' || 'PROCESSING_FAILED' || 'UPLOAD_FAILED' =>
        UploadFailureKind.transient,
      _ => _kindFromStatus(statusCode),
    };

    return UploadFailure(kind: kind, message: message);
  }

  /// Falls back to the status when an older server sends no code.
  static UploadFailureKind _kindFromStatus(int? statusCode) {
    return switch (statusCode) {
      401 || 403 => UploadFailureKind.forbidden,
      // 413 is the storage-full answer; 400 and 422 are batch problems.
      413 => UploadFailureKind.quotaExceeded,
      400 || 422 => UploadFailureKind.invalid,
      _ => UploadFailureKind.transient,
    };
  }
}

/// How far an upload has got, per file.
///
/// Reporting one number for the whole batch tells the user almost nothing when
/// the third of five videos is the slow one.
class UploadProgress {
  const UploadProgress({
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
    required this.sentBytes,
    required this.totalBytes,
    this.state = UploadFileState.uploading,
  });

  final String fileName;
  final int fileIndex;
  final int fileCount;
  final int sentBytes;
  final int totalBytes;
  final UploadFileState state;

  double get fraction => totalBytes == 0 ? 0 : sentBytes / totalBytes;
}

enum UploadFileState { queued, uploading, processing, done, failed }
