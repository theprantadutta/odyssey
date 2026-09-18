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

  Future<List<LocalExpense>> getAll() {
    return (select(localExpenses)
          ..where((e) => e.isDeleted.equals(false)))
        .get();
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

  /// Marks a record as carrying unsent changes.
  ///
  /// For a record written from a server copy that still has newer local edits
  /// queued: the write leaves it clean, and a clean row is never pushed.
  Future<void> markDirty(String id) {
    return (update(localExpenses)..where((t) => t.id.equals(id)))
        .write(const LocalExpensesCompanion(isDirty: Value(true)));
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

  /// Repoints rows from one trip ID to another.
  ///
  /// Used when a server-assigned trip ID replaces the locally generated one, so
  /// children are not orphaned when the stale parent row is removed.
  Future<void> repointTrip(String fromTripId, String toTripId) {
    return (update(localExpenses)..where((t) => t.tripId.equals(fromTripId)))
        .write(LocalExpensesCompanion(tripId: Value(toTripId)));
  }

  /// Removes every row for a trip outright.
  ///
  /// Used when access to the trip is revoked: a soft delete would leave the
  /// content readable, which is exactly what revocation has to prevent.
  Future<void> deleteByTrip(String tripId) {
    return (delete(localExpenses)..where((t) => t.tripId.equals(tripId))).go();
  }
}
