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
}
