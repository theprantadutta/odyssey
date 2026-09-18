import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/database_service.dart';
import '../services/logger_service.dart';
import 'sync_operation_coalescing.dart';

class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService _instance = SyncQueueService._();
  factory SyncQueueService() => _instance;

  AppDatabase get _db => DatabaseService().database;

  /// Queues an operation, merging it with anything already pending for the same
  /// entity.
  ///
  /// Merging rather than replacing is what keeps offline work intact: a create
  /// followed by a rename has to stay a create, because the server has never
  /// seen the entity and would reject an update for an unknown ID. Two partial
  /// edits have to combine, or the first one's fields are silently dropped.
  /// See [coalesceOperation] for the full rule set.
  ///
  /// Runs in a transaction so a concurrent enqueue cannot observe the entity
  /// with no queued operation at all.
  /// Returns true when an operation was written, false when the incoming
  /// operation cancelled an unsent one and nothing needs to reach the server.
  /// A caller deleting an entity uses that to purge the local row outright
  /// rather than leaving a soft-deleted ghost that will never sync.
  Future<bool> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    return _db.transaction(() async {
      final existingRows =
          await _db.syncQueueDao.getForEntity(entityType, entityId);

      final existing = existingRows
          .map((row) => QueuedOperation(
                id: row.id,
                operation: row.operation,
                payload: _decodePayload(row.payload),
                createdAt: row.createdAt,
                status: row.status,
              ))
          .toList(growable: false);

      // The place in line this entity already holds, if any. Coalescing carries
      // the original timestamp onto the merged row so FIFO survives; the
      // sequence has to travel with it for the same reason, or a merged parent
      // create would jump to the back of the queue behind its own child.
      final inheritedSequence = existingRows.isEmpty
          ? null
          : existingRows
              .map((row) => row.sequence)
              .where((value) => value > 0)
              .fold<int?>(null, (lowest, value) =>
                  lowest == null || value < lowest ? value : lowest);

      final result = coalesceOperation(
        existing: existing,
        incomingOperation: operation,
        incomingPayload: payload,
        now: DateTime.now(),
      );

      if (result.idsToDelete.isNotEmpty) {
        await _db.syncQueueDao.removeByIds(result.idsToDelete);
      }

      if (!result.writesOperation) {
        AppLogger.info(
            'Cancelled unsent sync: $operation $entityType $entityId');
        return false;
      }

      final sequence =
          inheritedSequence ?? await _db.syncQueueDao.nextSequence();

      await _db.syncQueueDao.enqueue(
        SyncQueueCompanion(
          id: Value(const Uuid().v4()),
          entityType: Value(entityType),
          entityId: Value(entityId),
          operation: Value(result.operation!),
          payload: Value(jsonEncode(result.payload)),
          status: const Value(SyncStatus.pending),
          createdAt: Value(result.createdAt),
          sequence: Value(sequence),
          retryCount: const Value(0),
        ),
      );

      AppLogger.info(
          'Enqueued sync: ${result.operation} $entityType $entityId');
      return true;
    });
  }

  Map<String, dynamic> _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      // A row we cannot read must not block the queue; treat it as empty so the
      // incoming operation still replaces it.
      AppLogger.error('Failed to decode queued payload: $e');
      return <String, dynamic>{};
    }
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
