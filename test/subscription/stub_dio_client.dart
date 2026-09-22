import 'package:dio/dio.dart';
import 'package:odyssey/src/core/network/dio_client.dart';

/// A `DioClient` that answers from a script instead of the network.
class StubDioClient implements DioClient {
  final List<String> requested = <String>[];
  final Map<String, Future<Map<String, dynamic>> Function()> _handlers = {};

  void onGet(String path, Future<Map<String, dynamic>> Function() handler) {
    _handlers[path] = handler;
  }

  int callsTo(String path) => requested.where((p) => p == path).length;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requested.add(path);

    final handler = _handlers[path];
    if (handler == null) {
      // Usage, limits and pricing are not what these tests are about. Failing
      // them also checks they cannot take entitlement down with them.
      throw StateError('no stubbed response for $path');
    }

    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: await handler(),
    );
  }

  @override
  Dio get dio => throw UnimplementedError();

  @override
  void init() => throw UnimplementedError();

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<Response> multipart(
    String path,
    FormData formData, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => throw UnimplementedError();
}
