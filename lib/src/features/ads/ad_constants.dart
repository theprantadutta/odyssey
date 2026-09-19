/// Compile-time tuning for ad presence and cadence.
///
/// Everything that controls "which formats run" and "how often" lives here so
/// the intensity can be dialled up or down in one place without touching the
/// managers or the screens. Every value is `const`: changing the ad profile is a
/// deliberate code change that ships with a release, not a runtime surprise.
///
/// All of this is gated behind `adsEnabledProvider`, so premium users never see
/// a single ad and these values are irrelevant to them.
///
/// ─── Current profile: QUIET LAUNCH ────────────────────────────────────────
///
/// Odyssey is a trip-planning app with a small user base, and the subscription —
/// not ad impressions — is the revenue that matters at this scale. Ad load is
/// therefore tuned for retention rather than yield:
///
///   * Full-screen formats (interstitial, app-open) are **off**. Both interrupt
///     mid-task, which in a planning app is most of the time.
///   * The anchored banner is **gone**. Odyssey 2.0 floats a glass nav in that
///     exact space, and the design system has no slot for a bar beneath it.
///   * Native tiles are compact and sparse.
///   * Rewarded stays on — it's opt-in, and it doubles as a free trial of the
///     premium features, so it drives subscriptions instead of fighting them.
///
/// To dial intensity back up later, flip the [Formats] switches and lower the
/// cadence numbers. The managers already enforce cooldowns, per-session caps and
/// cross-format spacing, so raising the switches is safe.
class AdConstants {
  AdConstants._();

  // ─── Format kill switches ────────────────────────────────────────────────
  /// Master on/off per ad format. A disabled format never loads and never
  /// shows — the managers short-circuit before requesting anything, so a format
  /// turned off here costs zero ad requests.
  ///
  /// Turning a format back on needs no other change; the cadence values below
  /// are already set to sane values for when that happens.

  // The anchored bottom banner was removed in the Odyssey 2.0 redesign: the
  // floating nav occupies that space on every screen that had one. Nothing
  // requests a banner any more, so there is no switch to leave off.

  /// Inline native tiles in long lists. On, but sparse and compact.
  static const bool nativeEnabled = true;

  /// Full-screen interstitial between screens. **Off.** In a planning app a
  /// navigation means "user is going deeper into a task", not "user finished
  /// something" — there is no natural break to attach this to.
  static const bool interstitialEnabled = false;

  /// Full-screen ad when returning to the app. **Off.** Trip planning means
  /// constantly switching to Maps/airline sites/email and coming back; every one
  /// of those round-trips would earn an ad.
  static const bool appOpenEnabled = false;

  /// User-initiated "watch an ad to unlock" flows. On — opt-in, and it's the one
  /// format that fits this app.
  static const bool rewardedEnabled = true;

  // ─── New-user grace period ───────────────────────────────────────────────
  /// No ads at all for this long after first launch.
  ///
  /// The first session decides whether someone keeps the app, and a user who
  /// churns on day one never reaches the paywall on day thirty. Suppressing ads
  /// while a user is still deciding costs almost nothing in impressions and
  /// protects the top of the funnel.
  ///
  /// Rewarded ads are deliberately exempt: they're user-initiated and unlock
  /// premium features, so they help rather than hurt during onboarding.
  static const Duration newUserGracePeriod = Duration(days: 3);

  // ─── Interstitial ────────────────────────────────────────────────────────
  /// Show an interstitial on every Nth qualifying navigation. Only navigations
  /// that look like a completed step count — form screens, uploads and the
  /// paywall are excluded by the route observer.
  ///
  /// Must be >= 1 (it's a divisor).
  static const int interstitialEveryNNavigations = 20;

  /// Minimum gap between two interstitials.
  static const Duration interstitialCooldown = Duration(minutes: 5);

  /// Hard cap on how many interstitials a single app session may show. The
  /// cooldown only spaces ads apart; without this, a long session has no upper
  /// bound on total interstitial volume.
  static const int interstitialMaxPerSession = 1;

  /// How long to wait after a route push before showing an interstitial, so the
  /// ad never lands on top of a screen that is still animating in.
  static const Duration interstitialShowDelay = Duration(milliseconds: 350);

  // ─── App Open ────────────────────────────────────────────────────────────
  /// Only show an app-open ad on resume if the app spent at least this long in
  /// the background. Set long enough that only a genuinely new session
  /// qualifies — not the constant app-switching that trip planning involves.
  static const Duration appOpenMinBackgroundDuration = Duration(hours: 4);

  /// App-open ads expire ~4h after load per Google; refresh defensively.
  static const Duration appOpenAdMaxCacheAge = Duration(hours: 4);

  // ─── Cross-format spacing ────────────────────────────────────────────────
  /// After any full-screen ad (app-open OR interstitial), suppress the other
  /// kind for this long so users never get two full-screen ads back-to-back.
  static const Duration fullScreenAdMutualCooldown = Duration(seconds: 30);

  // ─── Native inline ───────────────────────────────────────────────────────
  /// Inject a native ad after every Nth item in long lists (e.g. trips).
  /// Must be >= 1 (it's a divisor).
  static const int nativeAdEveryNItems = 8;

  /// Don't show inline native ads until the list has at least this many real
  /// items, so an ad can never dominate a short list.
  static const int nativeAdMinItemsBeforeFirst = 6;
}
