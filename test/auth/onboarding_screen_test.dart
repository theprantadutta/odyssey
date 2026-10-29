import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/core/router/app_router.dart';
import 'package:odyssey/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:odyssey/src/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:odyssey/src/features/trips/data/models/trip_model.dart';
import 'package:odyssey/src/features/trips/presentation/providers/trips_provider.dart';

class _FakeAuth extends Auth {
  _FakeAuth({this.isGuest = false});

  final bool isGuest;
  String? completedWith;

  @override
  AuthState build() => isGuest
      ? const AuthState(isGuest: true)
      : const AuthState(isAuthenticated: true);

  @override
  Future<void> completeOnboarding({required String choice}) async {
    completedWith = choice;
  }
}

class _FakeTrips extends Trips {
  TripRequest? request;
  String? source;

  @override
  TripsState build() => const TripsState();

  @override
  Future<TripModel> createTrip(
    TripRequest request, {
    String source = 'manual',
  }) async {
    this.request = request;
    this.source = source;
    return TripModel(
      id: 'trip-1',
      userId: 'user-1',
      title: request.title,
      startDate: request.startDate,
      endDate: request.endDate,
      status: request.status,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    );
  }
}

/// Onboarding is the default path to a user's first trip: the destination and
/// dates are the whole form, and finishing it lands inside the trip with home
/// underneath.
void main() {
  late _FakeAuth auth;
  late _FakeTrips trips;
  late GoRouter router;

  Future<void> pumpOnboarding(WidgetTester tester, {bool guest = false}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    auth = _FakeAuth(isGuest: guest);
    trips = _FakeTrips();
    router = GoRouter(
      initialLocation: AppRoutes.onboarding,
      routes: [
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('home screen'),
        ),
        GoRoute(
          path: '${AppRoutes.tripDetail}/:id',
          builder: (context, state) =>
              Text('trip ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => auth),
          tripsProvider.overrideWith(() => trips),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create my trip'));
    await tester.tap(find.text('Create my trip'));
    await tester.pumpAndSettle();
  }

  Future<void> pickDays(WidgetTester tester, String first, String last) async {
    for (final day in [first, last]) {
      await tester.ensureVisible(find.text(day));
      await tester.tap(find.text(day));
      await tester.pump();
    }
  }

  testWidgets('needs both a destination and a full date range',
      (tester) async {
    await pumpOnboarding(tester);

    await tapCreate(tester);
    expect(trips.request, isNull);

    await tester.enterText(find.byType(TextField), 'Lisbon');
    await tester.pump();
    await tapCreate(tester);
    expect(trips.request, isNull, reason: 'no dates yet');

    await pickDays(tester, '10', '14');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tapCreate(tester);
    expect(trips.request, isNull, reason: 'blank destination');
  });

  testWidgets('creates the trip and lands inside it', (tester) async {
    await pumpOnboarding(tester);

    await tester.enterText(find.byType(TextField), '  Lisbon ');
    await pickDays(tester, '10', '14');
    await tapCreate(tester);

    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    expect(trips.request!.title, 'Lisbon');
    expect(trips.request!.startDate, '${now.year}-$month-10');
    expect(trips.request!.endDate, '${now.year}-$month-14');
    expect(trips.source, 'onboarding');
    expect(auth.completedWith, 'first_trip');

    expect(find.text('trip trip-1'), findsOneWidget);
    // Home sits underneath, so the trip's back button has somewhere to go.
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('skipping creates nothing and goes home', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(trips.request, isNull);
    expect(auth.completedWith, 'skipped');
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('offers sample trips to an account', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Show me sample trips'), findsOneWidget);
  });

  testWidgets('does not offer a guest sample trips, which the server makes',
      (tester) async {
    await pumpOnboarding(tester, guest: true);
    expect(find.text('Show me sample trips'), findsNothing);
    expect(find.text('Skip for now'), findsOneWidget);
  });
}
