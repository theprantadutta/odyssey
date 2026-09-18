import 'package:drift/drift.dart';

import '../app_database.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [LocalDocuments])
class DocumentsDao extends DatabaseAccessor<AppDatabase> with _$DocumentsDaoMixin {
  DocumentsDao(super.db);

  Stream<List<LocalDocument>> watchByTrip(String tripId) {
    return (select(localDocuments)
          ..where((d) => d.tripId.equals(tripId) & d.isDeleted.equals(false))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<List<LocalDocument>> getByTrip(String tripId) {
    return (select(localDocuments)
          ..where((d) => d.tripId.equals(tripId) & d.isDeleted.equals(false))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .get();
  }

  Future<LocalDocument?> getById(String id) {
    return (select(localDocuments)..where((d) => d.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalDocumentsCompanion entry) {
    return into(localDocuments).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalDocumentsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localDocuments, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalDocument>> getDirty() {
    return (select(localDocuments)..where((d) => d.isDirty.equals(true))).get();
  }

  /// Marks a record as carrying unsent changes.
  ///
  /// For a record written from a server copy that still has newer local edits
  /// queued: the write leaves it clean, and a clean row is never pushed.
  Future<void> markDirty(String id) {
    return (update(localDocuments)..where((t) => t.id.equals(id)))
        .write(const LocalDocumentsCompanion(isDirty: Value(true)));
  }

  Future<void> clearDirty(String id) {
    return (update(localDocuments)..where((d) => d.id.equals(id)))
        .write(const LocalDocumentsCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localDocuments)..where((d) => d.id.equals(id)))
        .write(const LocalDocumentsCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localDocuments)..where((d) => d.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localDocuments).go();
  }

  /// Repoints rows from one trip ID to another.
  ///
  /// Used when a server-assigned trip ID replaces the locally generated one, so
  /// children are not orphaned when the stale parent row is removed.
  Future<void> repointTrip(String fromTripId, String toTripId) {
    return (update(localDocuments)..where((t) => t.tripId.equals(fromTripId)))
        .write(LocalDocumentsCompanion(tripId: Value(toTripId)));
  }

  /// Removes every row for a trip outright.
  ///
  /// Used when access to the trip is revoked: a soft delete would leave the
  /// content readable, which is exactly what revocation has to prevent.
  Future<void> deleteByTrip(String tripId) {
    return (delete(localDocuments)..where((t) => t.tripId.equals(tripId))).go();
  }
}
