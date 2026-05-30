import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/admob_config.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../application/ad_consent_service.dart';
import '../../application/app_open_ad_manager.dart';
import '../../application/interstitial_ad_manager.dart';
import '../../application/rewarded_ad_manager.dart';

part 'ads_providers.g.dart';

/// Runs the UMP consent flow once and exposes whether the SDK may request ads.
/// Resolves to `true` immediately for users whose region doesn't require a
/// consent form; for EEA/UK users it resolves after they answer the form.
@Riverpod(keepAlive: true)
Future<bool> adConsent(Ref ref) async {
  if (!AdMobConfig.isSupportedPlatform) return false;
  return AdConsentService.instance.gather();
}

/// THE master gate for every ad surface in the app.
///
/// Ads show only when ALL of these hold:
///  * the platform supports AdMob (Android/iOS),
///  * the user is NOT premium (reuses the existing [isPremiumProvider]),
///  * ad consent has been resolved/obtained.
///
/// The moment a user upgrades, [isPremiumProvider] flips and this recomputes to
/// `false` — every banner collapses and every manager is disabled, reactively.
@Riverpod(keepAlive: true)
bool adsEnabled(Ref ref) {
  if (!AdMobConfig.isSupportedPlatform) return false;
  final isPremium = ref.watch(isPremiumProvider);
  final consentReady = ref.watch(adConsentProvider).value ?? false;
  return !isPremium && consentReady;
}

/// Interstitial manager, kept in sync with [adsEnabled].
@Riverpod(keepAlive: true)
InterstitialAdManager interstitialAdManager(Ref ref) {
  final manager = InterstitialAdManager();
  ref.onDispose(manager.dispose);
  ref.listen(
    adsEnabledProvider,
    (_, enabled) => manager.setEnabled(enabled),
    fireImmediately: true,
  );
  return manager;
}

/// App-open manager. Observes the app lifecycle for the whole session.
@Riverpod(keepAlive: true)
AppOpenAdManager appOpenAdManager(Ref ref) {
  final manager = AppOpenAdManager()..start();
  ref.onDispose(manager.stop);
  ref.listen(
    adsEnabledProvider,
    (_, enabled) => manager.setEnabled(enabled),
    fireImmediately: true,
  );
  return manager;
}

/// Rewarded manager for user-initiated "watch an ad to unlock" flows.
@Riverpod(keepAlive: true)
RewardedAdManager rewardedAdManager(Ref ref) {
  final manager = RewardedAdManager();
  ref.onDispose(manager.dispose);
  ref.listen(
    adsEnabledProvider,
    (_, enabled) => manager.setEnabled(enabled),
    fireImmediately: true,
  );
  return manager;
}
