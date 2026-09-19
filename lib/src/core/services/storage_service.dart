import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../utils/authenticated_media.dart';
import '../../features/notifications/application/notification_permission_policy.dart';

/// Secure storage service for sensitive data (JWT tokens, etc.)
class StorageService implements NotificationPrimingStore {
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

    // Image and video widgets build synchronously and cannot await secure
    // storage, so they read a cached copy. Refreshing it here means a rotated
    // token reaches media requests immediately rather than at the next sign-in.
    await AuthenticatedMedia.refresh();
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: ApiConfig.accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: ApiConfig.accessTokenKey);
    AuthenticatedMedia.clear();
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

  // Notification permission priming
  //
  // How many times the explanation sheet has been shown, and when it last was.
  // Both are needed because the app re-raises the subject after a decline, and
  // "not too often" cannot be decided from a count alone.
  static const String _notificationAskCountKey = 'notification_primer_ask_count';
  static const String _notificationLastAskedKey = 'notification_primer_last_asked_at';

  @override
  Future<int> getNotificationAskCount() async {
    final value = await _storage.read(key: _notificationAskCountKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  @override
  Future<DateTime?> getNotificationLastAskedAt() async {
    final value = await _storage.read(key: _notificationLastAskedKey);
    final ms = int.tryParse(value ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> recordNotificationAsked(int count, DateTime at) async {
    await _storage.write(key: _notificationAskCountKey, value: count.toString());
    await _storage.write(
      key: _notificationLastAskedKey,
      value: at.millisecondsSinceEpoch.toString(),
    );
  }

  /// Forgets the priming history.
  ///
  /// Called on sign-out: these record one person's answers, and whoever signs in
  /// next has not answered anything.
  @override
  Future<void> clearNotificationPriming() async {
    await _storage.delete(key: _notificationAskCountKey);
    await _storage.delete(key: _notificationLastAskedKey);
  }

  // Terms & Conditions / Privacy Policy (legal agreement acceptance)
  //
  // Bump this whenever privacy.md or terms.md change materially. Users who
  // accepted an older version (or never had a version recorded) are re-prompted
  // with the legal agreement screen on their next launch.
  //
  // v2 (2026-07-10): privacy policy updated to disclose AdMob advertising and
  //   sharing of the Advertising ID / device identifiers with Google.
  // v3 (2026-07-17): terms updated for the public template gallery - what publishing
  //   means, no tolerance for objectionable content, and how to report or block.
  static const int currentLegalVersion = 3;

  static const String _acceptedLegalVersionKey = 'accepted_legal_version';

  /// Records that the user accepted the current legal documents.
  Future<void> setTermsAccepted() async {
    await _storage.write(
      key: _acceptedLegalVersionKey,
      value: currentLegalVersion.toString(),
    );
  }

  /// Returns true only if the user has accepted the current (or a newer) legal
  /// version. A missing or stale acceptance returns false so the agreement
  /// screen is shown again after the documents change.
  Future<bool> hasAcceptedTerms() async {
    final value = await _storage.read(key: _acceptedLegalVersionKey);
    final acceptedVersion = int.tryParse(value ?? '') ?? 0;
    return acceptedVersion >= currentLegalVersion;
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

  // Cached User Data (for offline auth)
  Future<void> saveUserData(String userJson) async {
    await _storage.write(key: ApiConfig.cachedUserDataKey, value: userJson);
  }

  Future<String?> getCachedUserData() async {
    return await _storage.read(key: ApiConfig.cachedUserDataKey);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: ApiConfig.cachedUserDataKey);
  }

  // Clear all auth data (logout) - preserves intro/onboarding state
  Future<void> clearAuthData() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await deleteUserId();
    await _storage.delete(key: ApiConfig.accessTokenExpiryKey);
    await deleteUserData();

    // The priming counters record one person's answers about notifications.
    // Whoever signs in next has not answered anything, and inheriting a
    // "already asked three times, stop asking" state from the previous account
    // would silently deny them the prompt for good.
    await clearNotificationPriming();
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

  // Walkthrough flags
  static const String _walkthroughDashboardKey = 'walkthrough_dashboard_completed';
  static const String _walkthroughTripDetailKey = 'walkthrough_trip_detail_completed';
  static const String _walkthroughTripCreationKey = 'walkthrough_trip_creation_completed';

  Future<void> setDashboardWalkthroughCompleted(bool completed) async {
    await _storage.write(key: _walkthroughDashboardKey, value: completed.toString());
  }

  Future<bool> isDashboardWalkthroughCompleted() async {
    final value = await _storage.read(key: _walkthroughDashboardKey);
    return value == 'true';
  }

  Future<void> setTripDetailWalkthroughCompleted(bool completed) async {
    await _storage.write(key: _walkthroughTripDetailKey, value: completed.toString());
  }

  Future<bool> isTripDetailWalkthroughCompleted() async {
    final value = await _storage.read(key: _walkthroughTripDetailKey);
    return value == 'true';
  }

  Future<void> setTripCreationWalkthroughCompleted(bool completed) async {
    await _storage.write(key: _walkthroughTripCreationKey, value: completed.toString());
  }

  Future<bool> isTripCreationWalkthroughCompleted() async {
    final value = await _storage.read(key: _walkthroughTripCreationKey);
    return value == 'true';
  }

  Future<void> resetAllWalkthroughs() async {
    await _storage.delete(key: _walkthroughDashboardKey);
    await _storage.delete(key: _walkthroughTripDetailKey);
    await _storage.delete(key: _walkthroughTripCreationKey);
  }

  // Theme Mode
  static const String _themeModeKey = 'theme_mode';
  static const String _legacyThemeModeKey = 'theme_mode_dark';

  Future<void> setThemeModeValue(String mode) async {
    await _storage.write(key: _themeModeKey, value: mode); // 'light', 'dark', 'system'
  }

  Future<String> getThemeModeValue() async {
    final value = await _storage.read(key: _themeModeKey);
    if (value != null) return value;
    // Migrate from legacy bool key
    final legacy = await _storage.read(key: _legacyThemeModeKey);
    if (legacy == 'true') return 'dark';
    return 'light';
  }

  @Deprecated('Use setThemeModeValue instead')
  Future<void> setThemeMode(bool isDark) async {
    await setThemeModeValue(isDark ? 'dark' : 'light');
  }

  @Deprecated('Use getThemeModeValue instead')
  Future<bool> getThemeMode() async {
    final value = await getThemeModeValue();
    return value == 'dark';
  }

  // Temporary feature unlocks (free users who watched a rewarded ad).
  // Stored as an expiry timestamp per feature key; the unlock is valid while
  // now < expiry. Mirrors the access-token-expiry storage pattern above.
  static String _featureUnlockKey(String featureKey) =>
      'feature_unlock_$featureKey';

  Future<void> saveFeatureUnlockExpiry(
    String featureKey,
    DateTime expiry,
  ) async {
    await _storage.write(
      key: _featureUnlockKey(featureKey),
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  Future<DateTime?> getFeatureUnlockExpiry(String featureKey) async {
    final value = await _storage.read(key: _featureUnlockKey(featureKey));
    if (value == null) return null;
    final millis = int.tryParse(value);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Removes one temporary feature unlock.
  ///
  /// Used when the server reports a feature is no longer granted, so the cached
  /// copy cannot keep the gate open past the grant it was a copy of.
  Future<void> clearFeatureUnlock(String featureKey) async {
    await _storage.delete(key: _featureUnlockKey(featureKey));
  }

  /// Removes every temporary feature unlock.
  ///
  /// An unlock is earned by a person, not by a device: leaving them behind let
  /// the next account to sign in inherit premium features it never earned.
  Future<void> clearFeatureUnlocks() async {
    for (final key in featureUnlockKeys) {
      await _storage.delete(key: _featureUnlockKey(key));
    }
  }

  /// Feature keys that can carry a temporary unlock.
  ///
  /// Kept here rather than derived from the subscription feature enum so core
  /// storage does not depend on a feature module.
  /// Must stay in step with `PremiumFeature.storageKey`.
  static const List<String> featureUnlockKeys = [
    'world_map',
    'full_statistics',
    'video_upload',
    'edit_sharing',
    'year_in_review',
  ];

  // First-launch timestamp — drives the new-user ad grace period.
  static const String _firstLaunchKey = 'first_launch_at';

  /// Returns when this install first ran, recording "now" the first time it's
  /// called. Idempotent: every later call returns the originally-stored value,
  /// so the grace-period clock starts once and never resets mid-life.
  ///
  /// A reinstall legitimately starts the clock again — a returning user who
  /// wiped the app is deciding about it afresh.
  Future<DateTime> ensureFirstLaunchAt() async {
    final existing = await _storage.read(key: _firstLaunchKey);
    final millis = existing == null ? null : int.tryParse(existing);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);

    final now = DateTime.now();
    await _storage.write(
      key: _firstLaunchKey,
      value: now.millisecondsSinceEpoch.toString(),
    );
    return now;
  }

  // In-app purchases — delivered receipts and the verification retry queue.
  //
  // `getAvailablePurchases` returns every owned item on every resume, so delivery
  // has to be deduped by a persisted set of purchase identities. The queue holds
  // receipts the backend could not answer for; they are replayed until it does.
  static const String _deliveredPurchasesKey = 'delivered_purchase_ids';
  static const String _pendingVerificationsKey = 'pending_purchase_verifications';
  static const int _maxDeliveredPurchaseIds = 200;

  Future<Set<String>> getDeliveredPurchaseIds() async {
    final raw = await _storage.read(key: _deliveredPurchasesKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((e) => e.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Records [purchaseId] as delivered, keeping the most recent
  /// [_maxDeliveredPurchaseIds] entries so the value cannot grow without bound.
  Future<void> addDeliveredPurchaseId(String purchaseId) async {
    final existing = await getDeliveredPurchaseIds();
    if (existing.contains(purchaseId)) return;

    final updated = [...existing, purchaseId];
    final trimmed = updated.length > _maxDeliveredPurchaseIds
        ? updated.sublist(updated.length - _maxDeliveredPurchaseIds)
        : updated;

    await _storage.write(
      key: _deliveredPurchasesKey,
      value: jsonEncode(trimmed),
    );
  }

  Future<void> clearDeliveredPurchaseIds() async {
    await _storage.delete(key: _deliveredPurchasesKey);
  }

  /// Receipts awaiting a backend verdict, oldest first. Keys are the same ones
  /// the pre-OpenIAP client used (`product_id`, `transaction_id`, `platform`,
  /// `receipt_data`, `purchase_token`), so entries persisted by the old plugin
  /// still parse after the upgrade.
  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    final raw = await _storage.read(key: _pendingVerificationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingVerifications(
    List<Map<String, dynamic>> pending,
  ) async {
    if (pending.isEmpty) {
      await _storage.delete(key: _pendingVerificationsKey);
      return;
    }
    await _storage.write(
      key: _pendingVerificationsKey,
      value: jsonEncode(pending),
    );
  }
  // ============================================================
  // ACTIVITY TICK-OFF
  // ============================================================
  //
  // Screen 3f makes every activity card tickable. The server's ActivityDto
  // carries no completion flag, so the state lives on the device: a tick does
  // not sync between devices and does not survive a reinstall. Adding
  // IsCompleted to the DTO is what would fix that.
  //
  // Stored here rather than behind a new preferences dependency, since this is
  // already the app's key-value seam.

  static const String _activityDonePrefix = 'activity_done_';

  Future<Set<String>> getDoneActivities(String tripId) async {
    final raw = await _storage.read(key: '$_activityDonePrefix$tripId');
    if (raw == null || raw.isEmpty) return <String>{};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  Future<void> setDoneActivities(String tripId, Set<String> ids) async {
    final key = '$_activityDonePrefix$tripId';
    if (ids.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: jsonEncode(ids.toList()));
  }

}
