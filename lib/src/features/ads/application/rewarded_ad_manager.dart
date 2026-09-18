import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../ad_constants.dart';
import 'full_screen_ad_lock.dart';

/// Loads and shows user-initiated Rewarded ads ("watch an ad to unlock X").
///
/// Unlike the other formats this one is only ever triggered by an explicit user
/// action, so there's no frequency cap — but it still respects
/// [FullScreenAdLock] so it can't collide with an app-open/interstitial.
class RewardedAdManager {
  RewardedAdManager({this.onRevenue});

  /// Reports AdMob paid events (micros, currency, precision) for analytics.
  final void Function(double valueMicros, String currency, int precision)?
      onRevenue;

  RewardedAd? _ad;
  bool _isLoading = false;
  bool _enabled = false;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  /// Warm up an ad ahead of a likely user action (e.g. opening a paywall that
  /// offers a watch-to-unlock option). No-op if disabled or already ready.
  void preload() => _preload();

  /// Forced off when [AdConstants.rewardedEnabled] is false. Every other path
  /// short-circuits on [_enabled], so this is the single choke point.
  void setEnabled(bool enabled) {
    enabled = enabled && AdConstants.rewardedEnabled;
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _preload();
    } else {
      _disposeAd();
    }
  }

  /// Whether an ad is loaded and ready to show right now.
  bool get isReady => _ad != null;

  void _preload() {
    if (!_enabled ||
        _isLoading ||
        _ad != null ||
        !AdMobConfig.isSupportedPlatform) {
      return;
    }
    _isLoading = true;
    RewardedAd.load(
      adUnitId: AdMobConfig.rewardedAdUnitId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
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
          AppLogger.debug('Rewarded ad failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Shows the rewarded ad. Returns `true` if the user earned the reward,
  /// `false` if no ad was available, it couldn't show, or it was dismissed
  /// before completion. Triggers a preload of the next ad afterwards.
  ///
  /// [intentId] identifies an offer the **server** already recorded for this
  /// account and feature. It is the only thing that decides what the reward is
  /// worth: the server reads the account, the feature and the permitted ad unit
  /// from its own row, so nothing this device puts in the callback can change
  /// them. [userId] travels alongside it for the network's own reporting.
  ///
  /// Returning `true` means the *ad* completed, not that the feature is unlocked:
  /// the reward reaches the server through the ad network, so the caller still
  /// has to wait for the grant to appear.
  Future<bool> showRewarded({
    required String userId,
    required String intentId,
  }) async {
    if (!_enabled || !AdMobConfig.isSupportedPlatform) return false;
    final ad = _ad;
    if (ad == null) {
      _preload(); // warm one up for next time
      return false;
    }
    if (!FullScreenAdLock.instance.canShowFullScreenAd) return false;

    // Set immediately before showing, not at load time: a preloaded ad may have
    // been warmed up before sign-in, or for a different feature than the one the
    // user eventually taps.
    ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId, customData: intentId),
    );

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => FullScreenAdLock.instance.markShowing(),
      onAdDismissedFullScreenContent: (ad) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        _preload();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        FullScreenAdLock.instance.markDismissed();
        ad.dispose();
        AppLogger.debug('Rewarded ad failed to show: ${error.message}');
        _preload();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _ad = null;
    ad.show(
      onUserEarnedReward: (_, RewardItem reward) {
        earned = true;
        AppLogger.info('Rewarded ad: user earned ${reward.amount} ${reward.type}');
      },
    );

    return completer.future;
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
  }

  void dispose() => _disposeAd();
}
