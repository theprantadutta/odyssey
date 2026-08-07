import 'package:flutter/widgets.dart';

/// Names for screens where the user is *in the middle of doing something* —
/// forms, uploads and viewers — as opposed to browsing.
///
/// Most of these are pushed imperatively with a raw `MaterialPageRoute` rather
/// than through GoRouter, so without an explicit name they arrive at every
/// [NavigatorObserver] as an anonymous route. Two things depend on naming them:
///
///  * `InterstitialRouteObserver` excludes them from the interstitial cadence.
///    A full-screen ad on top of a half-filled expense form is the worst
///    possible placement, and it's exactly what unnamed routes used to produce.
///  * `FirebaseAnalyticsObserver` reads `RouteSettings.name` for screen
///    tracking, so naming these is what makes them show up in analytics at all.
///
/// Kept in its own file (rather than alongside `AppRoutes`) so the ad layer can
/// depend on it without importing the router, which imports the ad observer.
class TaskRoutes {
  TaskRoutes._();

  static const String tripForm = 'trip-form';
  static const String activityForm = 'activity-form';
  static const String expenseForm = 'expense-form';
  static const String packingItemForm = 'packing-item-form';
  static const String documentUpload = 'document-upload';
  static const String photoUpload = 'photo-upload';
  static const String pdfViewer = 'pdf-viewer';
  static const String photoViewer = 'photo-viewer';
  static const String legalViewer = 'legal-viewer';

  /// Every name above. Used for membership checks by route observers.
  static const Set<String> all = <String>{
    tripForm,
    activityForm,
    expenseForm,
    packingItemForm,
    documentUpload,
    photoUpload,
    pdfViewer,
    photoViewer,
    legalViewer,
  };

  /// Fragments of GoRouter *path patterns* that are also task screens.
  ///
  /// GoRouter names its generated pages after the matched path pattern (e.g.
  /// `/edit-trip/:id`), so these are matched as substrings rather than by
  /// equality. Mirrors the corresponding entries in `AppRoutes`.
  static const List<String> goRouterPathFragments = <String>[
    'create-trip',
    'edit-trip',
  ];

  /// Whether [route] is a task screen that observers should skip.
  static bool isTaskRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return false;
    if (all.contains(name)) return true;
    return goRouterPathFragments.any(name.contains);
  }

  /// Shorthand for tagging an imperatively-pushed route.
  static RouteSettings settings(String name) => RouteSettings(name: name);
}
