import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_database.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;

  AppDatabase? _database;

  AppDatabase get database {
    if (_database == null) {
      throw StateError('DatabaseService not initialized. Call initialize() first.');
    }
    return _database!;
  }

  Future<void> initialize() async {
    _database ??= AppDatabase();
  }

  Future<void> clearAllData() async {
    await database.clearAllData();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Points the singleton at a test database.
  ///
  /// Services resolve the database through this singleton on every use, which
  /// is what lets a test drive the real `SyncService` against a temporary file
  /// instead of a fake. The test owns the database and closes it itself, so
  /// this deliberately does not.
  @visibleForTesting
  static void overrideForTesting(AppDatabase database) {
    _instance._database = database;
  }

  @visibleForTesting
  static void clearOverrideForTesting() {
    _instance._database = null;
  }
}
