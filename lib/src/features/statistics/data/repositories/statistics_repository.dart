import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../models/statistics_model.dart';

/// Exception thrown when a premium feature is accessed by a free user
class PremiumRequiredException implements Exception {
  final String message;
  final String featureName;

  PremiumRequiredException({
    required this.message,
    this.featureName = 'Full Statistics',
  });

  @override
  String toString() => message;
}

/// Statistics repository - computes from local DB with API enrichment
class StatisticsRepository {
  final DioClient _dioClient = DioClient();
  final _db = DatabaseService().database;

  /// Get overall statistics - computed from local DB
  Future<OverallStatistics> getOverallStatistics() async {
    try {
      // Compute from local DB
      final stats = await _computeLocalStatistics();

      // Background refresh from API if online (for fields we can't compute locally)
      if (ConnectivityService().isOnline) {
        _refreshStatisticsFromApi();
      }

      return stats;
    } catch (e) {
      // If local computation fails and we're online, fall back to API
      if (ConnectivityService().isOnline) {
        try {
          final response = await _dioClient.get(ApiConfig.statistics);
          return OverallStatistics.fromJson(response.data);
        } on DioException catch (e) {
          throw _handleError(e, featureName: 'Full Statistics');
        }
      }
      rethrow;
    }
  }

  /// Year in review - premium, API with cache
  Future<YearInReviewStats> getYearInReview({int? year}) async {
    final cacheKey = 'year_in_review_${year ?? DateTime.now().year}';

    // Try cache first
    final cached = await _db.subscriptionCacheDao.get(cacheKey);
    if (cached != null) {
      final stats = YearInReviewStats.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshYearInReview(year, cacheKey);
      }

      return stats;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Year in Review data is not available offline. Please connect to the internet to load it first.';
    }

    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsYearInReview,
        queryParameters: year != null ? {'year': year} : null,
      );
      final stats = YearInReviewStats.fromJson(response.data);

      // Cache for offline access
      await _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data));

      return stats;
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Year in Review');
    }
  }

  /// Travel timeline - premium, API with cache
  Future<TravelTimeline> getTravelTimeline({
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = 'travel_timeline_${limit}_$offset';

    // Try cache first
    final cached = await _db.subscriptionCacheDao.get(cacheKey);
    if (cached != null) {
      final timeline = TravelTimeline.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshTravelTimeline(limit, offset, cacheKey);
      }

      return timeline;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Travel Timeline data is not available offline. Please connect to the internet to load it first.';
    }

    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsTimeline,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final timeline = TravelTimeline.fromJson(response.data);

      await _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data));

      return timeline;
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Travel Timeline');
    }
  }

  // --- Private Methods ---

  Future<OverallStatistics> _computeLocalStatistics() async {
    final trips = await _db.tripsDao.getAll();
    final activities = await _db.activitiesDao.getAll();
    final memories = await _db.memoriesDao.getAll();
    final expenses = await _db.expensesDao.getAll();

    final totalTrips = trips.length;
    final completedTrips = trips.where((t) => t.status == 'completed').length;
    final ongoingTrips = trips.where((t) => t.status == 'ongoing').length;
    final plannedTrips = trips.where((t) => t.status == 'planning').length;
    final totalActivities = activities.length;
    final totalMemories = memories.length;
    final totalExpenses = expenses.length;
    final totalExpenseAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Compute total days of travel from trip start/end dates
    int totalDaysOfTravel = 0;
    for (final trip in trips) {
      if (trip.endDate != null && trip.endDate!.isNotEmpty) {
        try {
          final start = DateTime.parse(trip.startDate);
          final end = DateTime.parse(trip.endDate!);
          totalDaysOfTravel += end.difference(start).inDays.abs();
        } catch (_) {}
      }
    }

    // Activities by category
    final activitiesByCategory = <String, int>{};
    for (final a in activities) {
      activitiesByCategory[a.category] = (activitiesByCategory[a.category] ?? 0) + 1;
    }

    // Expenses by category
    final expensesByCategory = <String, double>{};
    for (final e in expenses) {
      expensesByCategory[e.category] = (expensesByCategory[e.category] ?? 0) + e.amount;
    }

    return OverallStatistics(
      totalTrips: totalTrips,
      completedTrips: completedTrips,
      ongoingTrips: ongoingTrips,
      plannedTrips: plannedTrips,
      totalActivities: totalActivities,
      totalMemories: totalMemories,
      totalExpenses: totalExpenses,
      totalExpenseAmount: totalExpenseAmount,
      countriesVisited: 0, // Requires geocoding data not in local schema
      totalDaysOfTravel: totalDaysOfTravel,
      uniqueDestinations: [], // Requires geocoding data not in local schema
      activitiesByCategory: activitiesByCategory,
      expensesByCategory: expensesByCategory,
    );
  }

  void _refreshStatisticsFromApi() async {
    try {
      await _dioClient.get(ApiConfig.statistics);
      // Trigger the API call to keep things fresh on the server side
      // The local computation is the source of truth for offline
    } catch (e) {
      AppLogger.warning('Background statistics refresh failed: $e');
    }
  }

  void _refreshYearInReview(int? year, String cacheKey) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsYearInReview,
        queryParameters: year != null ? {'year': year} : null,
      );
      await _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data));
    } catch (e) {
      AppLogger.warning('Background year in review refresh failed: $e');
    }
  }

  void _refreshTravelTimeline(int limit, int offset, String cacheKey) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsTimeline,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      await _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data));
    } catch (e) {
      AppLogger.warning('Background travel timeline refresh failed: $e');
    }
  }

  Object _handleError(DioException e, {required String featureName}) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      // Check for 403 premium feature error
      if (statusCode == 403) {
        final message = data is Map && data.containsKey('error')
            ? data['error']
            : 'This feature requires Premium';
        return PremiumRequiredException(
          message: message,
          featureName: featureName,
        );
      }

      if (data is Map && data.containsKey('detail')) {
        return data['detail'];
      }
      return 'An error occurred: $statusCode';
    }
    return e.message ?? 'Network error occurred';
  }
}
