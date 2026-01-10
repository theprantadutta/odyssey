import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/repositories/device_repository.dart';

part 'notification_provider.g.dart';

/// Notification state
class NotificationState {
  final bool isInitialized;
  final bool hasPermission;
  final String? fcmToken;
  final bool isRegistering;
  final String? error;

  const NotificationState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.fcmToken,
    this.isRegistering = false,
    this.error,
  });

  NotificationState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    String? fcmToken,
    bool? isRegistering,
    String? error,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      fcmToken: fcmToken ?? this.fcmToken,
      isRegistering: isRegistering ?? this.isRegistering,
      error: error,
    );
  }
}

/// Device repository provider
@Riverpod(keepAlive: true)
DeviceRepository deviceRepository(Ref ref) {
  return DeviceRepository();
}

/// Notification state notifier provider
@Riverpod(keepAlive: true)
class Notifications extends _$Notifications {
  late final DeviceRepository _deviceRepository;
  late final NotificationService _notificationService;
  late final StorageService _storageService;
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  NotificationState build() {
    _deviceRepository = ref.read(deviceRepositoryProvider);
    _notificationService = NotificationService();
    _storageService = StorageService();

    // Clean up on dispose
    ref.onDispose(() {
      _tokenRefreshSubscription?.cancel();
    });

    return const NotificationState();
  }

  /// Initialize notifications
  Future<void> initialize({void Function(Map<String, dynamic>)? onTap}) async {
    if (state.isInitialized) return;

    try {
      // Initialize notification service
      await _notificationService.initialize(
        onNotificationTap: onTap,
      );

      // Request permission
      final hasPermission = await _notificationService.requestPermission();

      // Get FCM token
      final token = await _notificationService.getToken();

      // Listen for token refresh
      _tokenRefreshSubscription = _notificationService.onTokenRefresh.listen(
        _handleTokenRefresh,
      );

      state = state.copyWith(
        isInitialized: true,
        hasPermission: hasPermission,
        fcmToken: token,
      );

      AppLogger.info('Notifications initialized. Token: ${token?.substring(0, 20)}...');
    } catch (e) {
      AppLogger.error('Failed to initialize notifications', e);
      state = state.copyWith(
        isInitialized: true,
        error: e.toString(),
      );
    }
  }

  /// Register device with backend (call after user logs in)
  Future<bool> registerDevice() async {
    final token = state.fcmToken;
    if (token == null || token.isEmpty) {
      AppLogger.warning('No FCM token available for registration');
      return false;
    }

    state = state.copyWith(isRegistering: true, error: null);

    try {
      final success = await _deviceRepository.registerDevice(
        fcmToken: token,
      );

      state = state.copyWith(isRegistering: false);
      return success;
    } catch (e) {
      AppLogger.error('Failed to register device', e);
      state = state.copyWith(
        isRegistering: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Unregister device from backend (call before user logs out)
  Future<bool> unregisterDevice() async {
    final token = state.fcmToken;
    if (token == null || token.isEmpty) {
      return true; // No token to unregister
    }

    try {
      final success = await _deviceRepository.unregisterDevice(token);

      // Delete the FCM token
      await _notificationService.deleteToken();

      // Clear the token from state
      state = state.copyWith(fcmToken: null);

      return success;
    } catch (e) {
      AppLogger.error('Failed to unregister device', e);
      return false;
    }
  }

  /// Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    AppLogger.info('FCM token refreshed: ${newToken.substring(0, 20)}...');

    final oldToken = state.fcmToken;
    state = state.copyWith(fcmToken: newToken);

    // Check if user is authenticated before re-registering
    final isAuthenticated = await _storageService.isAuthenticated();
    if (isAuthenticated) {
      // Unregister old token if exists
      if (oldToken != null && oldToken.isNotEmpty) {
        await _deviceRepository.unregisterDevice(oldToken);
      }

      // Register new token
      await _deviceRepository.registerDevice(fcmToken: newToken);
    }
  }

  /// Request notification permissions again
  Future<bool> requestPermission() async {
    final hasPermission = await _notificationService.requestPermission();
    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }
}
