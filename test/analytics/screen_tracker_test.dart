import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:odyssey/src/core/router/app_router.dart';
import 'package:odyssey/src/core/router/screen_tracker.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';

class _RecordingAnalytics implements AnalyticsClient {
  final screens = <String>[];

  @override
  Future<void> trackScreenView({required String screenName}) async =>
      screens.add(screenName);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// The app's shape in miniature: two tabs in a stateful shell, a full-screen
/// trip detail outside it, and an imperatively pushed form.
GoRouter _buildRouter(ScreenTracker tracker) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    observers: [tracker.observer],
    routes: [
      GoRoute(
        path: '${AppRoutes.tripDetail}/:id',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'expense-form'),
                builder: (_) => const Scaffold(body: Text('form')),
              ),
            ),
            child: const Text('open form'),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: Row(
            children: [
              TextButton(
                onPressed: () => shell.goBranch(0),
                child: const Text('tab home'),
              ),
              TextButton(
                onPressed: () => shell.goBranch(1),
                child: const Text('tab trips'),
              ),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => TextButton(
                onPressed: () => context.push('${AppRoutes.tripDetail}/42'),
                child: const Text('open trip'),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.trips,
              builder: (context, state) => const Text('trips list'),
            ),
          ]),
        ],
      ),
    ],
  );
}

void main() {
  late _RecordingAnalytics analytics;
  late ScreenTracker tracker;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    analytics = _RecordingAnalytics();
    tracker = ScreenTracker(analytics);
    router = _buildRouter(tracker);
    tracker.attach(router);
    addTearDown(() {
      tracker.detach();
      router.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('reports the initial tab once', (tester) async {
    await pumpApp(tester);
    expect(analytics.screens, ['home']);
  });

  testWidgets('reports tab switches, which push nothing', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('tab trips'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tab home'));
    await tester.pumpAndSettle();

    expect(analytics.screens, ['home', 'trips', 'home']);
  });

  testWidgets('reports the tab again after popping a full-screen route',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('open trip'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(analytics.screens, ['home', 'trip_detail', 'home']);
  });

  testWidgets('reports imperative pushes and the screen they return to',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('open trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('form'))).pop();
    await tester.pumpAndSettle();

    expect(
      analytics.screens,
      ['home', 'trip_detail', 'expense_form', 'trip_detail'],
    );
  });

  testWidgets('ignores router refreshes that land on the same screen',
      (tester) async {
    await pumpApp(tester);

    router.refresh();
    await tester.pumpAndSettle();

    expect(analytics.screens, ['home']);
  });

  group('screen names', () {
    test('known routes use their table name', () {
      expect(screenNameForPath('${AppRoutes.tripDetail}/:id'), 'trip_detail');
      expect(screenNameForPath(AppRoutes.trips), 'trips');
      expect(screenNameForPath('year-review'), 'year_in_review');
    });

    test('unknown routes fall back to a name derived from the path', () {
      expect(screenNameForPath('/some-new/:id/thing'), 'some_new_thing');
      expect(screenNameForRouteName('packing-item-form'), 'packing_item_form');
      expect(screenNameForRouteName('/'), 'unknown');
    });
  });
}
