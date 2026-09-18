import 'dart:async';

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
import '../../../../core/sync/local_record_reconciler.dart';
import '../models/default_trips_eligibility.dart';
import '../models/trip_model.dart';
import 'trip_date_filter.dart';
import '../models/trip_filter_model.dart';
import '../../../../core/session/account_session.dart';
import '../../../../core/sync/base_version.dart';
import '../../../../core/sync/sync_service.dart';

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
      final response = _pageLocalTrips(
        localTrips.map(tripFromLocal).toList(),
        page: page,
        pageSize: pageSize,
        filters: filters,
      );

      // Trigger background refresh if online
      if (ConnectivityService().isOnline) {
        _refreshFromApi(filters: filters);
      }

      return response;
    }

    // No local data - fetch from API
    return _fetchFromApi(page: page, pageSize: pageSize, filters: filters);
  }

  /// Get trip by ID - reads from local DB first
  Future<TripModel> getTripById(String id) async {
    final scope = AccountSession().capture();
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
      await scope.write(() => _db.tripsDao.upsert(tripToLocal(trip)));
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
      payload: withClientId(id, request.toJson()),
    );

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());

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
      payload: {...updates, '_base_version': baseVersionOf(existing)},
    );

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());

    final updated = await _db.tripsDao.getById(id);
    return updated != null ? tripFromLocal(updated) : throw 'Trip not found';
  }

  /// Delete trip - soft deletes locally, syncs in background
  Future<void> deleteTrip(String id) async {
    await _db.tripsDao.softDelete(id);

    final queued = await SyncQueueService().enqueue(
      entityType: 'trip',
      entityId: id,
      operation: 'delete',
      payload: {},
    );

    // The delete cancelled a create that never reached the server, so there is
    // nothing to sync and nothing to keep: drop the row instead of leaving a
    // soft-deleted ghost that is hidden from the user and never syncs away.
    if (!queued) {
      await LocalRecordReconciler(_db)
          .purgeLocalOnly(entityType: 'trip', id: id);
      return;
    }

    // One write path. The request is made by the sync service, which is
    // the only place that knows which revision an acknowledgement is for
    // and how to merge a response with an edit made since. Issuing it here
    // as well, and then clearing the queue for this entity, is what lost
    // an edit made while the first request was in flight.
    unawaited(SyncService().performSync());
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

  /// Whether the sample trips can still be added to this account (once per account).
  Future<DefaultTripsEligibility> getDefaultTripsEligibility() async {
    try {
      final response = await _dioClient.get(ApiConfig.defaultTripsEligibility);
      return DefaultTripsEligibility.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create the sample trips. Returns the created trips, or null if the account
  /// has already used its one-time allowance (409).
  Future<List<TripModel>?> createDefaultTrips() async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.post(ApiConfig.defaultTrips);

      final created = (response.data as List<dynamic>)
          .map((json) => TripModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Write straight into the local DB. getTrips() is local-first and only
      // awaits the API when local is empty, so without this the new trips would
      // not surface until some later background refresh.
      for (final trip in created) {
        await scope.write(() => _db.tripsDao.upsert(tripToLocal(trip)));
      }

      return created;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return null;
      throw _handleError(e);
    }
  }

  /// Remove every demo trip from this account. Returns how many were deleted.
  Future<int> deleteDemoTrips() async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.delete(ApiConfig.deleteDemoTrips);
      final deletedIds = (response.data['deleted_trip_ids'] as List<dynamic>? ?? [])
          .map((id) => id as String);

      // Drop the same rows from the local mirror - getTrips() is local-first and would
      // otherwise keep serving them from Drift. hardDelete, not softDelete: the server
      // has already done the deletion, so there is nothing left to sync back.
      for (final id in deletedIds) {
        await scope.write(() => _db.tripsDao.hardDelete(id));
      }

      return (response.data['deleted_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Private Methods ──────────────────────────────────────────

  Future<TripsResponse> _fetchFromApi({
    int page = 1,
    int pageSize = 20,
    TripFilterModel? filters,
  }) async {
    final scope = AccountSession().capture();
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (filters != null) queryParams.addAll(filters.toQueryParams());

      final response = await _dioClient.get(ApiConfig.trips, queryParameters: queryParams);
      final tripsResponse = TripsResponse.fromJson(response.data);

      // Store in local DB
      for (final trip in tripsResponse.trips) {
        await scope.write(() => _db.tripsDao.upsert(tripToLocal(trip)));
      }

      return tripsResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshFromApi({TripFilterModel? filters}) async {
    final scope = AccountSession().capture();
    try {
      final queryParams = <String, dynamic>{'page': 1, 'page_size': 100};
      if (filters != null) queryParams.addAll(filters.toQueryParams());
      final response = await _dioClient.get(ApiConfig.trips, queryParameters: queryParams);
      final tripsResponse = TripsResponse.fromJson(response.data);
      for (final trip in tripsResponse.trips) {
        final existing = await _db.tripsDao.getById(trip.id);
        if (existing == null || !existing.isDirty) {
          await scope.write(() => _db.tripsDao.upsert(tripToLocal(trip)));
        }
      }
    } catch (e) {
      AppLogger.warning('Background trip refresh failed: $e');
    }
  }

  void _refreshTripFromApi(String id) async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get('${ApiConfig.trips}/$id');
      final trip = TripModel.fromJson(response.data);
      final existing = await _db.tripsDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await scope.write(() => _db.tripsDao.upsert(tripToLocal(trip)));
      }
    } catch (e) {
      AppLogger.warning('Background trip detail refresh failed: $e');
    }
  }

  /// Reads trips from the local database **without** triggering a refresh.
  ///
  /// The visible list subscribes to the database, and every read that also
  /// kicked off a network refresh would refresh, write, wake the subscription,
  /// read, and refresh again. This is the read for when something has already
  /// changed underneath.
  Future<TripsResponse> getLocalTrips({
    int page = 1,
    int pageSize = 20,
    TripFilterModel? filters,
  }) async {
    final localTrips = await _db.tripsDao.getAll();

    return _pageLocalTrips(
      localTrips.map(tripFromLocal).toList(),
      page: page,
      pageSize: pageSize,
      filters: filters,
    );
  }

  /// Filters, sorts and pages a local list the way the server would.
  TripsResponse _pageLocalTrips(
    List<TripModel> trips, {
    required int page,
    required int pageSize,
    TripFilterModel? filters,
  }) {
    if (filters != null && filters.hasActiveFilters) {
      trips = _applyFilters(trips, filters);
    }

    if (filters != null && filters.hasCustomSorting) {
      trips = _applySorting(trips, filters);
    }

    final total = trips.length;
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, total);
    final paged = start < total ? trips.sublist(start, end) : <TripModel>[];

    return TripsResponse(
      trips: paged, total: total, page: page, pageSize: pageSize);
  }

  /// Emits whenever the local trip rows change.
  Stream<void> watchLocalTrips() => _db.tripsDao.watchAll();

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

    // Date bounds were exposed by the filter model and the filter UI, and were
    // simply not implemented here - so they worked against a fresh API response
    // and stopped working the moment the list came from the local database,
    // which is every offline use and most online ones.
    if (filters.startDateFrom != null || filters.startDateTo != null) {
      filtered = filtered
          .where((t) => matchesStartDateRange(
                t.startDate,
                from: filters.startDateFrom,
                to: filters.startDateTo,
              ))
          .toList();
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
