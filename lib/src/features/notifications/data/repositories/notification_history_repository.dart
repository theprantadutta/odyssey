import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/logger_service.dart';
import '../models/notification_history_model.dart';

/// Repository for managing notification history
class NotificationHistoryRepository {
  final DioClient _dioClient = DioClient();

  /// Get paginated notification history
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool? unreadOnly,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
      };

      if (unreadOnly != null) {
        queryParams['unreadOnly'] = unreadOnly;
      }

      final response = await _dioClient.get(
        ApiConfig.notifications,
        queryParameters: queryParams,
      );

      return NotificationListResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.error('Failed to get notifications', e);
      rethrow;
    }
  }

  /// Get unread notification count for badge display
  Future<int> getUnreadCount() async {
    try {
      final response = await _dioClient.get(
        ApiConfig.notificationsUnreadCount,
      );

      final unreadResponse = UnreadCountResponse.fromJson(response.data);
      return unreadResponse.count;
    } on DioException catch (e) {
      AppLogger.error('Failed to get unread count', e);
      rethrow;
    }
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _dioClient.patch(
        ApiConfig.notificationMarkRead(notificationId),
      );

      AppLogger.info('Notification marked as read: $notificationId');
      return true;
    } on DioException catch (e) {
      AppLogger.error('Failed to mark notification as read', e);
      return false;
    }
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() async {
    try {
      final response = await _dioClient.patch(
        ApiConfig.notificationsReadAll,
      );

      final markAllResponse = MarkAllReadResponse.fromJson(response.data);
      AppLogger.info('Marked ${markAllResponse.markedCount} notifications as read');
      return markAllResponse.markedCount;
    } on DioException catch (e) {
      AppLogger.error('Failed to mark all notifications as read', e);
      rethrow;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _dioClient.delete(
        ApiConfig.notificationDelete(notificationId),
      );

      AppLogger.info('Notification deleted: $notificationId');
      return true;
    } on DioException catch (e) {
      AppLogger.error('Failed to delete notification', e);
      return false;
    }
  }
}
