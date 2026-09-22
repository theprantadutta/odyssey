import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../models/statistics_model.dart';
import '../../../../core/session/account_session.dart';
import '../../../../common/errors/failure_message.dart';

/// Exception thrown when a premium feature is accessed by a free user
class PremiumRequiredException implements UserFacingException {
  @override
  String get userMessage => message;

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
    final scope = AccountSession().capture();
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
      await scope.write(() => _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data)));

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
    final scope = AccountSession().capture();
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

      await scope.write(() => _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data)));

      return timeline;
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Travel Timeline');
    }
  }

  // --- Private Methods ---

  /// The dashboard's figures, computed from the local database.
  ///
  /// These rules mirror `GetOverallStatsQueryHandler` on the server. Where the
  /// two disagreed, this side was wrong: it summed amounts across currencies
  /// into a number that is not a quantity of money, counted trips booked for
  /// next year as days already travelled, ignored open-ended trips, and filtered
  /// on a `planning` status the server calls `planned`.

  /// Today, with the time of day discarded.
  ///
  /// Trip dates are calendar days; comparing them against a timestamp makes a
  /// trip that started this morning look as though it has not started.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Parses a stored date, or null if it is absent or unreadable.
  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Reads the JSON-encoded tag list a trip row carries.
  static List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.map((t) => t.toString()).toList() : const [];
    } catch (_) {
      // A row we cannot read must not take the whole dashboard down.
      return const [];
    }
  }

  Future<OverallStatistics> _computeLocalStatistics() async {
    final trips = await _db.tripsDao.getAll();
    final activities = await _db.activitiesDao.getAll();
    final memories = await _db.memoriesDao.getAll();
    final expenses = await _db.expensesDao.getAll();

    final totalTrips = trips.length;
    final completedTrips = trips.where((t) => t.status == 'completed').length;
    final ongoingTrips = trips.where((t) => t.status == 'ongoing').length;

    // 'planned', not 'planning'. The server has never sent the latter, so this
    // count was always zero.
    final plannedTrips = trips.where((t) => t.status == 'planned').length;

    // The currency the user's trips are mostly kept in, chosen from the data
    // rather than assumed to be USD.
    final currencyCounts = <String, int>{};
    for (final trip in trips) {
      final currency = trip.displayCurrency;
      if (currency.isEmpty) continue;
      currencyCounts[currency] = (currencyCounts[currency] ?? 0) + 1;
    }

    final reportingCurrency = currencyCounts.isEmpty
        ? 'USD'
        : (currencyCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    // Each expense counts in the currency it is actually expressed in: its
    // converted amount where a conversion was recorded, otherwise its own.
    final denominated = expenses.map((e) {
      final converted = e.convertedAmount;
      final convertedCurrency = e.convertedCurrency;

      return converted != null &&
              convertedCurrency != null &&
              convertedCurrency.isNotEmpty
          ? (amount: converted, currency: convertedCurrency)
          : (amount: e.amount, currency: e.currency);
    }).toList();

    final expenseTotalsByCurrency = <String, double>{};
    for (final entry in denominated) {
      expenseTotalsByCurrency[entry.currency] =
          (expenseTotalsByCurrency[entry.currency] ?? 0) + entry.amount;
    }

    // The headline figure covers the reporting currency only. Anything else is
    // excluded and counted, rather than folded in at a guessed rate.
    final totalExpenseAmount = expenseTotalsByCurrency[reportingCurrency] ?? 0;

    final unconvertedExpenseCount = denominated
        .where((e) => e.currency.toUpperCase() != reportingCurrency.toUpperCase())
        .length;

    final today = _today();

    // Days actually travelled. A trip that has started counts up to today or
    // its end, whichever is sooner, inclusive of both days; a trip that has not
    // started counts nothing. Open-ended trips count too - being undated at the
    // far end does not mean the days did not happen.
    var totalDaysOfTravel = 0;
    var plannedDaysAhead = 0;

    for (final trip in trips) {
      final start = _parseDate(trip.startDate);
      if (start == null) continue;

      final end = _parseDate(trip.endDate);

      if (!start.isAfter(today)) {
        final effectiveEnd = end != null && end.isBefore(today) ? end : today;
        totalDaysOfTravel += effectiveEnd.difference(start).inDays + 1;
      } else if (end != null) {
        plannedDaysAhead += end.difference(start).inDays + 1;
      }
    }

    final activitiesByCategory = <String, int>{};
    for (final a in activities) {
      activitiesByCategory[a.category] =
          (activitiesByCategory[a.category] ?? 0) + 1;
    }

    // Categories are reported in the reporting currency only, for the same
    // reason the headline total is.
    final expensesByCategory = <String, double>{};
    for (var i = 0; i < expenses.length; i++) {
      final entry = denominated[i];
      if (entry.currency.toUpperCase() != reportingCurrency.toUpperCase()) {
        continue;
      }

      final category = expenses[i].category;
      expensesByCategory[category] =
          (expensesByCategory[category] ?? 0) + entry.amount;
    }

    final tripTags = <String>{};
    for (final trip in trips) {
      for (final tag in _decodeTags(trip.tags)) {
        if (tag.trim().isNotEmpty) tripTags.add(tag.trim());
      }
    }

    return OverallStatistics(
      totalTrips: totalTrips,
      completedTrips: completedTrips,
      ongoingTrips: ongoingTrips,
      plannedTrips: plannedTrips,
      totalActivities: activities.length,
      totalMemories: memories.length,
      totalExpenses: expenses.length,
      totalExpenseAmount: totalExpenseAmount,
      reportingCurrency: reportingCurrency,
      expenseTotalsByCurrency: expenseTotalsByCurrency,
      unconvertedExpenseCount: unconvertedExpenseCount,
      // Destinations are not recorded anywhere yet, here or on the server.
      // Reported as absent rather than as a zero that reads like a count.
      destinationDataAvailable: false,
      plannedDaysAhead: plannedDaysAhead,
      tripTags: tripTags.toList()..sort(),
      countriesVisited: 0,
      totalDaysOfTravel: totalDaysOfTravel,
      uniqueDestinations: const [],
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
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsYearInReview,
        queryParameters: year != null ? {'year': year} : null,
      );
      await scope.write(() => _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data)));
    } catch (e) {
      AppLogger.warning('Background year in review refresh failed: $e');
    }
  }

  void _refreshTravelTimeline(int limit, int offset, String cacheKey) async {
    final scope = AccountSession().capture();
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsTimeline,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      await scope.write(() => _db.subscriptionCacheDao.set(cacheKey, jsonEncode(response.data)));
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
