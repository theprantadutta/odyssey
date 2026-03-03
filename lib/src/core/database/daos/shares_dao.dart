import 'package:drift/drift.dart';

import '../app_database.dart';

part 'shares_dao.g.dart';

@DriftAccessor(tables: [LocalTripShares, LocalSharedTrips])
class SharesDao extends DatabaseAccessor<AppDatabase> with _$SharesDaoMixin {
  SharesDao(super.db);

  // ─── Trip Shares (outgoing shares with sync) ────────────────────

  Future<List<LocalTripShare>> getByTrip(String tripId) {
    return (select(localTripShares)
          ..where((s) => s.tripId.equals(tripId) & s.isDeleted.equals(false)))
        .get();
  }

  Future<LocalTripShare?> getById(String id) {
    return (select(localTripShares)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalTripSharesCompanion entry) {
    return into(localTripShares).insertOnConflictUpdate(entry);
  }

  Future<List<LocalTripShare>> getDirty() {
    return (select(localTripShares)..where((s) => s.isDirty.equals(true))).get();
  }

  Future<void> clearDirty(String id) {
    return (update(localTripShares)..where((s) => s.id.equals(id)))
        .write(const LocalTripSharesCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localTripShares)..where((s) => s.id.equals(id)))
        .write(const LocalTripSharesCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localTripShares)..where((s) => s.id.equals(id))).go();
  }

  // ─── Shared Trips (incoming, read-only cache) ───────────────────

  Future<List<LocalSharedTrip>> getAllShared() {
    return (select(localSharedTrips)
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)]))
        .get();
  }

  Future<void> upsertShared(LocalSharedTripsCompanion entry) {
    return into(localSharedTrips).insertOnConflictUpdate(entry);
  }

  Future<void> upsertSharedBatch(List<LocalSharedTripsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localSharedTrips, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<void> clearSharedCache() {
    return delete(localSharedTrips).go();
  }
}
