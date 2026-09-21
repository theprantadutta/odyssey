import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/theme/app_theme.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:odyssey/src/features/subscription/presentation/widgets/limit_meter.dart';
import 'package:odyssey/src/features/subscription/presentation/widgets/pro_upsell_card.dart';

/// The rule both of these obey, written on [Entitlement.unknown] itself:
/// nothing that depends on the *absence* of Premium may act on an entitlement
/// that has not resolved. A subscriber whose status is still in flight must not
/// be asked to buy what they already have.
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

  const limits = SubscriptionLimits(free: free, premium: free);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Entitlement entitlement,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionProvider.overrideWith(
            () => _StubSubscription(entitlement: entitlement, limits: limits),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  group('LimitMeter.shouldShow', () {
    test('says nothing until two thirds of the cap is gone', () {
      // A five-document trip: quiet at two, speaks at four.
      expect(LimitMeter.shouldShow(count: 2, limit: 5), isFalse);
      expect(LimitMeter.shouldShow(count: 3, limit: 5), isFalse);
      expect(LimitMeter.shouldShow(count: 4, limit: 5), isTrue);
      expect(LimitMeter.shouldShow(count: 5, limit: 5), isTrue);
    });

    test('still speaks once the cap is full or over', () {
      expect(LimitMeter.shouldShow(count: 10, limit: 10), isTrue);
      expect(LimitMeter.shouldShow(count: 12, limit: 10), isTrue);
    });

    test('an unlimited cap is not a cap', () {
      // -1 is how the API says unlimited, and 0 is what an unloaded limit looks
      // like. Neither is something to draw a meter for.
      expect(LimitMeter.shouldShow(count: 900, limit: -1), isFalse);
      expect(LimitMeter.shouldShow(count: 900, limit: 0), isFalse);
    });

    test('an empty list says nothing', () {
      expect(LimitMeter.shouldShow(count: 0, limit: 5), isFalse);
    });
  });

  group('LimitMeter.remainingCopy', () {
    test('counts down, then stops, then admits being over', () {
      expect(LimitMeter.remainingCopy(count: 3, limit: 5),
          '2 left on the free plan.');
      expect(LimitMeter.remainingCopy(count: 4, limit: 5),
          'One left on the free plan.');
      expect(LimitMeter.remainingCopy(count: 5, limit: 5),
          'That is the last one on the free plan.');

      // Over the cap is a real state - a limit can be lowered, and an account
      // that was Premium keeps everything it made. A free account really was
      // sitting on seven trips against a cap of five.
      expect(LimitMeter.remainingCopy(count: 7, limit: 5),
          'That is more than the free plan holds.');
    });
  });

  group('the upsells are shown only to a known-free account', () {
    testWidgets('a meter is hidden while the entitlement is unknown', (
      tester,
    ) async {
      await pump(
        tester,
        const LimitMeter(LimitKind.documentsPerTrip, count: 5),
        entitlement: Entitlement.unknown,
      );
      expect(find.textContaining('Upgrade'), findsNothing);
      expect(find.textContaining('of 5'), findsNothing);
    });

    testWidgets('a meter is hidden from a subscriber', (tester) async {
      await pump(
        tester,
        const LimitMeter(LimitKind.documentsPerTrip, count: 5),
        entitlement: Entitlement.premium,
      );
      expect(find.textContaining('Upgrade'), findsNothing);
    });

    testWidgets('a meter shows the numbers to a free account', (tester) async {
      await pump(
        tester,
        const LimitMeter(LimitKind.documentsPerTrip, count: 4),
        entitlement: Entitlement.free,
      );
      expect(find.text('4 of 5'), findsOneWidget);
      expect(find.text('One left on the free plan.'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
    });

    testWidgets('a full cap says so plainly', (tester) async {
      await pump(
        tester,
        const LimitMeter(LimitKind.documentsPerTrip, count: 5),
        entitlement: Entitlement.free,
      );
      expect(find.text('That is the last one on the free plan.'), findsOneWidget);
    });

    testWidgets('over the cap does not claim to be the last one', (
      tester,
    ) async {
      await pump(
        tester,
        const LimitMeter(LimitKind.activeTrips, count: 7),
        entitlement: Entitlement.free,
      );
      expect(find.text('7 of 5'), findsOneWidget);
      expect(find.text('That is more than the free plan holds.'), findsOneWidget);
    });

    testWidgets('the card is hidden while the entitlement is unknown', (
      tester,
    ) async {
      await pump(tester, const ProUpsellCard(),
          entitlement: Entitlement.unknown);
      expect(find.text('See Pro'), findsNothing);
    });

    testWidgets('the card is hidden from a subscriber', (tester) async {
      await pump(tester, const ProUpsellCard(),
          entitlement: Entitlement.premium);
      expect(find.text('See Pro'), findsNothing);
    });

    testWidgets('the card is shown to a free account', (tester) async {
      await pump(tester, const ProUpsellCard(), entitlement: Entitlement.free);
      expect(find.text('See Pro'), findsOneWidget);
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
