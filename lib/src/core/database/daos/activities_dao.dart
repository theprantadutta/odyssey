import 'package:drift/drift.dart';

import '../app_database.dart';

part 'activities_dao.g.dart';

@DriftAccessor(tables: [LocalActivities])
class ActivitiesDao extends DatabaseAccessor<AppDatabase> with _$ActivitiesDaoMixin {
  ActivitiesDao(super.db);

  Stream<List<LocalActivity>> watchByTrip(String tripId) {
    return (select(localActivities)
          ..where((a) => a.tripId.equals(tripId) & a.isDeleted.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .watch();
  }

  Future<List<LocalActivity>> getByTrip(String tripId) {
    return (select(localActivities)
          ..where((a) => a.tripId.equals(tripId) & a.isDeleted.equals(false))
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
  }

  Future<LocalActivity?> getById(String id) {
    return (select(localActivities)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalActivitiesCompanion entry) {
    return into(localActivities).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalActivitiesCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localActivities, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalActivity>> getDirty() {
    return (select(localActivities)..where((a) => a.isDirty.equals(true))).get();
  }

  Future<void> clearDirty(String id) {
    return (update(localActivities)..where((a) => a.id.equals(id)))
        .write(const LocalActivitiesCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localActivities)..where((a) => a.id.equals(id)))
        .write(const LocalActivitiesCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localActivities)..where((a) => a.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localActivities).go();
  }
}
