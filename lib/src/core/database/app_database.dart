import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/activities_dao.dart';
import 'daos/documents_dao.dart';
import 'daos/expenses_dao.dart';
import 'daos/memories_dao.dart';
import 'daos/packing_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/trips_dao.dart';

part 'app_database.g.dart';

// ─── Table Definitions ──────────────────────────────────────────────

class LocalTrips extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  TextColumn get status => text()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  RealColumn get budget => real().nullable()();
  TextColumn get displayCurrency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalActivities extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get scheduledTime => text()();
  TextColumn get category => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get category => text()();
  TextColumn get date => text()();
  TextColumn get notes => text().nullable()();
  RealColumn get convertedAmount => real().nullable()();
  TextColumn get convertedCurrency => text().nullable()();
  RealColumn get exchangeRate => real().nullable()();
  TextColumn get convertedAt => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMemories extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get mediaItems => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get photoUrl => text().nullable()();
  TextColumn get location => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get caption => text().nullable()();
  TextColumn get takenAt => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get files => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get fileUrl => text().nullable()();
  TextColumn get fileType => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPackingItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  BoolColumn get isPacked => boolean().withDefault(const Constant(false))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalTripShares extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get ownerId => text()();
  TextColumn get sharedWithEmail => text()();
  TextColumn get sharedWithUserId => text().nullable()();
  TextColumn get permission => text()();
  TextColumn get inviteCode => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get acceptedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─── Database ──────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    LocalTrips,
    LocalActivities,
    LocalExpenses,
    LocalMemories,
    LocalDocuments,
    LocalPackingItems,
    LocalTripShares,
    SyncQueue,
    SyncMetadata,
  ],
  daos: [
    TripsDao,
    ActivitiesDao,
    ExpensesDao,
    MemoriesDao,
    DocumentsDao,
    PackingDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'odyssey.db'));
    return NativeDatabase.createInBackground(file);
  });
}
