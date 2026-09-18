import 'package:drift/drift.dart';

import '../app_database.dart';

part 'memories_dao.g.dart';

@DriftAccessor(tables: [LocalMemories])
class MemoriesDao extends DatabaseAccessor<AppDatabase> with _$MemoriesDaoMixin {
  MemoriesDao(super.db);

  Stream<List<LocalMemory>> watchByTrip(String tripId) {
    return (select(localMemories)
          ..where((m) => m.tripId.equals(tripId) & m.isDeleted.equals(false))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  Future<List<LocalMemory>> getAll() {
    return (select(localMemories)
          ..where((m) => m.isDeleted.equals(false)))
        .get();
  }

  Future<List<LocalMemory>> getByTrip(String tripId) {
    return (select(localMemories)
          ..where((m) => m.tripId.equals(tripId) & m.isDeleted.equals(false))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<LocalMemory?> getById(String id) {
    return (select(localMemories)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalMemoriesCompanion entry) {
    return into(localMemories).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalMemoriesCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localMemories, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalMemory>> getDirty() {
    return (select(localMemories)..where((m) => m.isDirty.equals(true))).get();
  }

  /// Marks a record as carrying unsent changes.
  ///
  /// For a record written from a server copy that still has newer local edits
  /// queued: the write leaves it clean, and a clean row is never pushed.
  Future<void> markDirty(String id) {
    return (update(localMemories)..where((t) => t.id.equals(id)))
        .write(const LocalMemoriesCompanion(isDirty: Value(true)));
  }

  Future<void> clearDirty(String id) {
    return (update(localMemories)..where((m) => m.id.equals(id)))
        .write(const LocalMemoriesCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localMemories)..where((m) => m.id.equals(id)))
        .write(const LocalMemoriesCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localMemories)..where((m) => m.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localMemories).go();
  }

  /// Repoints rows from one trip ID to another.
  ///
  /// Used when a server-assigned trip ID replaces the locally generated one, so
  /// children are not orphaned when the stale parent row is removed.
  Future<void> repointTrip(String fromTripId, String toTripId) {
    return (update(localMemories)..where((t) => t.tripId.equals(fromTripId)))
        .write(LocalMemoriesCompanion(tripId: Value(toTripId)));
  }

  /// Removes every row for a trip outright.
  ///
  /// Used when access to the trip is revoked: a soft delete would leave the
  /// content readable, which is exactly what revocation has to prevent.
  Future<void> deleteByTrip(String tripId) {
    return (delete(localMemories)..where((t) => t.tripId.equals(tripId))).go();
  }
}
