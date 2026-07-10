/// Tunable knobs for ad cadence / aggressiveness.
///
/// Everything that controls "how often" lives here so the intensity can be
/// dialled up or down in one place without touching the managers.
///
/// The "aggressiveness" knobs are **mutable defaults**: [RemoteAdConfig] may
/// overwrite them at startup from Firebase Remote Config, so cadence can be
/// tuned live (A/B tested, dialled back on complaints) without shipping a build.
/// The values assigned here are the safe fallbacks used until — or if — a remote
/// fetch succeeds. A couple of purely technical/policy values stay `const`
/// because they should never be remotely tuned.
///
/// Current profile: **moderate** (tuned for AdMob policy safety while still
/// monetizing free users well). Free users only — all of this is gated behind
/// [adsEnabledProvider], so paid users never see a single ad and these
/// values are irrelevant to them.
class AdConstants {
  AdConstants._();

  // ─── Interstitial ──────────────────────────────────────────────────────
  /// Show an interstitial on every Nth qualifying navigation.
  ///
  /// Odyssey is a planning app, not a game — users navigate a lot while mid-task
  /// and there are few "natural break" moments, so full-screen interruptions
  /// land harder here than in games. Keep this deliberately relaxed.
  ///
  /// Remotely tunable. Clamped to >= 1 on apply (0 would divide by zero).
  static int interstitialEveryNNavigations = 6;

  /// Minimum gap between two interstitials. Remotely tunable.
  static Duration interstitialCooldown = const Duration(seconds: 90);

  /// Hard cap on how many interstitials a single app session may show. The
  /// cooldown only spaces ads apart; without this, a long session has no upper
  /// bound on total interstitial volume. This is the real guard on aggregate
  /// intrusiveness (and on AdMob ad-frequency scrutiny). Remotely tunable.
  static int interstitialMaxPerSession = 5;

  // ─── App Open ──────────────────────────────────────────────────────────
  /// Only show an app-open ad on resume if the app spent at least this long
  /// in the background (prevents an ad on every tiny app switch). Remotely
  /// tunable.
  static Duration appOpenMinBackgroundDuration = const Duration(seconds: 60);

  /// App-open ads expire ~4h after load per Google; refresh defensively.
  /// Technical constant — not remotely tunable.
  static const Duration appOpenAdMaxCacheAge = Duration(hours: 4);

  // ─── Cross-format spacing ────────────────────────────────────────────────
  /// After any full-screen ad (app-open OR interstitial), suppress the other
  /// kind for this long so users never get two full-screen ads back-to-back.
  /// Technical/policy constant — not remotely tunable.
  static const Duration fullScreenAdMutualCooldown = Duration(seconds: 30);

  // ─── Native inline ───────────────────────────────────────────────────────
  /// Inject a native ad after every Nth item in long lists (e.g. trips).
  /// Remotely tunable. Clamped to >= 1 on apply (0 would divide by zero).
  static int nativeAdEveryNItems = 4;

  /// Don't show inline native ads until the list has at least this many real
  /// items (avoids an ad dominating a near-empty list). Remotely tunable.
  static int nativeAdMinItemsBeforeFirst = 3;
}
