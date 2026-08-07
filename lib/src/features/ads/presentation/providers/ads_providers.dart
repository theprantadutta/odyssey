import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/admob_config.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../ad_constants.dart';
import '../../application/ad_consent_service.dart';
import '../../application/app_open_ad_manager.dart';
import '../../application/interstitial_ad_manager.dart';
import '../../application/rewarded_ad_manager.dart';

part 'ads_providers.g.dart';

/// Builds an [onRevenue] callback that forwards AdMob paid events to analytics,
/// tagged with the ad [format]. Shared by every full-screen ad manager.
void Function(double, String, int) _revenueReporter(Ref ref, String format) {
  return (double valueMicros, String currency, int precision) {
    ref.read(analyticsServiceProvider).trackAdRevenue(
          format: format,
          valueMicros: valueMicros,
          currency: currency,
          precision: precision,
        );
  };
}

/// Runs the UMP consent flow once and exposes whether the SDK may request ads.
/// Resolves to `true` immediately for users whose region doesn't require a
/// consent form; for EEA/UK users it resolves after they answer the form.
@Riverpod(keepAlive: true)
Future<bool> adConsent(Ref ref) async {
  if (!AdMobConfig.isSupportedPlatform) return false;
  return AdConsentService.instance.gather();
}

/// Resolves to `true` once [AdConstants.newUserGracePeriod] has elapsed since
/// this install's first launch.
///
/// Until it resolves, callers treat it as `false` (grace still active), so a
/// slow storage read can only ever suppress ads — never surface them early.
@Riverpod(keepAlive: true)
Future<bool> adGracePeriodElapsed(Ref ref) async {
  if (!AdMobConfig.isSupportedPlatform) return false;
  final firstLaunch = await StorageService().ensureFirstLaunchAt();
  return DateTime.now().difference(firstLaunch) >=
      AdConstants.newUserGracePeriod;
}

/// THE master gate for every *passive* ad surface in the app.
///
/// Ads show only when ALL of these hold:
///  * the platform supports AdMob (Android/iOS),
///  * the user is NOT premium (reuses the existing [isPremiumProvider]),
///  * ad consent has been resolved/obtained,
///  * the new-user grace period has elapsed.
///
/// The moment a user upgrades, [isPremiumProvider] flips and this recomputes to
/// `false` — every banner collapses and every manager is disabled, reactively.
///
/// Rewarded ads deliberately do NOT use this gate; see [rewardedAdsEnabled].
@Riverpod(keepAlive: true)
bool adsEnabled(Ref ref) {
  if (!AdMobConfig.isSupportedPlatform) return false;
  final isPremium = ref.watch(isPremiumProvider);
  final consentReady = ref.watch(adConsentProvider).value ?? false;
  final graceElapsed = ref.watch(adGracePeriodElapsedProvider).value ?? false;
  return !isPremium && consentReady && graceElapsed;
}

/// Gate for the anchored bottom banner. [adsEnabled] plus the format switch.
@Riverpod(keepAlive: true)
bool bannerAdsEnabled(Ref ref) =>
    AdConstants.bannerEnabled && ref.watch(adsEnabledProvider);

/// Gate for inline native list tiles. [adsEnabled] plus the format switch.
@Riverpod(keepAlive: true)
bool nativeAdsEnabled(Ref ref) =>
    AdConstants.nativeEnabled && ref.watch(adsEnabledProvider);

/// Gate for user-initiated rewarded ads.
///
/// Intentionally NOT built on [adsEnabled]: rewarded ads are exempt from the
/// new-user grace period. They're opt-in, and they hand a free user 24h of a
/// premium feature — during onboarding that's a trial, not an interruption.
@Riverpod(keepAlive: true)
bool rewardedAdsEnabled(Ref ref) {
  if (!AdMobConfig.isSupportedPlatform) return false;
  if (!AdConstants.rewardedEnabled) return false;
  final isPremium = ref.watch(isPremiumProvider);
  final consentReady = ref.watch(adConsentProvider).value ?? false;
  return !isPremium && consentReady;
}

/// Interstitial manager, kept in sync with [adsEnabled] and the format switch.
@Riverpod(keepAlive: true)
InterstitialAdManager interstitialAdManager(Ref ref) {
  final manager =
      InterstitialAdManager(onRevenue: _revenueReporter(ref, 'interstitial'));
  ref.onDispose(manager.dispose);
  ref.listen(
    adsEnabledProvider,
    (_, enabled) =>
        manager.setEnabled(AdConstants.interstitialEnabled && enabled),
    fireImmediately: true,
  );
  return manager;
}

/// App-open manager. Observes the app lifecycle for the whole session.
@Riverpod(keepAlive: true)
AppOpenAdManager appOpenAdManager(Ref ref) {
  final manager =
      AppOpenAdManager(onRevenue: _revenueReporter(ref, 'app_open'))..start();
  ref.onDispose(manager.stop);
  ref.listen(
    adsEnabledProvider,
    (_, enabled) => manager.setEnabled(AdConstants.appOpenEnabled && enabled),
    fireImmediately: true,
  );
  return manager;
}

/// Rewarded manager for user-initiated "watch an ad to unlock" flows.
@Riverpod(keepAlive: true)
RewardedAdManager rewardedAdManager(Ref ref) {
  final manager = RewardedAdManager(onRevenue: _revenueReporter(ref, 'rewarded'));
  ref.onDispose(manager.dispose);
  ref.listen(
    rewardedAdsEnabledProvider,
    (_, enabled) => manager.setEnabled(enabled),
    fireImmediately: true,
  );
  return manager;
}
