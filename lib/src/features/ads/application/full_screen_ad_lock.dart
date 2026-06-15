import '../ad_constants.dart';

/// Global coordinator so two full-screen ads (app-open + interstitial) never
/// fire back-to-back. Both managers consult this before showing.
///
/// This is intentionally a tiny process-wide singleton (not a provider): the
/// app-open manager lives at the [WidgetsBinding] lifecycle level and the
/// interstitial manager hangs off a [NavigatorObserver], so a plain shared
/// object is the simplest thing that correctly serializes them.
class FullScreenAdLock {
  FullScreenAdLock._();
  static final FullScreenAdLock instance = FullScreenAdLock._();

  bool _isShowing = false;
  DateTime? _lastDismissedAt;

  /// True while any full-screen ad is currently on screen.
  bool get isShowing => _isShowing;

  /// Whether a new full-screen ad may be shown right now, respecting the
  /// mutual cooldown after the previous one was dismissed.
  bool get canShowFullScreenAd {
    if (_isShowing) return false;
    final last = _lastDismissedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >=
        AdConstants.fullScreenAdMutualCooldown;
  }

  void markShowing() => _isShowing = true;

  void markDismissed() {
    _isShowing = false;
    _lastDismissedAt = DateTime.now();
  }
}
