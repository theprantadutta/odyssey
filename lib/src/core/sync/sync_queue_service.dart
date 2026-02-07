import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/database_service.dart';
import '../services/logger_service.dart';

class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService _instance = SyncQueueService._();
  factory SyncQueueService() => _instance;

  AppDatabase get _db => DatabaseService().database;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    // Remove any existing pending operations for the same entity
    // to avoid duplicate operations (e.g., create then update -> just create)
    await _db.syncQueueDao.removeForEntity(entityType, entityId);

    await _db.syncQueueDao.enqueue(
      SyncQueueCompanion(
        id: Value(const Uuid().v4()),
        entityType: Value(entityType),
        entityId: Value(entityId),
        operation: Value(operation),
        payload: Value(jsonEncode(payload)),
        status: const Value('pending'),
        createdAt: Value(DateTime.now()),
        retryCount: const Value(0),
      ),
    );

    AppLogger.info('Enqueued sync: $operation $entityType $entityId');
  }

  Future<List<SyncQueueData>> getPendingOperations() {
    return _db.syncQueueDao.getPending();
  }

  Stream<int> watchPendingCount() {
    return _db.syncQueueDao.watchPendingCount();
  }

  Future<int> getPendingCount() {
    return _db.syncQueueDao.getPendingCount();
  }

  Future<void> markCompleted(String id) {
    return _db.syncQueueDao.markCompleted(id);
  }

  Future<void> markFailed(String id, String error) {
    return _db.syncQueueDao.incrementRetryCount(id, error);
  }

  Future<void> clearAll() {
    return _db.syncQueueDao.clearAll();
  }
}
