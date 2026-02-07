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
}
