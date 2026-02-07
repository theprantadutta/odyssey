import 'dart:convert';

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
import '../models/trip_model.dart';
import '../models/trip_filter_model.dart';

/// Trip repository - local-first with background API sync
class TripRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get all trips - reads from local DB, triggers background API refresh
  Future<TripsResponse> getTrips({
    int page = 1,
    int pageSize = 20,
    TripFilterModel? filters,
  }) async {
    // Read from local DB first
    final localTrips = await _db.tripsDao.getAll();

    if (localTrips.isNotEmpty || !ConnectivityService().isOnline) {
      var trips = localTrips.map(tripFromLocal).toList();

      // Apply local filtering
      if (filters != null && filters.hasActiveFilters) {
        trips = _applyFilters(trips, filters);
      }

      // Apply local sorting
      if (filters != null && filters.hasCustomSorting) {
        trips = _applySorting(trips, filters);
      }

      // Apply pagination
      final total = trips.length;
      final start = (page - 1) * pageSize;
      final end = (start + pageSize).clamp(0, total);
      final paged = start < total ? trips.sublist(start, end) : <TripModel>[];

      // Trigger background refresh if online
      if (ConnectivityService().isOnline) {
        _refreshFromApi(filters: filters);
      }

      return TripsResponse(trips: paged, total: total, page: page, pageSize: pageSize);
    }

    // No local data - fetch from API
    return _fetchFromApi(page: page, pageSize: pageSize, filters: filters);
  }

  /// Get trip by ID - reads from local DB first
  Future<TripModel> getTripById(String id) async {
    final local = await _db.tripsDao.getById(id);
    if (local != null && !local.isDeleted) {
      // Background refresh
      if (ConnectivityService().isOnline) {
        _refreshTripFromApi(id);
      }
      return tripFromLocal(local);
    }

    // Fallback to API
    try {
      final response = await _dioClient.get('${ApiConfig.trips}/$id');
      final trip = TripModel.fromJson(response.data);
      await _db.tripsDao.upsert(tripToLocal(trip));
      return trip;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create trip - writes to local DB immediately, syncs in background
  Future<TripModel> createTrip(TripRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final trip = TripModel(
      id: id,
      userId: '', // Will be set by server
      title: request.title,
      description: request.description,
      coverImageUrl: request.coverImageUrl,
      startDate: request.startDate,
      endDate: request.endDate,
      status: request.status,
      tags: request.tags,
      budget: request.budget,
      displayCurrency: request.displayCurrency ?? 'USD',
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );

    // Save to local DB
    await _db.tripsDao.upsert(tripToLocal(trip, isDirty: true, isLocalOnly: true));

    // Enqueue sync
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: id,
      operation: 'create',
      payload: request.toJson(),
    );

    // Try immediate API call if online
    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post('${ApiConfig.trips}/', data: request.toJson());
        final serverTrip = TripModel.fromJson(response.data);
        await _db.tripsDao.upsert(tripToLocal(serverTrip));
        await _db.syncQueueDao.removeForEntity('trip', id);
        return serverTrip;
      } catch (e) {
        AppLogger.warning('Failed to sync trip create, will retry: $e');
      }
    }

    return trip;
  }

  /// Update trip - writes to local DB immediately, syncs in background
  Future<TripModel> updateTrip(String id, Map<String, dynamic> updates) async {
    // Update local DB
    final existing = await _db.tripsDao.getById(id);
    if (existing != null) {
      final updatedCompanion = LocalTripsCompanion(
        id: Value(id),
        title: updates.containsKey('title') ? Value(updates['title'] as String) : const Value.absent(),
        description: updates.containsKey('description') ? Value(updates['description'] as String?) : const Value.absent(),
        coverImageUrl: updates.containsKey('cover_image_url') ? Value(updates['cover_image_url'] as String?) : const Value.absent(),
        startDate: updates.containsKey('start_date') ? Value(updates['start_date'] as String) : const Value.absent(),
        endDate: updates.containsKey('end_date') ? Value(updates['end_date'] as String?) : const Value.absent(),
        status: updates.containsKey('status') ? Value(updates['status'] as String) : const Value.absent(),
        tags: updates.containsKey('tags') ? Value(jsonEncode(updates['tags'])) : const Value.absent(),
        budget: updates.containsKey('budget') ? Value((updates['budget'] as num?)?.toDouble()) : const Value.absent(),
        displayCurrency: updates.containsKey('display_currency') ? Value(updates['display_currency'] as String) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localTrips))..where((t) => t.id.equals(id))).write(updatedCompanion);
    }

    // Enqueue sync
    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: id,
      operation: 'update',
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    // Try immediate API call if online
    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch('${ApiConfig.trips}/$id', data: updates);
        final serverTrip = TripModel.fromJson(response.data);
        await _db.tripsDao.upsert(tripToLocal(serverTrip));
        await _db.syncQueueDao.removeForEntity('trip', id);
        return serverTrip;
      } catch (e) {
        AppLogger.warning('Failed to sync trip update, will retry: $e');
      }
    }

    final updated = await _db.tripsDao.getById(id);
    return updated != null ? tripFromLocal(updated) : throw 'Trip not found';
  }

  /// Delete trip - soft deletes locally, syncs in background
  Future<void> deleteTrip(String id) async {
    await _db.tripsDao.softDelete(id);

    await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete('${ApiConfig.trips}/$id');
        await _db.tripsDao.hardDelete(id);
        await _db.syncQueueDao.removeForEntity('trip', id);
      } catch (e) {
        AppLogger.warning('Failed to sync trip delete, will retry: $e');
      }
    }
  }

  /// Get available tags for user's trips
  Future<List<String>> getAvailableTags() async {
    // Try local first
    final localTrips = await _db.tripsDao.getAll();
    final localTags = localTrips
        .expand((t) => (jsonDecode(t.tags) as List).cast<String>())
        .toSet()
        .toList()
      ..sort();

    if (localTags.isNotEmpty || !ConnectivityService().isOnline) {
      return localTags;
    }

    try {
      final response = await _dioClient.get('${ApiConfig.trips}/tags');
      return List<String>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create default trips for new user
  Future<bool> createDefaultTrips() async {
    try {
      await _dioClient.post(ApiConfig.defaultTrips);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return false;
      throw _handleError(e);
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<TripsResponse> _fetchFromApi({
    int page = 1,
    int pageSize = 20,
    TripFilterModel? filters,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (filters != null) queryParams.addAll(filters.toQueryParams());

      final response = await _dioClient.get(ApiConfig.trips, queryParameters: queryParams);
      final tripsResponse = TripsResponse.fromJson(response.data);

      // Store in local DB
      for (final trip in tripsResponse.trips) {
        await _db.tripsDao.upsert(tripToLocal(trip));
      }

      return tripsResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi({TripFilterModel? filters}) async {
    try {
      final queryParams = <String, dynamic>{'page': 1, 'page_size': 100};
      if (filters != null) queryParams.addAll(filters.toQueryParams());
      final response = await _dioClient.get(ApiConfig.trips, queryParameters: queryParams);
      final tripsResponse = TripsResponse.fromJson(response.data);
      for (final trip in tripsResponse.trips) {
        final existing = await _db.tripsDao.getById(trip.id);
        if (existing == null || !existing.isDirty) {
          await _db.tripsDao.upsert(tripToLocal(trip));
        }
      }
    } catch (e) {
      AppLogger.warning('Background trip refresh failed: $e');
    }
  }

  void _refreshTripFromApi(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.trips}/$id');
      final trip = TripModel.fromJson(response.data);
      final existing = await _db.tripsDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await _db.tripsDao.upsert(tripToLocal(trip));
      }
    } catch (e) {
      AppLogger.warning('Background trip detail refresh failed: $e');
    }
  }

  List<TripModel> _applyFilters(List<TripModel> trips, TripFilterModel filters) {
    var filtered = trips;
    if (filters.search != null && filters.search!.isNotEmpty) {
      final q = filters.search!.toLowerCase();
      filtered = filtered.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    if (filters.status != null && filters.status!.isNotEmpty) {
      filtered = filtered.where((t) => filters.status!.contains(t.status)).toList();
    }
    if (filters.tags != null && filters.tags!.isNotEmpty) {
      filtered = filtered.where((t) => t.tags?.any((tag) => filters.tags!.contains(tag)) ?? false).toList();
    }
    return filtered;
  }

  List<TripModel> _applySorting(List<TripModel> trips, TripFilterModel filters) {
    final sorted = List<TripModel>.from(trips);
    final asc = filters.sortOrder == TripSortOrder.asc;
    switch (filters.sortBy) {
      case TripSortField.title:
        sorted.sort((a, b) => asc ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
      case TripSortField.startDate:
        sorted.sort((a, b) => asc ? a.startDate.compareTo(b.startDate) : b.startDate.compareTo(a.startDate));
      case TripSortField.updatedAt:
        sorted.sort((a, b) => asc ? a.updatedAt.compareTo(b.updatedAt) : b.updatedAt.compareTo(a.updatedAt));
      default:
        sorted.sort((a, b) => asc ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
