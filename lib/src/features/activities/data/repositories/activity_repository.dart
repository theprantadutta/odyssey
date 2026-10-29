import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_availability.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../../../../core/sync/local_record_reconciler.dart';
import '../models/activity_model.dart';
import '../../../../core/session/account_session.dart';
import '../../../../core/sync/base_version.dart';
import '../../../../core/sync/sync_service.dart';

/// Activity repository - local-first with background API sync
class ActivityRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all activities for a trip - reads from local DB, triggers background API refresh
  Future<ActivitiesResponse> getActivities({
    required String tripId,
  }) async {
    final localActivities = await _db.activitiesDao.getByTrip(tripId);

    if (localActivities.isNotEmpty || !ApiAvailability.canReachApi) {
      final activities = localActivities.map(activityFromLocal).toList();

      if (ApiAvailability.canReachApi) {
        _refreshFromApi(tripId);
      }

      return ActivitiesResponse(activities: activities, total: activities.length);
    }

    // No local data - fetch from API
    return _fetchFromApi(tripId);
  }

  /// Get activity by ID - reads from local DB first
  Future<ActivityModel> getActivityById(String id) async {
    final scope = AccountSession().capture();
    final local = await _db.activitiesDao.getById(id);
    if (local != null && !local.isDeleted) {
      if (ApiAvailability.canReachApi) {
        _refreshActivityFromApi(id);
      }
      return activityFromLocal(local);
    }

    try {
      final response = await _dioClient.get('${ApiConfig.activities}/$id');
      final activity = ActivityModel.fromJson(response.data);
      await scope.write(() => _db.activitiesDao.upsert(activityToLocal(activity)));
      return activity;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create new activity - writes to local DB immediately, syncs in background
  Future<ActivityModel> createActivity(ActivityRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final activity = ActivityModel(
      id: id,
      tripId: request.tripId,
      title: request.title,
      description: request.description,
      scheduledTime: request.scheduledTime,
      category: request.category,
      latitude: request.latitude,
      longitude: request.longitude,
      sortOrder: 0,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    await _db.activitiesDao.upsert(activityToLocal(activity, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'activity',
      entityId: id,
      operation: 'create',
      payload: withClientId(id, request.toJson()),
    );

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());

    return activity;
  }

  /// Update activity - writes to local DB immediately, syncs in background
  Future<ActivityModel> updateActivity(String id, Map<String, dynamic> updates) async {
    final existing = await _db.activitiesDao.getById(id);
    if (existing != null) {
      final updatedCompanion = LocalActivitiesCompanion(
        id: Value(id),
        title: updates.containsKey('title') ? Value(updates['title'] as String) : const Value.absent(),
        description: updates.containsKey('description') ? Value(updates['description'] as String?) : const Value.absent(),
        scheduledTime: updates.containsKey('scheduled_time') ? Value(updates['scheduled_time'] as String) : const Value.absent(),
        category: updates.containsKey('category') ? Value(updates['category'] as String) : const Value.absent(),
        sortOrder: updates.containsKey('sort_order') ? Value(updates['sort_order'] as int) : const Value.absent(),
        latitude: updates.containsKey('latitude') ? Value((updates['latitude'] as num?)?.toDouble()) : const Value.absent(),
        longitude: updates.containsKey('longitude') ? Value((updates['longitude'] as num?)?.toDouble()) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localActivities))..where((t) => t.id.equals(id))).write(updatedCompanion);
    }

    await SyncQueueService().enqueue(
      entityType: 'activity',
      entityId: id,
      operation: 'update',
      payload: {...updates, '_base_version': baseVersionOf(existing)},
    );

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());

    final updated = await _db.activitiesDao.getById(id);
    return updated != null ? activityFromLocal(updated) : throw 'Activity not found';
  }

  /// Delete activity - soft deletes locally, syncs in background
  Future<void> deleteActivity(String id) async {
    await _db.activitiesDao.softDelete(id);

    final queued = await SyncQueueService().enqueue(
      entityType: 'activity',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    // The delete cancelled a create that never reached the server, so there is
    // nothing to sync and nothing to keep: drop the row instead of leaving a
    // soft-deleted ghost that is hidden from the user and never syncs away.
    if (!queued) {
      await LocalRecordReconciler(_db)
          .purgeLocalOnly(entityType: 'activity', id: id);
      return;
    }

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());
  }

  /// Reorder activities (for drag-and-drop) - writes locally, syncs in
  /// background. Each activity whose position changed is queued as an
  /// ordinary update of its `sort_order`.
  Future<void> reorderActivities({
    required String tripId,
    required List<ActivityOrder> activityOrders,
  }) async {
    await _db.transaction(() async {
      for (final order in activityOrders) {
        final existing = await _db.activitiesDao.getById(order.id);
        if (existing == null || existing.sortOrder == order.sortOrder) continue;

        await ((_db.update(_db.localActivities))
              ..where((t) => t.id.equals(order.id)))
            .write(
          LocalActivitiesCompanion(
            sortOrder: Value(order.sortOrder),
            updatedAt: Value(DateTime.now().toUtc()),
            isDirty: const Value(true),
          ),
        );
        await SyncQueueService().enqueue(
          entityType: 'activity',
          entityId: order.id,
          operation: 'update',
          payload: {
            'sort_order': order.sortOrder,
            '_base_version': baseVersionOf(existing),
          },
        );
      }
    });

    // One write path, as for a single edit: the sync service makes the
    // request. These used to call the bulk endpoint directly and queue
    // nothing, so a change made offline - or one whose request failed - was
    // never sent, and the dirty rows it left behind were skipped by every pull
    // after. The phone and the server disagreed for good.
    unawaited(SyncService().performSync());
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<ActivitiesResponse> _fetchFromApi(String tripId) async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get(
        ApiConfig.activities,
        queryParameters: {'trip_id': tripId},
      );
      final activitiesResponse = ActivitiesResponse.fromJson(response.data);

      for (final activity in activitiesResponse.activities) {
        await scope.write(() => _db.activitiesDao.upsert(activityToLocal(activity)));
      }

      return activitiesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi(String tripId) async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get(
        ApiConfig.activities,
        queryParameters: {'trip_id': tripId},
      );
      final activitiesResponse = ActivitiesResponse.fromJson(response.data);
      for (final activity in activitiesResponse.activities) {
        final existing = await _db.activitiesDao.getById(activity.id);
        if (existing == null || !existing.isDirty) {
          await scope.write(() => _db.activitiesDao.upsert(activityToLocal(activity)));
        }
      }
    } catch (e) {
      AppLogger.warning('Background activity refresh failed: $e');
    }
  }

  void _refreshActivityFromApi(String id) async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get('${ApiConfig.activities}/$id');
      final activity = ActivityModel.fromJson(response.data);
      final existing = await _db.activitiesDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await scope.write(() => _db.activitiesDao.upsert(activityToLocal(activity)));
      }
    } catch (e) {
      AppLogger.warning('Background activity detail refresh failed: $e');
    }
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
