import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/logger_service.dart';
import '../ad_constants.dart';

/// Fetches ad-cadence overrides from Firebase Remote Config and applies them to
/// the mutable defaults in [AdConstants].
///
/// This lets ad intensity be tuned live — A/B tested, or dialled back if users
/// complain — without shipping a new build. Every value is validated and
/// clamped to a sane range before it is applied, so a fat-fingered console entry
/// (e.g. `0`, which would divide by zero in the list/navigation math) can never
/// break the app. If the fetch fails (offline, timeout), the compiled-in
/// defaults in [AdConstants] are used unchanged.
///
/// Remote Config parameter keys (all integers; create these in the Firebase
/// console to override — omit any you want to leave at its default):
///   * ad_interstitial_every_n_navigations
///   * ad_interstitial_cooldown_seconds
///   * ad_interstitial_max_per_session
///   * ad_app_open_min_background_seconds
///   * ad_native_every_n_items
///   * ad_native_min_items_before_first
class RemoteAdConfig {
  RemoteAdConfig._();

  static const String _kInterstitialEveryN =
      'ad_interstitial_every_n_navigations';
  static const String _kInterstitialCooldownSec =
      'ad_interstitial_cooldown_seconds';
  static const String _kInterstitialMaxPerSession =
      'ad_interstitial_max_per_session';
  static const String _kAppOpenMinBackgroundSec =
      'ad_app_open_min_background_seconds';
  static const String _kNativeEveryN = 'ad_native_every_n_items';
  static const String _kNativeMinBeforeFirst = 'ad_native_min_items_before_first';

  /// Best-effort: fetches and applies remote overrides. Never throws — any
  /// failure just leaves the [AdConstants] defaults in place.
  static Future<void> initialize() async {
    try {
      final rc = FirebaseRemoteConfig.instance;

      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // In debug we want to see console changes immediately; in production a
        // 6h cache keeps fetches cheap and avoids hammering the backend.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 6),
      ));

      // Seed defaults from the compiled-in values so the keys always exist.
      await rc.setDefaults(<String, dynamic>{
        _kInterstitialEveryN: AdConstants.interstitialEveryNNavigations,
        _kInterstitialCooldownSec: AdConstants.interstitialCooldown.inSeconds,
        _kInterstitialMaxPerSession: AdConstants.interstitialMaxPerSession,
        _kAppOpenMinBackgroundSec:
            AdConstants.appOpenMinBackgroundDuration.inSeconds,
        _kNativeEveryN: AdConstants.nativeAdEveryNItems,
        _kNativeMinBeforeFirst: AdConstants.nativeAdMinItemsBeforeFirst,
      });

      await rc.fetchAndActivate();
      _apply(rc);
      AppLogger.info('Remote ad config applied');
    } catch (e) {
      // Offline / timeout / not configured — keep the safe defaults.
      AppLogger.debug('Remote ad config unavailable, using defaults: $e');
    }
  }

  static void _apply(FirebaseRemoteConfig rc) {
    // `every N` values are divisors in the cadence math — must be >= 1.
    AdConstants.interstitialEveryNNavigations =
        rc.getInt(_kInterstitialEveryN).clamp(1, 100);
    AdConstants.nativeAdEveryNItems = rc.getInt(_kNativeEveryN).clamp(1, 100);

    // Cooldown / background thresholds: seconds, non-negative, capped at 1h/1d.
    AdConstants.interstitialCooldown =
        Duration(seconds: rc.getInt(_kInterstitialCooldownSec).clamp(0, 3600));
    AdConstants.appOpenMinBackgroundDuration = Duration(
        seconds: rc.getInt(_kAppOpenMinBackgroundSec).clamp(0, 86400));

    // Counts: 0 is valid (0 max-per-session effectively disables interstitials).
    AdConstants.interstitialMaxPerSession =
        rc.getInt(_kInterstitialMaxPerSession).clamp(0, 100);
    AdConstants.nativeAdMinItemsBeforeFirst =
        rc.getInt(_kNativeMinBeforeFirst).clamp(0, 1000);
  }
}
