/// Pure decision logic for merging a new sync operation into whatever is
/// already queued for the same entity.
///
/// This file has no database or plugin dependencies so every case can be unit
/// tested directly. [SyncQueueService] applies the result inside a transaction.
library;

/// Operation names as stored in the `sync_queue` table.
class SyncOp {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Queue row statuses.
class SyncStatus {
  static const String pending = 'pending';
  static const String inProgress = 'inProgress';
}

/// Payload key carrying the local row version an update was based on.
///
/// Used for conflict detection server-side, so when two updates merge the
/// *oldest* base must survive - the merged patch is still relative to the
/// version the first edit started from.
const String kBaseVersionKey = '_base_version';

/// A queued operation, reduced to just what coalescing needs to decide.
class QueuedOperation {
  const QueuedOperation({
    required this.id,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status;

  bool get isInFlight => status == SyncStatus.inProgress;
}

/// What the queue should do once a new operation arrives.
class CoalesceResult {
  const CoalesceResult({
    required this.idsToDelete,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  /// Queue rows to remove. Never includes an in-flight row.
  final List<String> idsToDelete;

  /// The operation to write, or null when the new operation annihilates the
  /// queued one and nothing should be sent (offline create then delete).
  final String? operation;

  final Map<String, dynamic>? payload;

  /// Timestamp for the row to write.
  ///
  /// When merging into an existing operation this is the *original* createdAt,
  /// never `now`. The queue drains in FIFO order, so refreshing the timestamp
  /// would reorder a parent's create behind a child's and break dependency
  /// ordering - edit a trip after adding an activity to it and the activity
  /// would be sent to a server that has never seen the trip.
  final DateTime createdAt;

  bool get writesOperation => operation != null;
}

/// Decides how [incomingOperation] merges with [existing] operations already
/// queued for the same entity.
///
/// [existing] must be every queued row for that entity, oldest first.
/// [now] is the timestamp to use when no existing operation is being merged.
///
/// Rules:
///  - create + update  -> one create carrying the updated fields. The server has
///    never seen this entity, so sending an update would fail with "not found".
///  - create + delete  -> nothing. An unsent create cancels out; there is no
///    server record to delete.
///  - update + update  -> one update with the patches merged and the *oldest*
///    base version preserved.
///  - update + delete  -> delete. The pending patch is irrelevant.
///  - delete + anything -> the later operation wins; a re-create after a delete
///    is a legitimate resurrection.
///  - anything in flight is never merged into or deleted: its outcome is still
///    unknown, so the new operation is queued separately behind it.
CoalesceResult coalesceOperation({
  required List<QueuedOperation> existing,
  required String incomingOperation,
  required Map<String, dynamic> incomingPayload,
  required DateTime now,
}) {
  // An operation already handed to the server may still succeed. Removing or
  // rewriting it would either lose the change or double-apply it, so leave it
  // alone and queue behind it.
  final mergeable =
      existing.where((op) => !op.isInFlight).toList(growable: false);

  if (mergeable.isEmpty) {
    return CoalesceResult(
      idsToDelete: const [],
      operation: incomingOperation,
      payload: incomingPayload,
      createdAt: now,
    );
  }

  final idsToDelete = mergeable.map((op) => op.id).toList(growable: false);

  // Fold the queued rows into a single effective operation. Normally there is
  // exactly one, but a queue written before coalescing existed may hold several.
  final effective = _foldExisting(mergeable);
  final effectiveOp = effective.operation;
  final effectivePayload = effective.payload;
  final originalCreatedAt = mergeable.first.createdAt;

  switch ((effectiveOp, incomingOperation)) {
    case (SyncOp.create, SyncOp.update):
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: SyncOp.create,
        // The create payload is the full entity; the update is a partial patch.
        // Applying the patch over it keeps the create complete and current.
        payload: _mergePayloads(effectivePayload, incomingPayload,
            keepOldestBaseVersion: false),
        createdAt: originalCreatedAt,
      );

    case (SyncOp.create, SyncOp.delete):
      // Never sent, so there is nothing on the server to delete.
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: null,
        payload: null,
        createdAt: originalCreatedAt,
      );

    case (SyncOp.create, SyncOp.create):
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: SyncOp.create,
        payload: incomingPayload,
        createdAt: originalCreatedAt,
      );

    case (SyncOp.update, SyncOp.update):
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: SyncOp.update,
        payload: _mergePayloads(effectivePayload, incomingPayload,
            keepOldestBaseVersion: true),
        createdAt: originalCreatedAt,
      );

    case (SyncOp.update, SyncOp.delete):
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: SyncOp.delete,
        payload: incomingPayload,
        createdAt: originalCreatedAt,
      );

    // A delete followed by a create is a resurrection; the create wins and
    // carries the full entity. Anything else after a delete also takes over.
    case (SyncOp.delete, _):
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: incomingOperation,
        payload: incomingPayload,
        createdAt: originalCreatedAt,
      );

    default:
      return CoalesceResult(
        idsToDelete: idsToDelete,
        operation: incomingOperation,
        payload: incomingPayload,
        createdAt: originalCreatedAt,
      );
  }
}

/// Reduces several queued rows for one entity to a single effective operation.
_Effective _foldExisting(List<QueuedOperation> ops) {
  var operation = ops.first.operation;
  var payload = Map<String, dynamic>.from(ops.first.payload);

  for (final next in ops.skip(1)) {
    switch ((operation, next.operation)) {
      case (SyncOp.create, SyncOp.update):
        payload = _mergePayloads(payload, next.payload,
            keepOldestBaseVersion: false);
      case (SyncOp.create, SyncOp.delete):
        operation = SyncOp.delete;
        payload = Map<String, dynamic>.from(next.payload);
      case (SyncOp.update, SyncOp.update):
        payload =
            _mergePayloads(payload, next.payload, keepOldestBaseVersion: true);
      default:
        operation = next.operation;
        payload = Map<String, dynamic>.from(next.payload);
    }
  }

  return _Effective(operation, payload);
}

class _Effective {
  const _Effective(this.operation, this.payload);
  final String operation;
  final Map<String, dynamic> payload;
}

/// Applies [newer] over [older].
///
/// When [keepOldestBaseVersion] is true the older `_base_version` survives,
/// because the combined patch is still relative to the version the first edit
/// was made against. When merging into a create there is no base version at all,
/// so the key is dropped entirely - the entity does not exist server-side yet.
Map<String, dynamic> _mergePayloads(
  Map<String, dynamic> older,
  Map<String, dynamic> newer, {
  required bool keepOldestBaseVersion,
}) {
  final merged = <String, dynamic>{...older, ...newer};

  if (!keepOldestBaseVersion) {
    merged.remove(kBaseVersionKey);
    return merged;
  }

  if (older.containsKey(kBaseVersionKey)) {
    final oldest = older[kBaseVersionKey];
    if (oldest == null) {
      merged.remove(kBaseVersionKey);
    } else {
      merged[kBaseVersionKey] = oldest;
    }
  }

  return merged;
}
