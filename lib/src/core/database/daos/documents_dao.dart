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
}
