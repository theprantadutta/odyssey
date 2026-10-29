import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/analytics_service.dart';
import 'app_router.dart';

/// Reports a `screen_view` for every screen the user lands on, under a stable,
/// readable name.
///
/// The app navigates two ways, so two sources feed it:
///
///  * **GoRouter pages** are read from the router's current configuration each
///    time it changes. A navigator observer alone misses two of the most common
///    moves: switching tabs (the shell swaps branches without pushing anything)
///    and coming back to a tab after popping a full-screen route (the page
///    revealed is the shell itself, which has no name).
///  * **Imperative pushes** — the forms, viewers and paywall pushed with a raw
///    `MaterialPageRoute` — never touch the router's configuration, so
///    [observer] reports those, and re-reports the router's screen once the
///    last of them is popped.
///
/// The one [observer] belongs in GoRouter's root `observers`. The shell's
/// branch navigators forward to the root observers (`notifyRootObserver`
/// defaults to true), so pushes made from inside a tab arrive there too.
class ScreenTracker {
  ScreenTracker(this._analytics);

  final AnalyticsClient _analytics;

  GoRouter? _router;
  String? _lastScreen;

  /// Imperative pages currently on screen above the router's page. While any
  /// are up, router changes (auth refreshes, redirects) are not what the user
  /// is looking at, so they are not reported.
  int _imperativeDepth = 0;

  late final NavigatorObserver observer = _ImperativeRouteObserver(this);

  void attach(GoRouter router) {
    _router = router;
    router.routerDelegate.addListener(_onRouterChanged);
    _onRouterChanged();
  }

  void detach() {
    _router?.routerDelegate.removeListener(_onRouterChanged);
    _router = null;
  }

  void _onRouterChanged() {
    if (_imperativeDepth > 0) return;
    _reportRouterScreen();
  }

  void _reportRouterScreen({bool force = false}) {
    final match = _router?.routerDelegate.currentConfiguration.lastOrNull;
    if (match == null) return;
    _report(screenNameForPath(match.route.path), force: force);
  }

  /// Router notifications repeat for the same location (refreshes, redirects
  /// that land where they started), hence the de-duplication. [force] is for a
  /// genuine return to a screen, such as popping a form back to its trip.
  void _report(String screenName, {bool force = false}) {
    if (!force && screenName == _lastScreen) return;
    _lastScreen = screenName;
    _analytics.trackScreenView(screenName: screenName);
  }

  void _onImperativePush(Route<dynamic> route) {
    _imperativeDepth++;
    final name = route.settings.name;
    if (name != null) _report(screenNameForRouteName(name), force: true);
  }

  void _onImperativeGone(Route<dynamic>? revealed) {
    if (_imperativeDepth > 0) _imperativeDepth--;
    if (revealed != null && _ImperativeRouteObserver.isImperative(revealed)) {
      final name = revealed.settings.name;
      if (name != null) _report(screenNameForRouteName(name), force: true);
    } else if (_imperativeDepth == 0) {
      _reportRouterScreen(force: true);
    }
  }
}

class _ImperativeRouteObserver extends NavigatorObserver {
  _ImperativeRouteObserver(this._tracker);

  final ScreenTracker _tracker;

  /// A full page that GoRouter didn't build. GoRouter's routes carry their
  /// [Page] as settings; a raw `MaterialPageRoute` carries plain
  /// [RouteSettings]. Dialogs and bottom sheets aren't screens.
  static bool isImperative(Route<dynamic> route) =>
      route is PageRoute && route.settings is! Page;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (isImperative(route)) _tracker._onImperativePush(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (isImperative(route)) _tracker._onImperativeGone(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (isImperative(route)) _tracker._onImperativeGone(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null && isImperative(oldRoute)) {
      _tracker._onImperativeGone(null);
    }
    if (newRoute != null && isImperative(newRoute)) {
      _tracker._onImperativePush(newRoute);
    }
  }
}

/// Analytics names for GoRouter routes, keyed by the route's own `path` (so
/// nested routes appear by their relative segment).
const Map<String, String> _screenNamesByPath = {
  AppRoutes.splash: 'splash',
  AppRoutes.intro: 'intro',
  AppRoutes.legalAgreement: 'legal_agreement',
  AppRoutes.login: 'login',
  AppRoutes.register: 'register',
  AppRoutes.onboarding: 'onboarding',
  AppRoutes.createTrip: 'trip_create',
  '${AppRoutes.editTrip}/:id': 'trip_edit',
  '${AppRoutes.acceptInvite}/:code': 'accept_invite',
  '${AppRoutes.tripDetail}/:id': 'trip_detail',
  'shares': 'manage_shares',
  AppRoutes.sharedTrips: 'shared_trips',
  AppRoutes.templates: 'templates',
  AppRoutes.achievements: 'achievements',
  AppRoutes.statistics: 'statistics',
  'year-review': 'year_in_review',
  AppRoutes.notifications: 'notifications',
  AppRoutes.notificationSettings: 'notification_settings',
  AppRoutes.subscription: 'subscription',
  // Tabs.
  AppRoutes.home: 'home',
  AppRoutes.trips: 'trips',
  AppRoutes.worldMap: 'world_map',
  AppRoutes.settings: 'settings',
};

/// The analytics name for a GoRouter route path. A route missing from the
/// table still reports, under a name derived from its path.
@visibleForTesting
String screenNameForPath(String path) =>
    _screenNamesByPath[path] ?? screenNameForRouteName(path);

/// The analytics name for an imperatively pushed route, e.g. `TaskRoutes`'
/// `expense-form` becomes `expense_form`.
@visibleForTesting
String screenNameForRouteName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r':\w+'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
  return cleaned.isEmpty ? 'unknown' : cleaned;
}
