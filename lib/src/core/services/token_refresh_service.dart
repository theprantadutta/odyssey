import 'dart:async';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'logger_service.dart';
import 'storage_service.dart';

/// Service to handle token refresh operations.
/// Uses a separate Dio instance to avoid interceptor loops.
class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  factory TokenRefreshService() => _instance;
  TokenRefreshService._internal();

  final StorageService _storageService = StorageService();

  // Separate Dio instance without auth interceptors to avoid loops
  late final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.fullBaseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': ApiConfig.contentTypeJson,
        'Accept': ApiConfig.contentTypeJson,
      },
    ),
  );

  // Lock to prevent multiple simultaneous refresh requests
  Completer<bool>? _refreshCompleter;
  bool _isRefreshing = false;

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if refresh was successful, false otherwise.
  /// Uses a lock to ensure only one refresh happens at a time.
  Future<bool> refreshToken() async {
    // If already refreshing, wait for that to complete
    if (_isRefreshing && _refreshCompleter != null) {
      AppLogger.auth('Token refresh already in progress, waiting...');
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _storageService.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.auth('No refresh token available', isError: true);
        _completeRefresh(false);
        return false;
      }

      AppLogger.auth('Attempting to refresh access token...');

      final response = await _refreshDio.post(
        ApiConfig.refresh,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (newAccessToken != null && newRefreshToken != null) {
          // Save new tokens
          await _storageService.saveAccessToken(newAccessToken);
          await _storageService.saveRefreshToken(newRefreshToken);

          // Calculate and save expiry time
          if (expiresIn != null) {
            final expiry = DateTime.now().add(Duration(seconds: expiresIn));
            await _storageService.saveAccessTokenExpiry(expiry);
          }

          AppLogger.auth('Token refresh successful');
          _completeRefresh(true);
          return true;
        }
      }

      AppLogger.auth('Token refresh failed - invalid response', isError: true);
      _completeRefresh(false);
      return false;
    } on DioException catch (e) {
      AppLogger.auth(
        'Token refresh failed: ${e.response?.statusCode ?? e.message}',
        isError: true,
      );

      // If refresh token is invalid/expired, clear all auth data
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _storageService.clearAuthData();
      }

      _completeRefresh(false);
      return false;
    } catch (e) {
      AppLogger.auth('Token refresh error: $e', isError: true);
      _completeRefresh(false);
      return false;
    }
  }

  void _completeRefresh(bool success) {
    _isRefreshing = false;
    _refreshCompleter?.complete(success);
    _refreshCompleter = null;
  }

  /// Proactively refresh token if it's about to expire.
  /// Call this before making requests to ensure token is fresh.
  Future<void> ensureValidToken() async {
    final isExpired = await _storageService.isAccessTokenExpired();
    if (isExpired) {
      final hasRefreshToken = await _storageService.getRefreshToken() != null;
      if (hasRefreshToken) {
        await refreshToken();
      }
    }
  }
}
