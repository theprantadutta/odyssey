import 'package:flutter/widgets.dart';

/// A [NavigatorObserver] that pings a callback on every meaningful forward
/// navigation (route push). Wired into GoRouter's `observers`; the callback
/// forwards to [InterstitialAdManager.onNavigation], which decides whether this
/// particular navigation should surface an interstitial.
///
/// We only count pushes (not pops/replaces) so the cadence tracks "user went
/// deeper into the app", which is the natural, least-annoying interstitial beat.
class InterstitialRouteObserver extends NavigatorObserver {
  InterstitialRouteObserver(this.onNavigation);

  /// Invoked once per route push.
  final void Function() onNavigation;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Ignore the very first push (initial route) — there's no prior screen, so
    // it isn't a navigation the user initiated.
    if (previousRoute == null) return;
    // Only count full pages, not dialogs/popups/bottom sheets.
    if (route is PageRoute) {
      onNavigation();
    }
  }
}
