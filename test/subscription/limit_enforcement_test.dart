import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/core/providers/analytics_provider.dart';
import 'package:odyssey/src/core/services/analytics_service.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:odyssey/src/features/subscription/presentation/utils/limit_checker.dart';

/// The enforcement side of the rule the upsells already obey.
///
/// Hiding an upsell from an unresolved account was only half of it. The caps
/// were still chosen with `sub.isPremium`, which is false for a subscriber
/// whose status has not arrived - so during startup a paying customer got the
/// free caps, and every check below turns a cap into a paywall. Somebody could
/// be stopped from adding a sixth photo and asked to buy what they had bought.
void main() {
  const free = TierLimits(
    activeTrips: 5,
    activitiesPerTrip: 25,
    expensesPerTrip: 30,
    packingItemsPerTrip: 50,
    memoriesPerTrip: 10,
    mediaPerMemory: 5,
    documentsPerTrip: 5,
    filesPerDocument: 3,
    templates: 3,
    storageBytes: 1073741824,
    maxFileSizeBytes: 26214400,
    allowVideo: false,
    allowEditSharing: false,
    allowPublicTemplates: false,
    allowWorldMap: false,
    allowYearInReview: false,
    allowFullStatistics: false,
    allowLeaderboard: false,
    allowAllAchievements: false,
    allowDataExport: false,
  );

  const premium = TierLimits(
    activeTrips: -1,
    activitiesPerTrip: -1,
    expensesPerTrip: -1,
    packingItemsPerTrip: -1,
    memoriesPerTrip: -1,
    mediaPerMemory: 50,
    documentsPerTrip: -1,
    filesPerDocument: 25,
    templates: -1,
    storageBytes: 26843545600,
    maxFileSizeBytes: 524288000,
    allowVideo: true,
    allowEditSharing: true,
    allowPublicTemplates: true,
    allowWorldMap: true,
    allowYearInReview: true,
    allowFullStatistics: true,
    allowLeaderboard: true,
    allowAllAchievements: true,
    allowDataExport: true,
  );

  const limits = SubscriptionLimits(free: free, premium: premium);

  Widget harness(Entitlement entitlement, Widget child) => ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(
        () => _StubSubscription(entitlement: entitlement, limits: limits),
      ),
      // The paywall this opens reports itself on the way in, and the real
      // client wants a Firebase app.
      analyticsServiceProvider.overrideWithValue(AnalyticsFacade([])),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );

  /// Taps a gated action and reports what happened.
  ///
  /// The paywall is a modal with a running animation, so it never settles and
  /// the check never returns while it is open. Its presence is the outcome:
  /// `allowed` stays null exactly when the user was stopped.
  Future<({bool? allowed, bool paywall})> attempt(
    WidgetTester tester,
    Entitlement entitlement,
    Future<bool> Function(BuildContext, WidgetRef) run,
  ) async {
    bool? allowed;
    await tester.pumpWidget(
      harness(
        entitlement,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => allowed = await run(context, ref),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    return (
      allowed: allowed,
      paywall: find.textContaining('limit reached').evaluate().isNotEmpty,
    );
  }

  /// Reads a tier number as the app would while building a screen.
  Future<int?> filesPerDocument(
    WidgetTester tester,
    Entitlement entitlement,
  ) async {
    int? seen;
    await tester.pumpWidget(
      harness(
        entitlement,
        Consumer(
          builder: (context, ref, _) {
            seen = LimitChecker.getFilesPerDocumentLimit(ref);
            return const SizedBox();
          },
        ),
      ),
    );
    return seen;
  }

  group('a cap is not applied to an account we cannot identify', () {
    testWidgets('a subscriber mid-startup is not held to the free cap', (
      tester,
    ) async {
      // The bug, exactly: at the free cap of 10 memories with the entitlement
      // still unresolved. This used to open a paywall.
      final outcome = await attempt(
        tester,
        Entitlement.unknown,
        (context, ref) =>
            LimitChecker.canCreateMemory(context, ref, currentCount: 10),
      );

      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });

    testWidgets('a known-free account at its cap still meets the paywall', (
      tester,
    ) async {
      final outcome = await attempt(
        tester,
        Entitlement.free,
        (context, ref) =>
            LimitChecker.canCreateMemory(context, ref, currentCount: 10),
      );

      expect(outcome.paywall, isTrue);
    });

    testWidgets('a known-free account under its cap is left alone', (
      tester,
    ) async {
      final outcome = await attempt(
        tester,
        Entitlement.free,
        (context, ref) =>
            LimitChecker.canCreateMemory(context, ref, currentCount: 3),
      );

      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });

    testWidgets('a subscriber is held to the premium cap, which is unlimited', (
      tester,
    ) async {
      final outcome = await attempt(
        tester,
        Entitlement.premium,
        (context, ref) =>
            LimitChecker.canCreateMemory(context, ref, currentCount: 900),
      );

      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });

    testWidgets('the same holds for trips', (tester) async {
      final outcome = await attempt(
        tester,
        Entitlement.unknown,
        (context, ref) => LimitChecker.canCreateTrip(context, ref),
      );
      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });

    testWidgets('and for documents', (tester) async {
      final outcome = await attempt(
        tester,
        Entitlement.unknown,
        (context, ref) =>
            LimitChecker.canCreateDocument(context, ref, currentCount: 5),
      );
      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });

    testWidgets('and for templates', (tester) async {
      final outcome = await attempt(
        tester,
        Entitlement.unknown,
        (context, ref) =>
            LimitChecker.canCreateTemplate(context, ref, currentCount: 3),
      );
      expect(outcome.allowed, isTrue);
      expect(outcome.paywall, isFalse);
    });
  });

  group('the per-tier numbers themselves', () {
    testWidgets('an unresolved account is quoted no cap at all', (
      tester,
    ) async {
      // Null, so the caller falls back to its own default rather than to the
      // cheapest tier's number.
      expect(await filesPerDocument(tester, Entitlement.unknown), isNull);
    });

    testWidgets('a free account is quoted the free number', (tester) async {
      expect(await filesPerDocument(tester, Entitlement.free), 3);
    });

    testWidgets('a subscriber is quoted the premium number', (tester) async {
      expect(await filesPerDocument(tester, Entitlement.premium), 25);
    });
  });
}

/// A subscription state with nothing behind it - no repository, no network.
class _StubSubscription extends Subscription {
  _StubSubscription({required this.entitlement, required this.limits});

  final Entitlement entitlement;
  final SubscriptionLimits limits;

  @override
  SubscriptionState build() => SubscriptionState(
    entitlement: entitlement,
    limits: limits,
    isLoading: false,
  );
}
