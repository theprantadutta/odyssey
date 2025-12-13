import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration for Odyssey Backend
class ApiConfig {
  ApiConfig._(); // Private constructor

  // Base URL - Automatically selects based on build mode
  static String get baseUrl {
    if (kReleaseMode) {
      return dotenv.env['PROD_URL'] ?? 'https://odyssey.pranta.dev';
    }
    return dotenv.env['DEV_URL'] ?? 'http://localhost:8546';
  }

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
  static const String expenses = '/expenses';
  static const String packing = '/packing';
  static const String documents = '/documents';
  static const String sharing = '/share';
  static const String templates = '/templates';
  static const String seed = '/seed';

  // Sharing endpoints
  static const String sharedWithMe = '$trips/shared-with-me';
  static String tripShares(String tripId) => '$trips/$tripId/shares';
  static String shareTrip(String tripId) => '$trips/$tripId/share';
  static String inviteDetails(String code) => '$sharing/invite/$code';
  static String acceptInvite(String code) => '$sharing/accept/$code';
  static String declineInvite(String code) => '$sharing/decline/$code';

  // Template endpoints
  static const String publicTemplates = '$templates/public';
  static const String templateFromTrip = '$templates/from-trip';
  static String templateDetail(String id) => '$templates/$id';
  static String useTemplate(String id) => '$templates/use/$id';

  // Auth endpoints
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String me = '$auth/me';
  static const String logout = '$auth/logout';

  // Trip endpoints
  static const String defaultTrips = '$trips/default-trips';

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
  static const String onboardingCompletedKey = 'onboarding_completed';
}
