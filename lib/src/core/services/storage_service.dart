import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Secure storage service for sensitive data (JWT tokens, etc.)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
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

  // Clear all data (logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
