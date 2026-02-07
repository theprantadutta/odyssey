import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../models/activity_model.dart';

/// Activity repository - local-first with background API sync
class ActivityRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all activities for a trip - reads from local DB, triggers background API refresh
  Future<ActivitiesResponse> getActivities({
    required String tripId,
  }) async {
    final localActivities = await _db.activitiesDao.getByTrip(tripId);

    if (localActivities.isNotEmpty || !ConnectivityService().isOnline) {
      final activities = localActivities.map(activityFromLocal).toList();

      if (ConnectivityService().isOnline) {
        _refreshFromApi(tripId);
      }

      return ActivitiesResponse(activities: activities, total: activities.length);
    }

    // No local data - fetch from API
    return _fetchFromApi(tripId);
  }

  /// Get activity by ID - reads from local DB first
  Future<ActivityModel> getActivityById(String id) async {
    final local = await _db.activitiesDao.getById(id);
    if (local != null && !local.isDeleted) {
      if (ConnectivityService().isOnline) {
        _refreshActivityFromApi(id);
      }
      return activityFromLocal(local);
    }

    try {
      final response = await _dioClient.get('${ApiConfig.activities}/$id');
      final activity = ActivityModel.fromJson(response.data);
      await _db.activitiesDao.upsert(activityToLocal(activity));
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
      payload: request.toJson(),
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post('${ApiConfig.activities}/', data: request.toJson());
        final serverActivity = ActivityModel.fromJson(response.data);
        await _db.activitiesDao.upsert(activityToLocal(serverActivity));
        await _db.syncQueueDao.removeForEntity('activity', id);
        return serverActivity;
      } catch (e) {
        AppLogger.warning('Failed to sync activity create, will retry: $e');
      }
    }

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
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch('${ApiConfig.activities}/$id', data: updates);
        final serverActivity = ActivityModel.fromJson(response.data);
        await _db.activitiesDao.upsert(activityToLocal(serverActivity));
        await _db.syncQueueDao.removeForEntity('activity', id);
        return serverActivity;
      } catch (e) {
        AppLogger.warning('Failed to sync activity update, will retry: $e');
      }
    }

    final updated = await _db.activitiesDao.getById(id);
    return updated != null ? activityFromLocal(updated) : throw 'Activity not found';
  }

  /// Delete activity - soft deletes locally, syncs in background
  Future<void> deleteActivity(String id) async {
    await _db.activitiesDao.softDelete(id);

    await SyncQueueService().enqueue(
      entityType: 'activity',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.activities}/$id');
        await _db.activitiesDao.hardDelete(id);
        await _db.syncQueueDao.removeForEntity('activity', id);
      } catch (e) {
        AppLogger.warning('Failed to sync activity delete, will retry: $e');
      }
    }
  }

  /// Reorder activities (for drag-and-drop) - online only with local update
  Future<void> reorderActivities({
    required String tripId,
    required List<ActivityOrder> activityOrders,
  }) async {
    // Update sort orders locally
    for (final order in activityOrders) {
      await ((_db.update(_db.localActivities))..where((t) => t.id.equals(order.id))).write(
        LocalActivitiesCompanion(
          sortOrder: Value(order.sortOrder),
          updatedAt: Value(DateTime.now().toUtc()),
          isDirty: const Value(true),
        ),
      );
    }

    if (ConnectivityService().isOnline) {
      try {
        final request = ReorderRequest(activityOrders: activityOrders);
        await _dioClient.put(
          '${ApiConfig.activities}/reorder',
          queryParameters: {'trip_id': tripId},
          data: request.toJson(),
        );
        // Clear dirty flags after successful sync
        for (final order in activityOrders) {
          await _db.activitiesDao.clearDirty(order.id);
        }
      } catch (e) {
        AppLogger.warning('Failed to sync activity reorder, will retry: $e');
      }
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<ActivitiesResponse> _fetchFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.activities,
        queryParameters: {'trip_id': tripId},
      );
      final activitiesResponse = ActivitiesResponse.fromJson(response.data);

      for (final activity in activitiesResponse.activities) {
        await _db.activitiesDao.upsert(activityToLocal(activity));
      }

      return activitiesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi(String tripId) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.activities,
        queryParameters: {'trip_id': tripId},
      );
      final activitiesResponse = ActivitiesResponse.fromJson(response.data);
      for (final activity in activitiesResponse.activities) {
        final existing = await _db.activitiesDao.getById(activity.id);
        if (existing == null || !existing.isDirty) {
          await _db.activitiesDao.upsert(activityToLocal(activity));
        }
      }
    } catch (e) {
      AppLogger.warning('Background activity refresh failed: $e');
    }
  }

  void _refreshActivityFromApi(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.activities}/$id');
      final activity = ActivityModel.fromJson(response.data);
      final existing = await _db.activitiesDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await _db.activitiesDao.upsert(activityToLocal(activity));
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
