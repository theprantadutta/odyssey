import 'package:drift/drift.dart';

import '../app_database.dart';

part 'templates_dao.g.dart';

@DriftAccessor(tables: [LocalTemplates, LocalPublicTemplates])
class TemplatesDao extends DatabaseAccessor<AppDatabase> with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  // ─── Local Templates (user's own — full CRUD with sync) ─────────

  Stream<List<LocalTemplate>> watchAll() {
    return (select(localTemplates)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<List<LocalTemplate>> getAll() {
    return (select(localTemplates)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  Future<LocalTemplate?> getById(String id) {
    return (select(localTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalTemplatesCompanion entry) {
    return into(localTemplates).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalTemplatesCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localTemplates, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalTemplate>> getDirty() {
    return (select(localTemplates)..where((t) => t.isDirty.equals(true))).get();
  }

  Future<void> clearDirty(String id) {
    return (update(localTemplates)..where((t) => t.id.equals(id)))
        .write(const LocalTemplatesCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localTemplates)..where((t) => t.id.equals(id)))
        .write(const LocalTemplatesCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localTemplates)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localTemplates).go();
  }

  // ─── Public Templates (read-only cache) ─────────────────────────

  Future<List<LocalPublicTemplate>> getAllPublic() {
    return (select(localPublicTemplates)
          ..orderBy([(t) => OrderingTerm.desc(t.useCount)]))
        .get();
  }

  Future<LocalPublicTemplate?> getPublicById(String id) {
    return (select(localPublicTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertPublic(LocalPublicTemplatesCompanion entry) {
    return into(localPublicTemplates).insertOnConflictUpdate(entry);
  }

  Future<void> upsertPublicBatch(List<LocalPublicTemplatesCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localPublicTemplates, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<void> clearPublicCache() {
    return delete(localPublicTemplates).go();
  }
}
