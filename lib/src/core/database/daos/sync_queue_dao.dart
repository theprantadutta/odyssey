import 'package:drift/drift.dart';

import '../app_database.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue, SyncMetadata, SyncConflicts, QuarantinedOperations])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  // ─── Queue Operations ────────────────────────────────────────

  Future<void> enqueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  /// Pending operations, oldest first.
  ///
  /// Ordered by [SyncQueue.sequence], not by `createdAt`. The timestamp has
  /// one-second resolution and coalescing deliberately reuses the original
  /// value, so ties are ordinary - and a tie between a parent create and its
  /// child create can put the child first, pushing it to a server that has
  /// never heard of the parent. `createdAt` breaks remaining ties only so rows
  /// written before the sequence existed keep a defined order.
  Future<List<SyncQueueData>> getPending() {
    return (select(syncQueue)
          ..where((q) => q.status.equals('pending'))
          ..orderBy([
            (q) => OrderingTerm.asc(q.sequence),
            (q) => OrderingTerm.asc(q.createdAt),
          ]))
        .get();
  }

  /// The next position in line.
  ///
  /// Monotonic across the whole queue rather than per entity, so operations on
  /// different entities keep the order the user made them in - which is what
  /// dependency ordering between a parent and its child depends on.
  Future<int> nextSequence() async {
    final highest = syncQueue.sequence.max();
    final query = selectOnly(syncQueue)..addColumns([highest]);
    final row = await query.getSingleOrNull();
    return (row?.read(highest) ?? 0) + 1;
  }

  Stream<int> watchPendingCount() {
    final query = selectOnly(syncQueue)
      ..where(syncQueue.status.equals('pending'))
      ..addColumns([syncQueue.id.count()]);
    return query.watchSingle().map((row) => row.read(syncQueue.id.count()) ?? 0);
  }

  Future<int> getPendingCount() async {
    final query = selectOnly(syncQueue)
      ..where(syncQueue.status.equals('pending'))
      ..addColumns([syncQueue.id.count()]);
    final row = await query.getSingle();
    return row.read(syncQueue.id.count()) ?? 0;
  }

  /// Marks an operation as handed to the server, recording the local revision it
  /// was sent for so a late response can be matched against it.
  Future<void> markInProgress(
    String id, {
    DateTime? sentRevision,
    DateTime? sentAt,
  }) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('inProgress'),
        sentRevision: Value(sentRevision),
        sentAt: Value(sentAt ?? DateTime.now()),
      ),
    );
  }

  Future<List<SyncQueueData>> getInProgress() {
    return (select(syncQueue)..where((q) => q.status.equals('inProgress'))).get();
  }

  /// Returns an abandoned in-flight operation to the queue.
  Future<void> releaseInProgress(String id) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        sentRevision: Value(null),
        sentAt: Value(null),
      ),
    );
  }

  // ─── Per-account quarantine ──────────────────────────────────

  /// Every queued operation, whatever its status.
  Future<List<SyncQueueData>> getAllOperations() => select(syncQueue).get();

  /// Moves every queued operation into the quarantine for [userId].
  ///
  /// Called before the local database is cleared on sign-out, so work the user
  /// made offline and never pushed is set aside rather than deleted.
  Future<int> quarantinePendingFor(String userId) async {
    final rows = await select(syncQueue).get();
    if (rows.isEmpty) return 0;

    final now = DateTime.now();
    await batch((b) {
      b.insertAll(
        quarantinedOperations,
        rows.map((row) => QuarantinedOperationsCompanion.insert(
              id: row.id,
              userId: userId,
              entityType: row.entityType,
              entityId: row.entityId,
              operation: row.operation,
              payload: row.payload,
              createdAt: row.createdAt,
              quarantinedAt: now,
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
    return rows.length;
  }

  /// Puts an account's quarantined work back on the queue when it signs in again.
  ///
  /// Sign-out work only. Work set aside because access to its trip was revoked
  /// stays in recovery storage: the server has already refused it, so putting
  /// it back on the queue would push it again on every cycle, and the rows it
  /// patches are deliberately no longer here.
  Future<int> restoreQuarantinedFor(String userId) async {
    final rows = await (select(quarantinedOperations)
          ..where((q) =>
              q.userId.equals(userId) &
              q.reason.equals(QuarantineReason.signOut))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
    if (rows.isEmpty) return 0;

    await batch((b) {
      b.insertAll(
        syncQueue,
        rows.map((row) => SyncQueueCompanion.insert(
              id: row.id,
              entityType: row.entityType,
              entityId: row.entityId,
              operation: row.operation,
              payload: row.payload,
              createdAt: row.createdAt,
            )),
        mode: InsertMode.insertOrReplace,
      );
      b.deleteWhere(
          quarantinedOperations,
          (q) =>
              q.userId.equals(userId) &
              q.reason.equals(QuarantineReason.signOut));
    });
    return rows.length;
  }

  /// How many operations are waiting to be restored on the next sign-in.
  ///
  /// Revoked work is excluded: it is never restored, so counting it here would
  /// promise the user work would come back that deliberately will not.
  Future<int> quarantinedCountFor(String userId) async {
    final query = selectOnly(quarantinedOperations)
      ..where(quarantinedOperations.userId.equals(userId) &
          quarantinedOperations.reason.equals(QuarantineReason.signOut))
      ..addColumns([quarantinedOperations.id.count()]);
    final row = await query.getSingle();
    return row.read(quarantinedOperations.id.count()) ?? 0;
  }

  // ─── Conflicts ───────────────────────────────────────────────

  Future<void> recordConflict(SyncConflictsCompanion entry) {
    return into(syncConflicts).insertOnConflictUpdate(entry);
  }

  Future<List<SyncConflict>> getUnresolvedConflicts() {
    return (select(syncConflicts)
          ..where((c) => c.isResolved.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.detectedAt)]))
        .get();
  }

  Stream<int> watchUnresolvedConflictCount() {
    final query = selectOnly(syncConflicts)
      ..where(syncConflicts.isResolved.equals(false))
      ..addColumns([syncConflicts.id.count()]);
    return query.watchSingle().map((row) => row.read(syncConflicts.id.count()) ?? 0);
  }

  Future<void> resolveConflict(String id) {
    return (update(syncConflicts)..where((c) => c.id.equals(id)))
        .write(const SyncConflictsCompanion(isResolved: Value(true)));
  }

  /// Clears any outstanding conflict for a record, used once a later push for it
  /// succeeds and the disagreement is moot.
  Future<void> resolveConflictsFor(String entityType, String entityId) {
    return (update(syncConflicts)
          ..where((c) =>
              c.entityType.equals(entityType) &
              c.entityId.equals(entityId) &
              c.isResolved.equals(false)))
        .write(const SyncConflictsCompanion(isResolved: Value(true)));
  }

  Future<void> markCompleted(String id) {
    return (delete(syncQueue)..where((q) => q.id.equals(id))).go();
  }

  Future<void> markFailed(String id, String error) {
    return (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('pending'),
        lastError: Value(error),
        retryCount: const Value.absent(), // Will be incremented manually via incrementRetryCount
      ),
    );
  }

  Future<void> incrementRetryCount(String id, String error) async {
    final item = await (select(syncQueue)..where((q) => q.id.equals(id))).getSingleOrNull();
    if (item == null) return;
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value('pending'),
        retryCount: Value(item.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }

  /// Every queued row for one entity, oldest first, whatever its status.
  ///
  /// Coalescing needs in-flight rows too: it must see them in order to leave
  /// them alone rather than silently rewriting an operation already sent.
  Future<List<SyncQueueData>> getForEntity(String entityType, String entityId) {
    return (select(syncQueue)
          ..where((q) => q.entityType.equals(entityType) & q.entityId.equals(entityId))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
  }

  Future<List<SyncQueueData>> getByEntityType(String entityType) {
    return (select(syncQueue)..where((q) => q.entityType.equals(entityType))).get();
  }

  /// Replaces a queued payload in place, keeping the row's position in the queue.
  Future<void> replacePayload(String id, String payload) {
    return (update(syncQueue)..where((q) => q.id.equals(id)))
        .write(SyncQueueCompanion(payload: Value(payload)));
  }

  /// Drops queued operations of [entityType] whose payload names [tripId].
  ///
  /// Child operations are keyed by their own ID, so the trip they belong to is
  /// only visible inside the payload. Used when access to that trip is revoked:
  /// the operations would be refused anyway, and retrying them forever is noise.
  Future<void> removeForTripPayload(String entityType, String tripId) async {
    final rows = await getByEntityType(entityType);
    final doomed = rows
        .where((row) => row.payload.contains('"trip_id":"$tripId"'))
        .map((row) => row.id)
        .toList();
    await removeByIds(doomed);
  }

  Future<void> removeByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (delete(syncQueue)..where((q) => q.id.isIn(ids))).go();
  }

  Future<void> removeForEntity(String entityType, String entityId) {
    return (delete(syncQueue)
          ..where((q) => q.entityType.equals(entityType) & q.entityId.equals(entityId)))
        .go();
  }

  /// Rewrites the entity ID on queued rows after a server-assigned ID replaces a
  /// locally generated one, so pending operations still address the right record.
  Future<void> remapEntityId({
    required String entityType,
    required String fromEntityId,
    required String toEntityId,
  }) {
    return (update(syncQueue)
          ..where((q) =>
              q.entityType.equals(entityType) & q.entityId.equals(fromEntityId)))
        .write(SyncQueueCompanion(entityId: Value(toEntityId)));
  }

  /// Empties the live queue and conflicts.
  ///
  /// The quarantine is deliberately left alone: it holds work belonging to an
  /// account that has signed out, waiting for that account to return.
  Future<void> clearAll() async {
    await delete(syncQueue).go();
    await delete(syncConflicts).go();
  }

  // ─── Metadata Operations ─────────────────────────────────────

  Future<String?> getLastSyncAt() async {
    final row = await (select(syncMetadata)..where((m) => m.key.equals('last_sync_at')))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setLastSyncAt(String value) {
    return into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataCompanion(
        key: const Value('last_sync_at'),
        value: Value(value),
      ),
    );
  }

  Future<void> clearMetadata() {
    return delete(syncMetadata).go();
  }
}
