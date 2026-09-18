import 'package:drift/drift.dart';

import '../app_database.dart';

part 'packing_dao.g.dart';

@DriftAccessor(tables: [LocalPackingItems])
class PackingDao extends DatabaseAccessor<AppDatabase> with _$PackingDaoMixin {
  PackingDao(super.db);

  Stream<List<LocalPackingItem>> watchByTrip(String tripId) {
    return (select(localPackingItems)
          ..where((p) => p.tripId.equals(tripId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  Future<List<LocalPackingItem>> getByTrip(String tripId) {
    return (select(localPackingItems)
          ..where((p) => p.tripId.equals(tripId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  Future<LocalPackingItem?> getById(String id) {
    return (select(localPackingItems)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalPackingItemsCompanion entry) {
    return into(localPackingItems).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalPackingItemsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localPackingItems, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalPackingItem>> getDirty() {
    return (select(localPackingItems)..where((p) => p.isDirty.equals(true))).get();
  }

  /// Marks a record as carrying unsent changes.
  ///
  /// For a record written from a server copy that still has newer local edits
  /// queued: the write leaves it clean, and a clean row is never pushed.
  Future<void> markDirty(String id) {
    return (update(localPackingItems)..where((t) => t.id.equals(id)))
        .write(const LocalPackingItemsCompanion(isDirty: Value(true)));
  }

  Future<void> clearDirty(String id) {
    return (update(localPackingItems)..where((p) => p.id.equals(id)))
        .write(const LocalPackingItemsCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localPackingItems)..where((p) => p.id.equals(id)))
        .write(const LocalPackingItemsCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localPackingItems)..where((p) => p.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localPackingItems).go();
  }

  /// Repoints rows from one trip ID to another.
  ///
  /// Used when a server-assigned trip ID replaces the locally generated one, so
  /// children are not orphaned when the stale parent row is removed.
  Future<void> repointTrip(String fromTripId, String toTripId) {
    return (update(localPackingItems)..where((t) => t.tripId.equals(fromTripId)))
        .write(LocalPackingItemsCompanion(tripId: Value(toTripId)));
  }

  /// Removes every row for a trip outright.
  ///
  /// Used when access to the trip is revoked: a soft delete would leave the
  /// content readable, which is exactly what revocation has to prevent.
  Future<void> deleteByTrip(String tripId) {
    return (delete(localPackingItems)..where((t) => t.tripId.equals(tripId))).go();
  }
}
