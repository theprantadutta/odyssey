import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../ad_constants.dart';
import 'full_screen_ad_lock.dart';

/// Loads and shows App Open ads.
///
/// Shows an ad when the user *returns* to the app after being away for at least
/// [AdConstants.appOpenMinBackgroundDuration], plus once shortly after the
/// manager is first enabled (a "cold start" ad — but note this only happens
/// after the user is past splash/auth, since ads are only enabled for an
/// authenticated free user, so we never show over the launch screen).
///
/// Observes the app lifecycle directly via [WidgetsBindingObserver]. Free users
/// only — the owning provider toggles [enabled].
class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAd? _ad;
  bool _isLoading = false;
  bool _enabled = false;
  bool _started = false;
  bool _showOnNextLoad = false;
  DateTime? _loadedAt;
  DateTime? _backgroundedAt;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  /// Begin observing the app lifecycle. Call once at app start.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop observing and release resources.
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _disposeAd();
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      // Try to surface an ad shortly after enabling (cold-start-ish), once one
      // is loaded and nothing else is on screen.
      _showOnNextLoad = true;
      _load();
    } else {
      _showOnNextLoad = false;
      _disposeAd();
    }
  }

  bool get _isAdAvailable {
    final loadedAt = _loadedAt;
    if (_ad == null || loadedAt == null) return false;
    return DateTime.now().difference(loadedAt) < AdConstants.appOpenAdMaxCacheAge;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        _maybeShowOnResume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _maybeShowOnResume() {
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return; // never left, nothing to do
    final awayFor = DateTime.now().difference(backgroundedAt);
    _backgroundedAt = null;
    if (awayFor < AdConstants.appOpenMinBackgroundDuration) return;
    _showIfAvailable();
  }

  void _load() {
    if (!_enabled ||
        _isLoading ||
        _ad != null ||
        !AdMobConfig.isSupportedPlatform) {
      return;
    }
    _isLoading = true;
    AppOpenAd.load(
      adUnitId: AdMobConfig.appOpenAdUnitId,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          if (!_enabled) {
            ad.dispose();
            return;
          }
          _ad = ad;
          _loadedAt = DateTime.now();
          if (_showOnNextLoad) {
            _showOnNextLoad = false;
            _showIfAvailable();
          }
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          AppLogger.debug('App open ad failed to load: ${error.message}');
        },
      ),
    );
  }

  void _showIfAvailable() {
    if (!_enabled || FullScreenAdLock.instance.isShowing) return;
    if (!_isAdAvailable) {
      _load();
      return;
    }
    if (!FullScreenAdLock.instance.canShowFullScreenAd) return;

    final ad = _ad!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => FullScreenAdLock.instance.markShowing(),
      onAdDismissedFullScreenContent: (ad) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        _load(); // preload the next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        AppLogger.debug('App open ad failed to show: ${error.message}');
        _load();
      },
    );

    _ad = null;
    _loadedAt = null;
    ad.show();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }
}
