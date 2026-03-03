import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/activities_dao.dart';
import 'daos/achievements_dao.dart';
import 'daos/documents_dao.dart';
import 'daos/expenses_dao.dart';
import 'daos/memories_dao.dart';
import 'daos/packing_dao.dart';
import 'daos/shares_dao.dart';
import 'daos/subscription_cache_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/templates_dao.dart';
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
  TextColumn get inviteExpiresAt => text().nullable()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Templates ─────────────────────────────────────────────────────

class LocalTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get structureJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Sync columns
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocalOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPublicTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get structureJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isPublic => boolean().withDefault(const Constant(true))();
  TextColumn get category => text().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Achievements ──────────────────────────────────────────────────

class LocalAchievements extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get icon => text()();
  TextColumn get category => text()();
  IntColumn get threshold => integer()();
  TextColumn get tier => text()();
  IntColumn get points => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalUserAchievements extends Table {
  TextColumn get id => text()();
  TextColumn get achievementId => text()();
  IntColumn get progress => integer()();
  TextColumn get earnedAt => text().nullable()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();
  TextColumn get achievementJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Shared Trips ──────────────────────────────────────────────────

class LocalSharedTrips extends Table {
  TextColumn get id => text()(); // tripId as PK
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  TextColumn get status => text()();
  TextColumn get ownerEmail => text()();
  TextColumn get permission => text()();
  TextColumn get sharedAt => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Subscription Cache ────────────────────────────────────────────

class LocalSubscriptionCache extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
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
    LocalTemplates,
    LocalPublicTemplates,
    LocalAchievements,
    LocalUserAchievements,
    LocalSharedTrips,
    LocalSubscriptionCache,
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
    TemplatesDao,
    AchievementsDao,
    SharesDao,
    SubscriptionCacheDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add new tables
          await m.createTable(localTemplates);
          await m.createTable(localPublicTemplates);
          await m.createTable(localAchievements);
          await m.createTable(localUserAchievements);
          await m.createTable(localSharedTrips);
          await m.createTable(localSubscriptionCache);

          // Add missing columns to LocalTripShares
          await m.addColumn(localTripShares, localTripShares.inviteExpiresAt);
          await m.addColumn(localTripShares, localTripShares.isDirty);
          await m.addColumn(localTripShares, localTripShares.isLocalOnly);
          await m.addColumn(localTripShares, localTripShares.isDeleted);
        }
      },
    );
  }

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
