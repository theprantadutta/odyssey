import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../ad_constants.dart';
import 'full_screen_ad_lock.dart';

/// Loads and shows App Open ads.
///
/// Shows an ad only when the user *returns* to the app after being away for at
/// least [AdConstants.appOpenMinBackgroundDuration]. We deliberately do NOT show
/// a "cold start" ad right after the manager is enabled: that fires immediately
/// after login while the user is trying to use the app, which is jarring and
/// borderline against AdMob's app-open policy. Enabling only preloads; the first
/// impression happens on a genuine resume from background.
///
/// Observes the app lifecycle directly via [WidgetsBindingObserver]. Free users
/// only — the owning provider toggles [enabled].
class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAdManager({this.onRevenue});

  /// Reports AdMob paid events (micros, currency, precision) for analytics.
  final void Function(double valueMicros, String currency, int precision)?
      onRevenue;

  AppOpenAd? _ad;
  bool _isLoading = false;
  bool _enabled = false;
  bool _started = false;
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
      // Only warm one up; the first impression waits for a genuine resume.
      _load();
    } else {
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
          ad.onPaidEvent = (_, valueMicros, precision, currencyCode) =>
              onRevenue?.call(valueMicros, currencyCode, precision.index);
          _ad = ad;
          _loadedAt = DateTime.now();
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
