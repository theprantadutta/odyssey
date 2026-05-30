import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Central resolver for AdMob ad-unit IDs.
///
/// AdMob IDs are **not secrets** — they're embedded in the shipped app binary
/// and visible to anyone — so the real IDs live here as committed constants
/// (not in `.env`). Keeping them in code also avoids a nasty failure mode: a
/// gitignored `.env` would be absent on CI / fresh clones, silently leaving a
/// release build on test ads. Constants are always present.
///
/// Safety rule that still applies:
///  * **Debug / profile builds always return Google's official TEST ad units.**
///    Tapping a live ad during development can get an AdMob account banned.
///  * **Release builds return the real Odyssey ad units below.**
///
/// App-level IDs (the `~` form) are NOT here — those live in the native
/// AndroidManifest / Info.plist. These are the per-format ad-unit IDs (`/` form).
class AdMobConfig {
  AdMobConfig._();

  /// AdMob only supports Android & iOS. Used to short-circuit on web/desktop.
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ─── Google's official sample/test ad units ──────────────────────────────
  // https://developers.google.com/admob/flutter/test-ads
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _testAppOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const _testAppOpenIos = 'ca-app-pub-3940256099942544/5575463023';
  static const _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  // ─── Real Odyssey ad units (used in release builds only) ─────────────────
  static const _bannerAndroid = 'ca-app-pub-9242904787767394/9610269465';
  static const _bannerIos = 'ca-app-pub-9242904787767394/1923351138';
  static const _interstitialAndroid = 'ca-app-pub-9242904787767394/6984106128';
  static const _interstitialIos = 'ca-app-pub-9242904787767394/3603264319';
  static const _rewardedAndroid = 'ca-app-pub-9242904787767394/6521071698';
  static const _rewardedIos = 'ca-app-pub-9242904787767394/4209087752';
  static const _appOpenAndroid = 'ca-app-pub-9242904787767394/8479505259';
  static const _appOpenIos = 'ca-app-pub-9242904787767394/7166423589';
  static const _nativeAndroid = 'ca-app-pub-9242904787767394/8955663340';
  static const _nativeIos = 'ca-app-pub-9242904787767394/7642581676';

  /// Returns the test unit in debug/profile and the real unit in release,
  /// picking the platform variant.
  static String _resolve({
    required String releaseAndroid,
    required String releaseIos,
    required String testAndroid,
    required String testIos,
  }) {
    if (!kReleaseMode) return _isAndroid ? testAndroid : testIos;
    return _isAndroid ? releaseAndroid : releaseIos;
  }

  static String get bannerAdUnitId => _resolve(
        releaseAndroid: _bannerAndroid,
        releaseIos: _bannerIos,
        testAndroid: _testBannerAndroid,
        testIos: _testBannerIos,
      );

  static String get interstitialAdUnitId => _resolve(
        releaseAndroid: _interstitialAndroid,
        releaseIos: _interstitialIos,
        testAndroid: _testInterstitialAndroid,
        testIos: _testInterstitialIos,
      );

  static String get rewardedAdUnitId => _resolve(
        releaseAndroid: _rewardedAndroid,
        releaseIos: _rewardedIos,
        testAndroid: _testRewardedAndroid,
        testIos: _testRewardedIos,
      );

  static String get appOpenAdUnitId => _resolve(
        releaseAndroid: _appOpenAndroid,
        releaseIos: _appOpenIos,
        testAndroid: _testAppOpenAndroid,
        testIos: _testAppOpenIos,
      );

  static String get nativeAdUnitId => _resolve(
        releaseAndroid: _nativeAndroid,
        releaseIos: _nativeIos,
        testAndroid: _testNativeAndroid,
        testIos: _testNativeIos,
      );

  /// Physical device IDs that should always receive test ads (safe to tap even
  /// from real ad units). Run the app once on a device and copy the ID it logs
  /// (`Use ... setTestDeviceIds(Arrays.asList("33BE2250B43..."))`) into here.
  static const List<String> testDeviceIds = <String>[
    // 'YOUR_DEVICE_ID',
  ];
}
