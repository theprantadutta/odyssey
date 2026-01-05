import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/google_sign_in_service.dart';
import '../../../../core/config/api_config.dart';
import '../models/user_model.dart';

/// Exception thrown when account linking is required
class AccountLinkingRequiredException implements Exception {
  final String message;
  final String firebaseToken;

  AccountLinkingRequiredException({
    required this.message,
    required this.firebaseToken,
  });

  @override
  String toString() => message;
}

/// Authentication repository for API calls
class AuthRepository {
  final DioClient _dioClient = DioClient();
  final StorageService _storageService = StorageService();
  final GoogleSignInService _googleSignInService = GoogleSignInService();

  /// Save all auth tokens and user ID from response
  Future<void> _saveAuthTokens(AuthResponse response) async {
    await _storageService.saveAccessToken(response.accessToken);
    await _storageService.saveUserId(response.userId);

    // Save refresh token if present
    if (response.refreshToken.isNotEmpty) {
      await _storageService.saveRefreshToken(response.refreshToken);
    }

    // Calculate and save token expiry time
    if (response.expiresIn > 0) {
      final expiry = DateTime.now().add(Duration(seconds: response.expiresIn));
      await _storageService.saveAccessTokenExpiry(expiry);
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final request = RegisterRequest(
        email: email,
        password: password,
        displayName: displayName,
      );
      final response = await _dioClient.post(
        ApiConfig.register,
        data: request.toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthTokens(authResponse);

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
      await _saveAuthTokens(authResponse);

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

  /// Logout user (revokes current refresh token)
  Future<void> logout() async {
    try {
      // Get refresh token to revoke
      final refreshToken = await _storageService.getRefreshToken();

      // Call logout endpoint to revoke the refresh token
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await _dioClient.post(
            ApiConfig.logout,
            data: {'refresh_token': refreshToken},
          );
        } catch (_) {
          // Ignore logout endpoint errors - token may already be invalid
        }
      }

      // Clear local auth data (preserves intro/onboarding state)
      await _storageService.clearAuthData();
    } catch (e) {
      // Always clear auth data even if API call fails
      await _storageService.clearAuthData();
      rethrow;
    }
  }

  /// Logout from all devices (revokes all refresh tokens)
  Future<void> logoutAll() async {
    try {
      await _dioClient.post(ApiConfig.logoutAll);
      await _storageService.clearAuthData();
    } catch (e) {
      // Always clear local auth data even if API call fails
      await _storageService.clearAuthData();
      rethrow;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _storageService.isAuthenticated();
  }

  /// Sign in with Google
  ///
  /// Returns AuthResponse on success
  /// Throws AccountLinkingRequiredException if account linking is needed
  /// Returns null if user cancelled
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      // Step 1: Sign in with Google via Firebase
      final userCredential = await _googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        return null; // User cancelled
      }

      // Step 2: Get Firebase ID token
      final firebaseToken = await _googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        throw Exception('Failed to get Firebase token');
      }

      // Step 3: Authenticate with backend
      return await _authenticateWithFirebaseToken(firebaseToken);
    } on AccountLinkingRequiredException {
      rethrow;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      // Sign out from Google if backend auth failed
      await _googleSignInService.signOut();
      rethrow;
    }
  }

  /// Authenticate with Firebase token (used internally and for linking)
  Future<AuthResponse> _authenticateWithFirebaseToken(String firebaseToken) async {
    try {
      final response = await _dioClient.post(
        ApiConfig.googleAuth,
        data: {'firebase_token': firebaseToken},
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthTokens(authResponse);

      return authResponse;
    } on DioException catch (e) {
      // Check for account linking required (409 conflict)
      if (e.response?.statusCode == 409) {
        final message = e.response?.data['detail'] ?? 'Account linking required';
        throw AccountLinkingRequiredException(
          message: message,
          firebaseToken: firebaseToken,
        );
      }
      rethrow;
    }
  }

  /// Link Google account to existing email/password account (with password)
  Future<AuthResponse> linkGoogleAccount({
    required String firebaseToken,
    required String password,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConfig.linkGoogle,
        data: {
          'firebase_token': firebaseToken,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthTokens(authResponse);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Auto-link Google account to existing email/password account (no password required)
  /// This relies on Google's email verification for security
  Future<AuthResponse> autoLinkGoogleAccount({
    required String firebaseToken,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiConfig.autoLinkGoogle,
        data: {
          'firebase_token': firebaseToken,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthTokens(authResponse);

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Unlink Google account from user
  Future<void> unlinkGoogle() async {
    try {
      await _dioClient.post(ApiConfig.unlinkGoogle);
      await _googleSignInService.signOut();
    } on DioException catch (e) {
      throw _handleError(e);
    }
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
