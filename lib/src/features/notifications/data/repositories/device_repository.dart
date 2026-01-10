import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/logger_service.dart';

/// Repository for managing device registration with the backend
class DeviceRepository {
  final DioClient _dioClient = DioClient();

  /// Register a device token with the backend
  Future<bool> registerDevice({
    required String fcmToken,
    String? deviceName,
  }) async {
    try {
      final platform = Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid
              ? 'Android'
              : 'Unknown';

      await _dioClient.post(
        ApiConfig.deviceRegister,
        data: {
          'fcm_token': fcmToken,
          'device_name': deviceName,
          'platform': platform,
        },
      );

      AppLogger.info('Device registered successfully');
      return true;
    } on DioException catch (e) {
      AppLogger.error('Failed to register device', e);
      return false;
    }
  }

  /// Unregister a device token from the backend
  Future<bool> unregisterDevice(String fcmToken) async {
    try {
      await _dioClient.delete(
        ApiConfig.deviceUnregister(fcmToken),
      );

      AppLogger.info('Device unregistered successfully');
      return true;
    } on DioException catch (e) {
      AppLogger.error('Failed to unregister device', e);
      return false;
    }
  }
}
