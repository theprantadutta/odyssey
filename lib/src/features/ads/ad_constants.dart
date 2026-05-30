/// Tunable knobs for ad cadence / aggressiveness.
///
/// Everything that controls "how often" lives here so the intensity can be
/// dialled up or down in one place without touching the managers.
///
/// Current profile: **aggressive** (per product decision). Free users only —
/// all of this is gated behind [adsEnabledProvider], so paid users never see
/// a single ad and these constants are irrelevant to them.
class AdConstants {
  AdConstants._();

  // ─── Interstitial ──────────────────────────────────────────────────────
  /// Show an interstitial on every Nth qualifying navigation.
  static const int interstitialEveryNNavigations = 3;

  /// Minimum gap between two interstitials.
  static const Duration interstitialCooldown = Duration(seconds: 45);

  // ─── App Open ──────────────────────────────────────────────────────────
  /// Only show an app-open ad on resume if the app spent at least this long
  /// in the background (prevents an ad on every tiny app switch).
  static const Duration appOpenMinBackgroundDuration = Duration(seconds: 30);

  /// App-open ads expire ~4h after load per Google; refresh defensively.
  static const Duration appOpenAdMaxCacheAge = Duration(hours: 4);

  // ─── Cross-format spacing ────────────────────────────────────────────────
  /// After any full-screen ad (app-open OR interstitial), suppress the other
  /// kind for this long so users never get two full-screen ads back-to-back.
  static const Duration fullScreenAdMutualCooldown = Duration(seconds: 30);

  // ─── Native inline ───────────────────────────────────────────────────────
  /// Inject a native ad after every Nth item in long lists (e.g. trips).
  static const int nativeAdEveryNItems = 4;

  /// Don't show inline native ads until the list has at least this many real
  /// items (avoids an ad dominating a near-empty list).
  static const int nativeAdMinItemsBeforeFirst = 3;
}
