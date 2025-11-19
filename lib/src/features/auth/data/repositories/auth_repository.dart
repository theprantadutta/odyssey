import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/config/api_config.dart';
import '../models/user_model.dart';

/// Authentication repository for API calls
class AuthRepository {
  final DioClient _dioClient = DioClient();
  final StorageService _storageService = StorageService();

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String password,
  }) async {
    try {
      final request = AuthRequest(email: email, password: password);
      final response = await _dioClient.post(
        ApiConfig.register,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Save token and user ID
      await _storageService.saveAccessToken(authResponse.accessToken);
      await _storageService.saveUserId(authResponse.userId);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Login existing user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = AuthRequest(email: email, password: password);
      final response = await _dioClient.post(
        ApiConfig.login,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);

      // Save token and user ID
      await _storageService.saveAccessToken(authResponse.accessToken);
      await _storageService.saveUserId(authResponse.userId);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current user info
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dioClient.get(ApiConfig.me);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Call logout endpoint (optional, backend may not require this)
      try {
        await _dioClient.post(ApiConfig.logout);
      } catch (_) {
        // Ignore logout endpoint errors
      }

      // Clear local storage
      await _storageService.clearAll();
    } catch (e) {
      // Always clear storage even if API call fails
      await _storageService.clearAll();
      rethrow;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _storageService.isAuthenticated();
  }

  /// Handle Dio errors and throw user-friendly messages
  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;

      // FastAPI returns {"detail": "error message"}
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }

    // Fallback to generic error from interceptor
    return error.error?.toString() ?? 'Authentication failed';
  }
}
