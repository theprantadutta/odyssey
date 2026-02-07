import 'package:drift/drift.dart';

import '../app_database.dart';

part 'trips_dao.g.dart';

@DriftAccessor(tables: [LocalTrips])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  Stream<List<LocalTrip>> watchAll() {
    return (select(localTrips)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<List<LocalTrip>> getAll() {
    return (select(localTrips)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<LocalTrip?> getById(String id) {
    return (select(localTrips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalTripsCompanion entry) {
    return into(localTrips).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalTripsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localTrips, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalTrip>> getDirty() {
    return (select(localTrips)..where((t) => t.isDirty.equals(true))).get();
  }

  Future<void> clearDirty(String id) {
    return (update(localTrips)..where((t) => t.id.equals(id)))
        .write(const LocalTripsCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localTrips)..where((t) => t.id.equals(id)))
        .write(const LocalTripsCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localTrips)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localTrips).go();
  }
}
