import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/logger_service.dart';
import '../models/notification_preference_model.dart';

class NotificationPreferenceRepository {
  final DioClient _dioClient = DioClient();

  static const String _preferencesPath = '${ApiConfig.notifications}/preferences';

  /// Get notification preferences for the current user
  Future<NotificationPreferenceModel> getPreferences() async {
    try {
      final response = await _dioClient.get(_preferencesPath);
      return NotificationPreferenceModel.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.error('Failed to get notification preferences', e);
      rethrow;
    }
  }

  /// Update notification preferences
  Future<NotificationPreferenceModel> updatePreferences(
      NotificationPreferenceModel preferences) async {
    try {
      final response = await _dioClient.put(
        _preferencesPath,
        data: preferences.toJson(),
      );
      return NotificationPreferenceModel.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.error('Failed to update notification preferences', e);
      rethrow;
    }
  }
}
