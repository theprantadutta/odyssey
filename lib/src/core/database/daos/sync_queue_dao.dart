import 'package:drift/drift.dart';

import '../app_database.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue, SyncMetadata])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  // ─── Queue Operations ────────────────────────────────────────

  Future<void> enqueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  Future<List<SyncQueueData>> getPending() {
    return (select(syncQueue)
          ..where((q) => q.status.equals('pending'))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
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

  Future<void> markInProgress(String id) {
    return (update(syncQueue)..where((q) => q.id.equals(id)))
        .write(const SyncQueueCompanion(status: Value('inProgress')));
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

  Future<void> removeForEntity(String entityType, String entityId) {
    return (delete(syncQueue)
          ..where((q) => q.entityType.equals(entityType) & q.entityId.equals(entityId)))
        .go();
  }

  Future<void> clearAll() {
    return delete(syncQueue).go();
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
