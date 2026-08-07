import 'package:flutter/widgets.dart';

import '../../../../core/router/task_routes.dart';

/// A [NavigatorObserver] that pings a callback on navigations that represent the
/// user *finishing a step and moving on*, rather than diving deeper into work.
/// Wired into GoRouter's `observers`; the callback forwards to
/// `InterstitialAdManager.onNavigation`, which decides whether this particular
/// navigation should surface an interstitial.
///
/// Three filters keep the cadence off task flows:
///
///  * **Non-page routes** — dialogs, popups and bottom sheets never count.
///  * **Full-screen dialogs** — the paywall is pushed as a `fullscreenDialog`
///    `MaterialPageRoute`, so before this filter existed a paywall push could be
///    the Nth navigation and land an interstitial on top of the paywall itself.
///  * **Task routes** — forms, uploads and viewers, identified via
///    [TaskRoutes.isTaskRoute]. A full-screen ad on top of a half-filled expense
///    form is the worst placement in the app.
class InterstitialRouteObserver extends NavigatorObserver {
  InterstitialRouteObserver(this.onNavigation);

  /// Invoked once per qualifying route push.
  final void Function() onNavigation;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Ignore the very first push (initial route) — there's no prior screen, so
    // it isn't a navigation the user initiated.
    if (previousRoute == null) return;
    // Only count full pages, not dialogs/popups/bottom sheets.
    if (route is! PageRoute) return;
    // Modal, dialog-style pages (paywall, and anything else pushed as one) are
    // never a natural break — they're a response to the user hitting a wall.
    if (route.fullscreenDialog) return;
    // The user is mid-task on these.
    if (TaskRoutes.isTaskRoute(route)) return;

    onNavigation();
  }
}
