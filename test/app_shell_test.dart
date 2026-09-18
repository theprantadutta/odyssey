import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/router/app_router.dart';

/// The route table every screen navigates by.
///
/// `test/widget_test.dart` previously held one test named "App builds
/// successfully" whose entire body was `expect(true, isTrue)`. It never pumped
/// the app and passed whatever the state of the code — a green result standing
/// in for a check that did not exist, which is worse than no file at all
/// because the suite count implied coverage that was not there.
///
/// What replaces it is deliberately smaller than the name it replaced.
///
/// Constructing the real themes needs the Nunito font files present as bundled
/// assets: `google_fonts` fetches them over HTTP on first use, a test binding
/// answers every request with 400, and disabling runtime fetching then throws
/// because the font is not in the assets either. Asserting around that would
/// only prove the suppression worked. Building the app shell itself needs
/// Firebase, Drift and secure storage stood up.
///
/// Both belong in the device acceptance pass, and are listed there. What can be
/// checked honestly without a platform is checked here.
void main() {
  /// Every route constant the app navigates by.
  const routes = <String, String>{
    'splash': AppRoutes.splash,
    'intro': AppRoutes.intro,
    'legalAgreement': AppRoutes.legalAgreement,
    'login': AppRoutes.login,
    'register': AppRoutes.register,
    'onboarding': AppRoutes.onboarding,
    'home': AppRoutes.home,
    'createTrip': AppRoutes.createTrip,
    'tripDetail': AppRoutes.tripDetail,
  };

  test('every route is a rooted path', () {
    for (final entry in routes.entries) {
      expect(entry.value, startsWith('/'),
          reason: '${entry.key} is not a rooted path');
      expect(entry.value.trim(), entry.value,
          reason: '${entry.key} has surrounding whitespace');
      expect(entry.value, isNotEmpty);
    }
  });

  test('no two routes share a path', () {
    final seen = <String, String>{};

    for (final entry in routes.entries) {
      final clash = seen[entry.value];

      // Two names for one path means one of them silently never matches, and
      // which one wins depends on registration order.
      expect(clash, isNull,
          reason: '${entry.key} and $clash are both "${entry.value}"');

      seen[entry.value] = entry.key;
    }
  });

  test('a prefix route carries no trailing slash', () {
    // tripDetail is used as a prefix - `'${AppRoutes.tripDetail}/$id'` - so a
    // trailing slash here would give every trip link a double one.
    expect(AppRoutes.tripDetail, isNot(endsWith('/')));
  });
}
