/// API Configuration for Odyssey Backend
class ApiConfig {
  ApiConfig._(); // Private constructor

  // Base URL - Update this for production
  static const String baseUrl = 'http://localhost:8546';

  // API Version
  static const String apiVersion = 'v1';

  // Base API path
  static const String basePath = '/api/$apiVersion';

  // Full base URL
  static String get fullBaseUrl => '$baseUrl$basePath';

  // Endpoints
  static const String auth = '/auth';
  static const String trips = '/trips';
  static const String activities = '/activities';
  static const String memories = '/memories';
  static const String seed = '/seed';

  // Auth endpoints
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String me = '$auth/me';
  static const String logout = '$auth/logout';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Headers
  static const String contentTypeJson = 'application/json';
  static const String contentTypeMultipart = 'multipart/form-data';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String userIdKey = 'user_id';
}
