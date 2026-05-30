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
  InterstitialAd? _ad;
  bool _isLoading = false;
  bool _enabled = false;
  int _navCount = 0;
  DateTime? _lastShownAt;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  /// Turn the manager on/off. Off => dispose cached ad and reset counters.
  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _preload();
    } else {
      _navCount = 0;
      _disposeAd();
    }
  }

  /// Call on every route push. Shows an ad every Nth qualifying navigation.
  void onNavigation() {
    if (!_enabled || !AdMobConfig.isSupportedPlatform) return;
    _navCount++;
    if (_navCount % AdConstants.interstitialEveryNNavigations != 0) {
      // Keep one warm for the next trigger.
      _preload();
      return;
    }
    _showIfReady();
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
    final ad = _ad;
    if (ad == null) {
      _preload();
      return;
    }

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
    ad.show();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
  }

  void dispose() => _disposeAd();
}
