import 'package:dio/dio.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../services/token_refresh_service.dart';

/// Interceptor to add JWT token to all requests and handle token refresh.
/// Uses QueuedInterceptor to queue requests during token refresh.
class AuthInterceptor extends QueuedInterceptor {
  final StorageService _storageService = StorageService();
  final TokenRefreshService _tokenRefreshService = TokenRefreshService();

  // Track if we've already tried refreshing for a request to avoid infinite loops
  static const String _retryKey = 'x-retry-after-refresh';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for refresh endpoint itself
    if (options.path.contains('/auth/refresh')) {
      return handler.next(options);
    }

    // Check if token is about to expire and proactively refresh
    final isExpired = await _storageService.isAccessTokenExpired();
    if (isExpired) {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        AppLogger.auth('Token expired, attempting proactive refresh...');
        final refreshed = await _tokenRefreshService.refreshToken();
        if (!refreshed) {
          AppLogger.auth('Proactive refresh failed', isError: true);
          // Don't fail the request yet, let it try and handle 401 in onError
        }
      }
    }

    // Get token from secure storage
    final token = await _storageService.getAccessToken();

    // Add Authorization header if token exists
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      AppLogger.auth('Token attached to request');
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized - token expired or invalid
    if (err.response?.statusCode == 401) {
      final requestOptions = err.requestOptions;

      // Skip retry for auth endpoints (except /me)
      if (requestOptions.path.contains('/auth/') &&
          !requestOptions.path.contains('/auth/me')) {
        return handler.next(err);
      }

      // Check if we've already tried refreshing for this request
      if (requestOptions.extra[_retryKey] == true) {
        AppLogger.auth('Already retried after refresh, giving up', isError: true);
        await _storageService.clearAuthData();
        return handler.next(err);
      }

      // Check if we have a refresh token
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.auth('No refresh token available, clearing auth data', isError: true);
        await _storageService.clearAuthData();
        return handler.next(err);
      }

      // Attempt to refresh the token
      AppLogger.auth('401 received, attempting token refresh...');
      final refreshed = await _tokenRefreshService.refreshToken();

      if (refreshed) {
        // Retry the original request with new token
        AppLogger.auth('Token refreshed, retrying original request');
        try {
          final token = await _storageService.getAccessToken();
          requestOptions.headers['Authorization'] = 'Bearer $token';
          requestOptions.extra[_retryKey] = true;

          // Create a new Dio instance for the retry to avoid interceptor loops
          final retryDio = Dio(BaseOptions(
            baseUrl: requestOptions.baseUrl,
            connectTimeout: requestOptions.connectTimeout,
            receiveTimeout: requestOptions.receiveTimeout,
            sendTimeout: requestOptions.sendTimeout,
          ));

          final response = await retryDio.fetch(requestOptions);
          return handler.resolve(response);
        } catch (retryError) {
          AppLogger.auth('Retry after refresh failed: $retryError', isError: true);
          if (retryError is DioException) {
            return handler.next(retryError);
          }
          return handler.next(err);
        }
      } else {
        // Refresh failed, clear auth data
        AppLogger.auth('Token refresh failed, clearing auth data', isError: true);
        await _storageService.clearAuthData();
      }
    }

    return handler.next(err);
  }
}

/// Interceptor for logging API requests and responses
class LoggingInterceptor extends Interceptor {
  final Map<String, DateTime> _requestTimestamps = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Store timestamp for duration calculation
    _requestTimestamps[options.uri.toString()] = DateTime.now();

    AppLogger.request(
      method: options.method,
      url: options.uri.toString(),
      headers: options.headers.map((k, v) => MapEntry(k, v.toString())),
      body: options.data,
    );
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final url = response.requestOptions.uri.toString();
    final startTime = _requestTimestamps.remove(url);
    final durationMs = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : null;

    AppLogger.response(
      statusCode: response.statusCode ?? 0,
      url: url,
      body: response.data,
      durationMs: durationMs,
    );
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final url = err.requestOptions.uri.toString();
    _requestTimestamps.remove(url);

    AppLogger.networkError(
      url: url,
      message: err.message ?? 'Unknown error',
      statusCode: err.response?.statusCode,
      error: err.response?.data,
    );
    return super.onError(err, handler);
  }
}

/// Interceptor for handling common errors
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String errorMessage = _handleError(err);

    // Create new DioException with user-friendly message
    final newErr = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: errorMessage,
    );

    return handler.next(newErr);
  }

  String _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';

      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response?.statusCode);

      case DioExceptionType.cancel:
        return 'Request cancelled';

      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';

      case DioExceptionType.unknown:
        return 'An unexpected error occurred. Please try again.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _handleStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication failed. Please login again.';
      case 403:
        return 'Access denied. You don\'t have permission.';
      case 404:
        return 'Resource not found.';
      case 422:
        return 'Validation error. Please check your input.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'Error occurred (Status: $statusCode)';
    }
  }
}
