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

  Future<List<LocalActivity>> getAll() {
    return (select(localActivities)
          ..where((a) => a.isDeleted.equals(false)))
        .get();
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

  /// Marks a record as carrying unsent changes.
  ///
  /// For a record written from a server copy that still has newer local edits
  /// queued: the write leaves it clean, and a clean row is never pushed.
  Future<void> markDirty(String id) {
    return (update(localActivities)..where((t) => t.id.equals(id)))
        .write(const LocalActivitiesCompanion(isDirty: Value(true)));
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

  /// Repoints rows from one trip ID to another.
  ///
  /// Used when a server-assigned trip ID replaces the locally generated one, so
  /// children are not orphaned when the stale parent row is removed.
  Future<void> repointTrip(String fromTripId, String toTripId) {
    return (update(localActivities)..where((t) => t.tripId.equals(fromTripId)))
        .write(LocalActivitiesCompanion(tripId: Value(toTripId)));
  }

  /// Removes every row for a trip outright.
  ///
  /// Used when access to the trip is revoked: a soft delete would leave the
  /// content readable, which is exactly what revocation has to prevent.
  Future<void> deleteByTrip(String tripId) {
    return (delete(localActivities)..where((t) => t.tripId.equals(tripId))).go();
  }
}
