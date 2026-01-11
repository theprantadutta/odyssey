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

  // Weather endpoints
  static const String weather = '/weather';
  static const String weatherCurrent = '$weather/current';
  static const String weatherForecast = '$weather/forecast';
  static String weatherTrip(String tripId) => '$weather/trip/$tripId';

  // Currency endpoints
  static const String currency = '/currency';
  static const String currencyRates = '$currency/rates';
  static const String currencyConvert = '$currency/convert';
  static const String currencyBulkConvert = '$currency/bulk-convert';
  static const String currencySupported = '$currency/supported';

  // Achievements endpoints
  static const String achievements = '/achievements';
  static const String achievementsMe = '$achievements/me';
  static const String achievementsCheck = '$achievements/check';
  static const String achievementsUnseen = '$achievements/unseen';
  static const String achievementsLeaderboard = '$achievements/leaderboard';
  static String achievementSeen(String id) => '$achievements/$id/seen';

  // Statistics endpoints
  static const String statistics = '/statistics';
  static const String statisticsYearInReview = '$statistics/year-in-review';
  static const String statisticsTimeline = '$statistics/timeline';

  // Auth endpoints
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String me = '$auth/me';
  static const String logout = '$auth/logout';
  static const String refresh = '$auth/refresh';
  static const String logoutAll = '$auth/logout-all';

  // Google Auth endpoints
  static const String googleAuth = '$auth/google';
  static const String firebaseAuth = '$auth/firebase';
  static const String linkGoogle = '$auth/link-google';
  static const String autoLinkGoogle = '$auth/auto-link-google';
  static const String unlinkGoogle = '$auth/unlink-google';
  static const String authProviders = '$auth/providers';

  // Device endpoints (push notifications)
  static const String devices = '/devices';
  static const String deviceRegister = '$devices/register';
  static String deviceUnregister(String token) => '$devices/$token';

  // Notification history endpoints
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '$notifications/unread-count';
  static const String notificationsReadAll = '$notifications/read-all';
  static String notificationMarkRead(String id) => '$notifications/$id/read';
  static String notificationDelete(String id) => '$notifications/$id';

  // Trip endpoints
  static const String defaultTrips = '$trips/default-trips';

  // Timeouts
  // Increased receive timeout to accommodate seeding demo images on first user setup
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(minutes: 2);
  static const Duration sendTimeout = Duration(seconds: 60);

  // Headers
  static const String contentTypeJson = 'application/json';
  static const String contentTypeMultipart = 'multipart/form-data';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String accessTokenExpiryKey = 'access_token_expiry';
  static const String userIdKey = 'user_id';
  static const String onboardingCompletedKey = 'onboarding_completed';
}
