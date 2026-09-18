import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../config/api_config.dart';
import '../session/account_session.dart';
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

  /// The refresh client, for tests that need to hold a refresh in flight.
  ///
  /// Refresh deliberately bypasses `DioClient` to avoid an interceptor loop,
  /// which also puts it out of reach of the adapter a test installs there. The
  /// behaviour worth testing - what a refresh does when it outlives its own
  /// session - cannot be reached any other way.
  @visibleForTesting
  Dio get refreshDioForTesting => _refreshDio;

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

    // Captured before the request. A refresh outliving its own session is the
    // most damaging late response in the app: the tokens it writes are the ones
    // every later request is sent with, so a refresh started by one account and
    // answered after another has signed in would hand the new session the old
    // account's credentials. The 401 branch is as bad in the other direction -
    // it clears auth data, which would sign the *new* account out.
    final scope = AccountSession().capture();

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
          if (!scope.isCurrent) {
            // Valid tokens, for an account that is no longer signed in. Storing
            // them would overwrite whoever is signed in now.
            AppLogger.auth(
                'Discarding a token refresh that outlived its session');
            _completeRefresh(false);
            return false;
          }

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

      // If refresh token is invalid/expired, clear all auth data - but only if
      // it is still this account's auth data. A rejected refresh belonging to a
      // session that has already ended must not sign out the account that has
      // since signed in.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (scope.isCurrent) {
          await _storageService.clearAuthData();
        } else {
          AppLogger.auth(
              'A rejected refresh outlived its session; auth data left alone');
        }
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
