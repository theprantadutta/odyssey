import 'dart:convert';

import '../database/app_database.dart';
import '../services/logger_service.dart';

/// Entity types whose queued payloads carry a `trip_id` that must follow a trip
/// through an ID change.
const List<String> _tripScopedEntityTypes = [
  'activity',
  'expense',
  'packing_item',
  'document',
  'memory',
];

/// Adds the locally generated ID to a create payload.
///
/// Creates send the ID the local row was written under so the server adopts it.
/// One ID end to end means the local row is confirmed in place rather than
/// duplicated, and a retry after a lost response resolves to the same record
/// instead of creating a second one.
Map<String, dynamic> withClientId(String id, Map<String, dynamic> payload) {
  return {'id': id, ...payload};
}

/// Reconciles the locally created row with what the server actually stored.
///
/// With [withClientId] in place the server normally adopts the local ID and
/// there is nothing to do. A server that assigns its own ID anyway - an older
/// deployment, or an ID already taken - used to leave the local row stranded
/// beside the server's copy, so one trip appeared twice and counts, budgets and
/// navigation went wrong (F03). [reconcileCreatedId] repairs that case.
class LocalRecordReconciler {
  const LocalRecordReconciler(this._db);

  final AppDatabase _db;

  /// Resolves a local ID against the ID the server returned.
  ///
  /// Does nothing when they match, which is the normal path.
  Future<void> reconcileCreatedId({
    required String entityType,
    required String localId,
    required String serverId,
  }) async {
    if (localId == serverId || serverId.isEmpty) return;

    AppLogger.warning(
        'Server assigned a different $entityType ID ($localId -> $serverId); '
        'reconciling local records');

    await _db.transaction(() async {
      // Children reference the parent by ID, so they must move before the stale
      // parent row is removed or they are orphaned.
      if (entityType == 'trip') {
        await _repointTripChildren(fromTripId: localId, toTripId: serverId);
        await _rewriteQueuedTripIds(fromTripId: localId, toTripId: serverId);
      }

      // Queued operations still address the old ID and would be sent for a
      // record the server has never heard of.
      await _db.syncQueueDao.remapEntityId(
        entityType: entityType,
        fromEntityId: localId,
        toEntityId: serverId,
      );

      await _hardDeleteLocal(entityType, localId);
    });
  }

  Future<void> _repointTripChildren({
    required String fromTripId,
    required String toTripId,
  }) async {
    await _db.activitiesDao.repointTrip(fromTripId, toTripId);
    await _db.expensesDao.repointTrip(fromTripId, toTripId);
    await _db.packingDao.repointTrip(fromTripId, toTripId);
    await _db.documentsDao.repointTrip(fromTripId, toTripId);
    await _db.memoriesDao.repointTrip(fromTripId, toTripId);
  }

  /// Rewrites `trip_id` inside queued child payloads.
  ///
  /// A queued activity is keyed by its own ID, so remapping entity IDs does not
  /// reach the parent reference buried in its payload. Left alone, the activity
  /// would be created against a trip ID the server never issued.
  Future<void> _rewriteQueuedTripIds({
    required String fromTripId,
    required String toTripId,
  }) async {
    for (final entityType in _tripScopedEntityTypes) {
      final rows = await _db.syncQueueDao.getByEntityType(entityType);

      for (final row in rows) {
        final Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(row.payload);
          if (decoded is! Map) continue;
          payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          continue;
        }

        if (payload['trip_id'] != fromTripId) continue;

        payload['trip_id'] = toTripId;
        await _db.syncQueueDao.replacePayload(row.id, jsonEncode(payload));
      }
    }
  }

  /// Removes a local row outright.
  ///
  /// Used when a delete cancelled a create that was never sent: the record never
  /// existed on the server, so soft-deleting it would leave a row that is hidden
  /// from the user and will never sync away.
  Future<void> purgeLocalOnly({
    required String entityType,
    required String id,
  }) {
    return _hardDeleteLocal(entityType, id);
  }

  Future<void> _hardDeleteLocal(String entityType, String id) async {
    switch (entityType) {
      case 'trip':
        await _db.tripsDao.hardDelete(id);
      case 'activity':
        await _db.activitiesDao.hardDelete(id);
      case 'expense':
        await _db.expensesDao.hardDelete(id);
      case 'packing_item':
        await _db.packingDao.hardDelete(id);
      case 'template':
        await _db.templatesDao.hardDelete(id);
      default:
        AppLogger.warning(
            'No local cleanup registered for entity type $entityType');
    }
  }
}
