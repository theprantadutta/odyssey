import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/statistics_model.dart';

class StatisticsRepository {
  final DioClient _dioClient = DioClient();

  Future<OverallStatistics> getOverallStatistics() async {
    try {
      final response = await _dioClient.get(ApiConfig.statistics);
      return OverallStatistics.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
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
      throw _handleError(e);
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
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'];
      }
      return 'An error occurred: ${e.response!.statusCode}';
    }
    return e.message ?? 'Network error occurred';
  }
}
