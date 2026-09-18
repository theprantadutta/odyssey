/// Pure decision logic for handling one push result.
///
/// No database or network dependencies, so every case can be unit tested. The
/// sync service applies the decision transactionally.
library;

/// What the server said about one pushed operation.
class PushResultStatus {
  static const String ok = 'ok';
  static const String conflict = 'conflict';
  static const String error = 'error';
}

/// What to do with a local record once its push has been answered.
enum AckAction {
  /// Apply the server's copy and mark the record clean.
  applyServerData,

  /// The push succeeded, but the user has edited the record since it was sent.
  /// Drop the queue entry only; the newer edit keeps its dirty flag and its own
  /// queued operation, and must not be overwritten by this older response.
  keepNewerLocalEdit,

  /// The server refused the push because its copy had moved on. Keep both
  /// versions and leave the local record untouched and dirty.
  recordConflict,

  /// The operation failed and should be retried.
  retry,
}

/// The resolved outcome for one acknowledged operation.
class AckOutcome {
  const AckOutcome({
    required this.action,
    required this.removeQueueEntry,
    required this.clearDirtyFlag,
    required this.applyServerPayload,
  });

  final AckAction action;

  /// Whether the queue entry is finished with, either way.
  final bool removeQueueEntry;

  /// Whether the record may be marked clean.
  ///
  /// Only ever true when the acknowledged revision is still the current one.
  final bool clearDirtyFlag;

  /// Whether the server's copy should be written over the local row.
  final bool applyServerPayload;
}

/// Decides what an acknowledgement means for the local record.
///
/// [sentRevision] is the row's `updatedAt` captured when the operation was sent;
/// [currentRevision] is the row's `updatedAt` now. When they differ, the user
/// edited the record while the request was in flight, so this response describes
/// a version that is already superseded.
///
/// A null [sentRevision] is a queue entry written before revision tracking
/// existed, or an operation for a record that no longer exists locally. It is
/// treated as "cannot prove it is still current", which keeps the safe behaviour
/// of not clearing a dirty flag we cannot vouch for.
/// [hasNewerQueuedOperation] is the precise signal: if another operation for the
/// same record is already queued, the user has edited it since this one was sent,
/// whatever the timestamps say. Local timestamps are stored to the second, so an
/// edit made within the same second as the push is invisible to a revision
/// comparison alone.
AckOutcome resolveAcknowledgement({
  required String status,
  required DateTime? sentRevision,
  required DateTime? currentRevision,
  required bool serverDataAvailable,
  bool hasNewerQueuedOperation = false,
}) {
  final revisionIsCurrent = !hasNewerQueuedOperation &&
      sentRevision != null &&
      currentRevision != null &&
      !currentRevision.isAfter(sentRevision);

  switch (status) {
    case PushResultStatus.ok:
      if (!revisionIsCurrent) {
        // The push landed, but a newer local edit is already queued behind it.
        // Clearing the dirty flag here would strand that edit forever, and
        // writing the server's older copy would visibly undo the user's typing.
        return const AckOutcome(
          action: AckAction.keepNewerLocalEdit,
          removeQueueEntry: true,
          clearDirtyFlag: false,
          applyServerPayload: false,
        );
      }

      return AckOutcome(
        action: AckAction.applyServerData,
        removeQueueEntry: true,
        clearDirtyFlag: true,
        // Server-side normalisation and identity only reach the device here.
        applyServerPayload: serverDataAvailable,
      );

    case PushResultStatus.conflict:
      // Both versions are preserved. Overwriting the local row would discard the
      // user's work with no way back.
      return const AckOutcome(
        action: AckAction.recordConflict,
        removeQueueEntry: true,
        clearDirtyFlag: false,
        applyServerPayload: false,
      );

    default:
      return const AckOutcome(
        action: AckAction.retry,
        removeQueueEntry: false,
        clearDirtyFlag: false,
        applyServerPayload: false,
      );
  }
}

/// Whether an operation left in flight has been abandoned.
///
/// The process can be killed between sending a push and recording its result, so
/// an operation can sit in `inProgress` forever. After [staleAfter] it is put
/// back in the queue: the server may or may not have applied it, and the create
/// replay guard plus revision checks make a redelivery safe.
bool isStuckInFlight({
  required DateTime? sentAt,
  required DateTime now,
  Duration staleAfter = const Duration(minutes: 5),
}) {
  if (sentAt == null) return true;
  return now.difference(sentAt) >= staleAfter;
}
