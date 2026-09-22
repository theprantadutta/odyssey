import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// The server's own revision string for this record, stored verbatim.
  ///
  /// Kept apart from [updatedAt] because they answer different questions.
  /// [updatedAt] is when this device last touched the row and is stored as a
  /// Drift DateTime - unix seconds. A server revision needs to go back to the
  /// server byte-for-byte, and PostgreSQL keeps microseconds, so round-tripping
  /// it through a DateTime silently truncates it and the server rejects the
  /// result as stale. Held as opaque text: nothing here parses or compares it.
  TextColumn get serverRevision => text().nullable()();

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

  /// Position in the queue, independent of any clock.
  ///
  /// FIFO used to be `ORDER BY createdAt`, which ties whenever two operations
  /// are made in the same second - and coalescing deliberately carries the
  /// *original* timestamp onto the merged row, so ties are normal rather than
  /// rare. A parent create and its child create in one second could come back
  /// child-first, and the child would be pushed to a server that has never
  /// heard of its parent.
  ///
  /// Assigned once, monotonically, and preserved when a row is coalesced: the
  /// merged operation keeps the place in line that the edit it replaces had.
  IntColumn get sequence => integer().withDefault(const Constant(0))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// The local row's `updatedAt` at the moment this operation was sent.
  ///
  /// An acknowledgement is only valid for the revision it was sent for. If the
  /// user edited the record again while the request was in flight, the row's
  /// current `updatedAt` no longer matches and the response must not clear the
  /// dirty flag or overwrite the newer edit.
  ///
  /// Durable rather than in-memory so an operation left in flight by a process
  /// kill can still be reasoned about on the next launch.
  DateTimeColumn get sentRevision => dateTime().nullable()();

  /// When this operation was handed to the server, for stuck-operation recovery.
  DateTimeColumn get sentAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unsynced operations set aside when their account signed out.
///
/// Clearing the database on sign-out used to delete queued work outright, so an
/// edit made offline and never pushed was gone the moment the user logged out.
/// These rows are keyed by the account that made them and restored if that same
/// account signs back in; another account never sees them.
class QuarantinedOperations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get quarantinedAt => dateTime()();

  /// Why this was set aside - see [QuarantineReason].
  ///
  /// The two cases must not be treated alike. Work set aside on sign-out is
  /// this account's own, and belongs back in the ordinary tables the moment
  /// they sign in again. Work set aside because *access was revoked* is still
  /// theirs to recover, but the trip it belongs to is not: putting it back
  /// would return content the server has said they may no longer see.
  TextColumn get reason =>
      text().withDefault(const Constant('sign_out'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Snapshots of the local rows that quarantined operations act on.
///
/// Saving the queue alone is not enough. A queued operation is usually a partial
/// patch, and the row it patches is deleted when the database is cleared on
/// sign-out - so the restored operation would describe an edit the user can no
/// longer see, and a child would come back with no parent. These snapshots put
/// the base data back before the queue is replayed.
class QuarantinedRecords extends Table {
  /// `userId:entityType:entityId`.
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// The Drift row, serialised with its own `toJson`.
  TextColumn get rowJson => text()();
  DateTimeColumn get quarantinedAt => dateTime()();

  /// Why this was set aside - see [QuarantineReason].
  TextColumn get reason =>
      text().withDefault(const Constant('sign_out'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A push the server rejected because the record had changed underneath it.
///
/// Both versions are kept: discarding either one silently loses work the user
/// did. The local row stays dirty and unchanged so nothing disappears from the
/// screen while the conflict is unresolved.
class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// The operation payload we tried to push.
  TextColumn get localPayload => text()();

  /// The record as the server holds it.
  TextColumn get serverPayload => text()();

  DateTimeColumn get detectedAt => dateTime()();

  /// The queue sequence this conflict was detected at.
  ///
  /// Resolution has to tell "the edit that was refused" from "an edit the user
  /// made afterwards", and it must not lose that distinction for two edits in
  /// the same second. [detectedAt] is a Drift DateTime - unix seconds - so
  /// comparing against it decides same-second cases by luck. The sequence is
  /// exact.
  ///
  /// Zero for a conflict recorded before this column existed; comparisons treat
  /// that as "unknown" and fall back to the timestamp.
  IntColumn get detectedSequence => integer().withDefault(const Constant(0))();

  /// Cleared once the user (or a later successful push) settles it.
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Why a piece of work is sitting in recovery storage rather than in the app.
///
/// Stored as text so the value survives a schema the enum later outgrows.
abstract final class QuarantineReason {
  /// The account signed out. Restored in full when they sign back in.
  static const signOut = 'sign_out';

  /// Access to the trip was revoked. The work is kept and never silently
  /// restored: the trip must stay out of normal browsing, so putting the rows
  /// back would undo the eviction that removed them.
  static const revoked = 'revoked';

  /// The operation is larger than one `POST /sync/push` body may carry, so the
  /// server refuses it with 413 however often it is sent.
  ///
  /// Kept and never silently restored, for the same reason [revoked] is: the
  /// user wrote it and only they can recreate it, but putting it back on the
  /// queue would re-send the identical body and stall every operation behind it
  /// all over again. The local row is untouched and still dirty - the user's
  /// data is on screen, it is the *push* that could not be made.
  static const tooLarge = 'too_large';
}

/// Unresolved conflicts belonging to an account that is not signed in.
///
/// Kept separately from [SyncConflicts] for the same reason the operations are:
/// signing out clears the ordinary tables. A conflict holds the only copy of
/// the user's rejected edit, and once its queue row is gone - an acknowledged
/// conflict removes it - nothing else in the database points at that work. It
/// was therefore the one thing the queue-driven quarantine could never find.
class QuarantinedConflicts extends Table {
  /// `userId:conflictId`.
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get conflictId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// The edit the user made, which the server refused.
  TextColumn get localPayload => text()();

  /// The record as the server holds it.
  TextColumn get serverPayload => text()();

  DateTimeColumn get detectedAt => dateTime()();

  /// See [SyncConflicts.detectedSequence].
  IntColumn get detectedSequence => integer().withDefault(const Constant(0))();

  DateTimeColumn get quarantinedAt => dateTime()();

  /// See [QuarantineReason].
  TextColumn get reason =>
      text().withDefault(const Constant('sign_out'))();

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
    SyncConflicts,
    QuarantinedOperations,
    QuarantinedRecords,
    QuarantinedConflicts,
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

  /// Builds a database over a caller-supplied executor.
  ///
  /// Tests use this with `NativeDatabase.memory()` so queue coalescing, dirty
  /// flags and ID remapping can be exercised against real SQL rather than a
  /// hand-written fake that cannot reproduce transaction behaviour.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Applied in ascending order so an upgrade from any older version walks
        // the same path a stepwise upgrade would have taken.
        //
        // Column additions go through [_addColumnIfMissing], never `addColumn`
        // directly. A table created by an earlier step in this same run is
        // created from the table's *current* Dart definition - Drift keeps no
        // history of what it looked like at that schema version - so it already
        // has every column a later step would add, and adding one again throws
        // `duplicate column name`. That is not hypothetical: a device coming
        // from schema 3 created `quarantined_operations` at step 4 complete with
        // the `reason` column that step 6 then tried to add, and the migration
        // failed on every launch from then on.
        if (from < 2) {
          // Add new tables
          await m.createTable(localTemplates);
          await m.createTable(localPublicTemplates);
          await m.createTable(localAchievements);
          await m.createTable(localUserAchievements);
          await m.createTable(localSharedTrips);
          await m.createTable(localSubscriptionCache);

          // Add missing columns to LocalTripShares
          await _addColumnIfMissing(
            m,
            localTripShares,
            localTripShares.inviteExpiresAt,
          );
          await _addColumnIfMissing(
            m,
            localTripShares,
            localTripShares.isDirty,
          );
          await _addColumnIfMissing(
            m,
            localTripShares,
            localTripShares.isLocalOnly,
          );
          await _addColumnIfMissing(
            m,
            localTripShares,
            localTripShares.isDeleted,
          );
        }
        if (from < 3) {
          // Revision tracking for acknowledgements, and durable conflict records.
          await _addColumnIfMissing(m, syncQueue, syncQueue.sentRevision);
          await _addColumnIfMissing(m, syncQueue, syncQueue.sentAt);
          await m.createTable(syncConflicts);
        }
        if (from < 4) {
          // Unsynced work is set aside per account rather than deleted on logout.
          await m.createTable(quarantinedOperations);
        }
        if (from < 5) {
          // Base rows the quarantined operations act on, so a restored partial
          // edit still has a record to apply to.
          await m.createTable(quarantinedRecords);
        }
        if (from < 6) {
          // Revoked-access recovery is separated from ordinary sign-out work,
          // and unresolved conflicts are preserved in their own right rather
          // than only through the queue row that happened to reference them.
          await _addColumnIfMissing(
            m,
            quarantinedOperations,
            quarantinedOperations.reason,
          );
          await _addColumnIfMissing(
            m,
            quarantinedRecords,
            quarantinedRecords.reason,
          );
          await m.createTable(quarantinedConflicts);
        }
        if (from < 7) {
          // Exact server revisions, and ordering that does not depend on a
          // clock with one-second resolution.
          await _addColumnIfMissing(m, localTrips, localTrips.serverRevision);
          await _addColumnIfMissing(
            m,
            localActivities,
            localActivities.serverRevision,
          );
          await _addColumnIfMissing(
            m,
            localExpenses,
            localExpenses.serverRevision,
          );
          await _addColumnIfMissing(
            m,
            localMemories,
            localMemories.serverRevision,
          );
          await _addColumnIfMissing(
            m,
            localDocuments,
            localDocuments.serverRevision,
          );
          await _addColumnIfMissing(
            m,
            localPackingItems,
            localPackingItems.serverRevision,
          );
          await _addColumnIfMissing(
            m,
            localTemplates,
            localTemplates.serverRevision,
          );

          await _addColumnIfMissing(m, syncQueue, syncQueue.sequence);
          await _addColumnIfMissing(
            m,
            syncConflicts,
            syncConflicts.detectedSequence,
          );

          // Existing rows get a sequence in their current timestamp order, so
          // an upgrade does not reorder a queue that is already waiting.
          await m.database.customStatement(
            'UPDATE sync_queue SET sequence = rowid WHERE sequence = 0',
          );
        }
      },
    );
  }

  /// Adds [column] to [table] unless the table already has it.
  ///
  /// `ALTER TABLE ... ADD COLUMN` has no `IF NOT EXISTS` in SQLite, and a
  /// duplicate is a hard error that aborts the whole migration. Drift runs the
  /// migration in a transaction, so the failure rolls back and the app retries
  /// the identical failing statement on the next launch - the database never
  /// moves, and the user is locked out permanently rather than once.
  ///
  /// Asking the table what it has makes each step idempotent: it fixes the
  /// upgrade paths where a step creates a table that a later step then tries to
  /// extend, and it lets a database left half-migrated by an earlier crash
  /// finish the job instead of failing on the part that already succeeded.
  @visibleForTesting
  static Future<void> addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) => _addColumnIfMissing(m, table, column);

  static Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await m.database
        .customSelect(
          'SELECT name FROM pragma_table_info(?)',
          variables: [Variable<String>(table.actualTableName)],
        )
        .get();
    final existing = rows.map((r) => r.read<String>('name')).toSet();
    if (existing.contains(column.name)) return;
    await m.addColumn(table, column);
  }

  /// Empties every table that belongs to the signed-in account.
  ///
  /// The three quarantine tables are deliberately preserved: they are the
  /// recovery storage, holding work belonging to an account that has signed out
  /// or lost access to a trip. Wiping them here would delete the very thing
  /// they exist to save.
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        if (_preservedOnClear.contains(table.actualTableName)) continue;
        await delete(table).go();
      }
    });
  }

  /// Recovery storage, which outlives the account whose data it holds.
  late final Set<String> _preservedOnClear = {
    quarantinedOperations.actualTableName,
    quarantinedRecords.actualTableName,
    quarantinedConflicts.actualTableName,
  };
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'odyssey.db'));
    return NativeDatabase.createInBackground(file);
  });
}
