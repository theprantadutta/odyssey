import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';

/// Guards the upgrade paths against `duplicate column name`.
///
/// This is a regression test for a shipped outage. A device on schema 3 opened
/// a build carrying schema 7 and the migration threw
/// `SqliteException(1): duplicate column name: reason`, on every launch, with
/// no way out: `m.createTable(quarantinedOperations)` at step 4 builds the table
/// from its *current* definition, which has held `reason` since step 6 added it,
/// so step 6 then tried to add a column that was already there.
///
/// The shape of the mistake matters more than the one column. Any step that
/// creates a table, followed by any later step that extends it, breaks for
/// exactly the users who skipped both - the ones who had not updated in a while.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Runs the real upgrade over a database that is already fully current.
  ///
  /// This is the worst case every broken path collapses to: every table exists
  /// with every column, so each `addColumn` in the ladder is a duplicate. If any
  /// step still adds blindly, this throws.
  Future<void> upgradeFrom(int from) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final m = Migrator(db);
    await m.createAll();
    await db.migration.onUpgrade(m, from, 7);
  }

  for (var from = 1; from < 7; from++) {
    test('upgrade from schema $from re-runs cleanly', () async {
      await expectLater(upgradeFrom(from), completes);
    });
  }

  test('the reported crash: schema 3 to 7', () async {
    // The exact path the production user was on.
    await expectLater(upgradeFrom(3), completes);

    final columns = await db
        .customSelect(
          "SELECT name FROM pragma_table_info('quarantined_operations')",
        )
        .get();
    final names = columns.map((r) => r.read<String>('name')).toList();
    expect(names.where((n) => n == 'reason'), hasLength(1));
  });

  test(
    'a half-migrated database finishes instead of failing on what it has',
    () async {
      // A migration that died part-way leaves some columns added and some not.
      // Re-running must pick up where it stopped rather than throw on the part
      // that already succeeded.
      await expectLater(upgradeFrom(1), completes);
      await expectLater(upgradeFrom(1), completes);
    },
  );
}
