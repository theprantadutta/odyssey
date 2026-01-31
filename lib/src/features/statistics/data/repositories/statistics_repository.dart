import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
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

class StatisticsRepository {
  final DioClient _dioClient = DioClient();

  Future<OverallStatistics> getOverallStatistics() async {
    try {
      final response = await _dioClient.get(ApiConfig.statistics);
      return OverallStatistics.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Full Statistics');
    }
  }

  Future<YearInReviewStats> getYearInReview({int? year}) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsYearInReview,
        queryParameters: year != null ? {'year': year} : null,
      );
      return YearInReviewStats.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Year in Review');
    }
  }

  Future<TravelTimeline> getTravelTimeline({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.statisticsTimeline,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return TravelTimeline.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e, featureName: 'Travel Timeline');
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
