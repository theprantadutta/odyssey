import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/activity_model.dart';

/// Activity repository for API calls
class ActivityRepository {
  final DioClient _dioClient = DioClient();

  /// Get all activities for a trip
  Future<ActivitiesResponse> getActivities({
    required String tripId,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConfig.activities,
        queryParameters: {'trip_id': tripId},
      );

      return ActivitiesResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get activity by ID
  Future<ActivityModel> getActivityById(String id) async {
    try {
      final response = await _dioClient.get('${ApiConfig.activities}/$id');
      return ActivityModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create new activity
  Future<ActivityModel> createActivity(ActivityRequest request) async {
    try {
      final response = await _dioClient.post(
        '${ApiConfig.activities}/',
        data: request.toJson(),
      );

      return ActivityModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update activity
  Future<ActivityModel> updateActivity(
      String id, Map<String, dynamic> updates) async {
    try {
      final response = await _dioClient.patch(
        '${ApiConfig.activities}/$id',
        data: updates,
      );

      return ActivityModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete activity
  Future<void> deleteActivity(String id) async {
    try {
      await _dioClient.delete('${ApiConfig.activities}/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reorder activities (for drag-and-drop)
  Future<void> reorderActivities({
    required String tripId,
    required List<ActivityOrder> activityOrders,
  }) async {
    try {
      final request = ReorderRequest(activityOrders: activityOrders);
      await _dioClient.put(
        '${ApiConfig.activities}/reorder',
        queryParameters: {'trip_id': tripId},
        data: request.toJson(),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
