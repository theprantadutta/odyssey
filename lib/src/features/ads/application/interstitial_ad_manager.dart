import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../ad_constants.dart';
import 'full_screen_ad_lock.dart';

/// Loads and shows interstitial (full-screen) ads, with an aggressive-but-safe
/// cadence: one every Nth navigation, never more often than the cooldown, and
/// never stacked on top of an app-open ad (via [FullScreenAdLock]).
///
/// Free users only — the owning provider toggles [enabled] off for premium
/// users, which disposes any cached ad and stops all loading.
class InterstitialAdManager {
  InterstitialAdManager({this.onRevenue});

  /// Reports AdMob paid events (micros, currency, precision) for analytics.
  final void Function(double valueMicros, String currency, int precision)?
      onRevenue;

  InterstitialAd? _ad;
  bool _isLoading = false;
  bool _enabled = false;
  int _navCount = 0;
  int _shownThisSession = 0;
  DateTime? _lastShownAt;
  Timer? _showTimer;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  /// Turn the manager on/off. Off => dispose cached ad and reset counters.
  ///
  /// Forced off when [AdConstants.interstitialEnabled] is false, so a disabled
  /// format can never be switched on by a caller — every other code path already
  /// short-circuits on [_enabled], which makes this the single choke point.
  void setEnabled(bool enabled) {
    enabled = enabled && AdConstants.interstitialEnabled;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _preload();
    } else {
      _navCount = 0;
      _shownThisSession = 0;
      _cancelPendingShow();
      _disposeAd();
    }
  }

  /// Call on every qualifying route push (the observer filters out task flows
  /// and modal pages). Shows an ad every Nth navigation, until the per-session
  /// cap is reached.
  void onNavigation() {
    if (!_enabled || !AdMobConfig.isSupportedPlatform) return;
    // Session cap reached: stop counting and stop preloading so we don't burn
    // ad requests we'll never show.
    if (_shownThisSession >= AdConstants.interstitialMaxPerSession) return;
    _navCount++;
    if (_navCount % AdConstants.interstitialEveryNNavigations != 0) {
      // Keep one warm for the next trigger.
      _preload();
      return;
    }

    // Wait for the incoming route's transition to settle before covering it.
    // Showing straight out of `didPush` drops the ad on top of a screen that is
    // still animating in, which reads as a glitch rather than an ad break.
    _cancelPendingShow();
    _showTimer = Timer(AdConstants.interstitialShowDelay, () {
      _showTimer = null;
      _showIfReady();
    });
  }

  void _cancelPendingShow() {
    _showTimer?.cancel();
    _showTimer = null;
  }

  void _preload() {
    if (!_enabled ||
        _isLoading ||
        _ad != null ||
        !AdMobConfig.isSupportedPlatform) {
      return;
    }
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialAdUnitId,
      request: _request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          if (!_enabled) {
            ad.dispose();
            return;
          }
          ad.onPaidEvent = (_, valueMicros, precision, currencyCode) =>
              onRevenue?.call(valueMicros, currencyCode, precision.index);
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          AppLogger.debug('Interstitial failed to load: ${error.message}');
        },
      ),
    );
  }

  void _showIfReady() {
    // The timer may outlive a premium upgrade or a consent revocation.
    if (!_enabled) return;

    final ad = _ad;
    if (ad == null) {
      _preload();
      return;
    }

    if (_shownThisSession >= AdConstants.interstitialMaxPerSession) return;

    final last = _lastShownAt;
    final cooledDown = last == null ||
        DateTime.now().difference(last) >= AdConstants.interstitialCooldown;
    if (!cooledDown || !FullScreenAdLock.instance.canShowFullScreenAd) {
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => FullScreenAdLock.instance.markShowing(),
      onAdDismissedFullScreenContent: (ad) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        _preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        AppLogger.debug('Interstitial failed to show: ${error.message}');
        _preload();
      },
    );

    _ad = null;
    _lastShownAt = DateTime.now();
    _shownThisSession++;
    ad.show();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
  }

  void dispose() {
    _cancelPendingShow();
    _disposeAd();
  }
}
