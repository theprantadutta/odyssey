import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'dio_interceptors.dart';

/// Dio client factory with configured interceptors
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  /// Initialize Dio with base configuration and interceptors
  void init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.fullBaseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': ApiConfig.contentTypeJson,
          'Accept': ApiConfig.contentTypeJson,
        },
        responseType: ResponseType.json,
      ),
    );

    // Add interceptors in order
    _dio.interceptors.addAll([
      AuthInterceptor(), // Add JWT token to requests
      LoggingInterceptor(), // Log requests/responses (dev only)
      ErrorInterceptor(), // Handle errors
    ]);
  }

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// Multipart request (for file uploads)
  Future<Response> multipart(
    String path,
    FormData formData, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: ApiConfig.contentTypeMultipart,
        ),
      );
    } on DioException {
      rethrow;
    }
  }
}
