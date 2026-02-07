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
}
