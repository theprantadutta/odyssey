import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Secure storage service for sensitive data (JWT tokens, etc.)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Access Token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: ApiConfig.accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: ApiConfig.accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: ApiConfig.accessTokenKey);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: ApiConfig.refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: ApiConfig.refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: ApiConfig.refreshTokenKey);
  }

  // Access Token Expiry
  Future<void> saveAccessTokenExpiry(DateTime expiry) async {
    await _storage.write(
      key: ApiConfig.accessTokenExpiryKey,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  Future<DateTime?> getAccessTokenExpiry() async {
    final value = await _storage.read(key: ApiConfig.accessTokenExpiryKey);
    if (value == null) return null;
    final millis = int.tryParse(value);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<bool> isAccessTokenExpired() async {
    final expiry = await getAccessTokenExpiry();
    if (expiry == null) return true;
    // Consider expired if less than 60 seconds remaining (buffer for network latency)
    return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));
  }

  // User ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: ApiConfig.userIdKey, value: userId);
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: ApiConfig.userIdKey);
  }

  Future<void> deleteUserId() async {
    await _storage.delete(key: ApiConfig.userIdKey);
  }

  // Intro (first-time app launch)
  static const String _introSeenKey = 'intro_seen';

  Future<void> setIntroSeen(bool seen) async {
    await _storage.write(key: _introSeenKey, value: seen.toString());
  }

  Future<bool> hasSeenIntro() async {
    final value = await _storage.read(key: _introSeenKey);
    return value == 'true';
  }

  // Onboarding (post-authentication)
  Future<void> setOnboardingCompleted(bool completed) async {
    await _storage.write(
      key: ApiConfig.onboardingCompletedKey,
      value: completed.toString(),
    );
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: ApiConfig.onboardingCompletedKey);
    return value == 'true';
  }

  // Clear all auth data (logout) - preserves intro/onboarding state
  Future<void> clearAuthData() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await deleteUserId();
    await _storage.delete(key: ApiConfig.accessTokenExpiryKey);
  }

  // Clear all data (full reset)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Theme Mode
  static const String _themeModeKey = 'theme_mode_dark';

  Future<void> setThemeMode(bool isDark) async {
    await _storage.write(key: _themeModeKey, value: isDark.toString());
  }

  Future<bool> getThemeMode() async {
    final value = await _storage.read(key: _themeModeKey);
    return value == 'true';
  }
}
