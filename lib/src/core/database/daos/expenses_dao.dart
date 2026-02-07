import 'package:drift/drift.dart';

import '../app_database.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [LocalExpenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase> with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Stream<List<LocalExpense>> watchByTrip(String tripId) {
    return (select(localExpenses)
          ..where((e) => e.tripId.equals(tripId) & e.isDeleted.equals(false))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .watch();
  }

  Future<List<LocalExpense>> getByTrip(String tripId) {
    return (select(localExpenses)
          ..where((e) => e.tripId.equals(tripId) & e.isDeleted.equals(false))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  Future<LocalExpense?> getById(String id) {
    return (select(localExpenses)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(LocalExpensesCompanion entry) {
    return into(localExpenses).insertOnConflictUpdate(entry);
  }

  Future<void> upsertBatch(List<LocalExpensesCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localExpenses, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalExpense>> getDirty() {
    return (select(localExpenses)..where((e) => e.isDirty.equals(true))).get();
  }

  Future<void> clearDirty(String id) {
    return (update(localExpenses)..where((e) => e.id.equals(id)))
        .write(const LocalExpensesCompanion(isDirty: Value(false), isLocalOnly: Value(false)));
  }

  Future<void> softDelete(String id) {
    return (update(localExpenses)..where((e) => e.id.equals(id)))
        .write(const LocalExpensesCompanion(isDeleted: Value(true), isDirty: Value(true)));
  }

  Future<void> hardDelete(String id) {
    return (delete(localExpenses)..where((e) => e.id.equals(id))).go();
  }

  Future<void> deleteAll() {
    return delete(localExpenses).go();
  }
}
