import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/subscription/data/models/subscription_model.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/entitlement_state.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';

/// Whether an ad may be shown, expressed the way the provider expresses it.
///
/// Mirrors `adsEnabled`'s entitlement term. The real provider also weighs consent
/// and the grace period; this isolates the part that was wrong.
bool adsAllowed(SubscriptionState state) => state.isKnownFree;

void main() {
  const premiumStatus = SubscriptionStatus(
    tier: SubscriptionTier.premium,
    plan: SubscriptionPlan.monthly,
    isPremium: true,
  );

  const freeStatus = SubscriptionStatus(
    tier: SubscriptionTier.free,
    plan: SubscriptionPlan.free,
    isPremium: false,
  );

  group('the three states are distinct', () {
    test('unknown is not free', () {
      // The whole point. These used to be the same value, because entitlement
      // was read as `status?.isPremium ?? false`.
      expect(Entitlement.unknown.isPremium, isFalse);
      expect(Entitlement.unknown.isKnownFree, isFalse);
      expect(Entitlement.unknown.isResolved, isFalse);
    });

    test('free is resolved and not premium', () {
      expect(Entitlement.free.isPremium, isFalse);
      expect(Entitlement.free.isKnownFree, isTrue);
      expect(Entitlement.free.isResolved, isTrue);
    });

    test('premium is resolved and premium', () {
      expect(Entitlement.premium.isPremium, isTrue);
      expect(Entitlement.premium.isKnownFree, isFalse);
      expect(Entitlement.premium.isResolved, isTrue);
    });
  });

  group('slow startup', () {
    test('a fresh state is unknown, not free', () {
      const state = SubscriptionState(isLoading: true);

      expect(state.entitlement, Entitlement.unknown);
      expect(state.isEntitlementResolved, isFalse);
    });

    test('no ads are shown while entitlement is still loading', () {
      const state = SubscriptionState(isLoading: true);

      // A subscriber opening the app was shown ads until their status arrived,
      // because "not yet known to be premium" read as "free".
      expect(adsAllowed(state), isFalse);
    });

    test('ads begin only once the account is known to be free', () {
      const resolved = SubscriptionState(
        status: freeStatus,
        entitlement: Entitlement.free,
      );

      expect(adsAllowed(resolved), isTrue);
    });

    test('a resolved premium account never allows ads', () {
      const resolved = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      expect(adsAllowed(resolved), isFalse);
      expect(resolved.isPremium, isTrue);
    });
  });

  group('failures do not downgrade', () {
    test('an entitlement load failure leaves a known premium account premium', () {
      const resolved = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      // What the provider does on failure: set the error, keep the entitlement.
      final afterFailure = resolved.copyWith(
        isLoading: false,
        error: 'network unreachable',
      );

      expect(afterFailure.entitlement, Entitlement.premium);
      expect(adsAllowed(afterFailure), isFalse);
    });

    test('an entitlement load failure on first launch stays unknown', () {
      const fresh = SubscriptionState(isLoading: true);

      final afterFailure = fresh.copyWith(
        isLoading: false,
        error: 'network unreachable',
      );

      // Not free. Nothing that depends on the absence of Premium may act.
      expect(afterFailure.entitlement, Entitlement.unknown);
      expect(adsAllowed(afterFailure), isFalse);
    });

    test('a pricing failure does not touch entitlement', () {
      const resolved = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      // Pricing comes from the store and fails on its own schedule. It used to
      // share a Future.wait with the entitlement, so an unreachable store
      // silently downgraded the subscriber.
      final afterPricingFailure = resolved.copyWith(
        pricingError: 'store unreachable',
      );

      expect(afterPricingFailure.entitlement, Entitlement.premium);
      expect(afterPricingFailure.pricingError, isNotNull);
      expect(afterPricingFailure.error, isNull);
      expect(adsAllowed(afterPricingFailure), isFalse);
    });

    test('a pricing failure on a free account still allows ads', () {
      const resolved = SubscriptionState(
        status: freeStatus,
        entitlement: Entitlement.free,
      );

      final afterPricingFailure =
          resolved.copyWith(pricingError: 'store unreachable');

      // The free user's experience is unchanged by not knowing the price of an
      // upgrade they were not buying.
      expect(adsAllowed(afterPricingFailure), isTrue);
      expect(afterPricingFailure.entitlement, Entitlement.free);
    });

    test('usage and limits failing does not touch entitlement', () {
      const resolved = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      // Usage and limits are supporting detail: absent, the app shows less, but
      // it does not decide somebody stopped paying.
      expect(resolved.usage, isNull);
      expect(resolved.limits, isNull);
      expect(resolved.entitlement, Entitlement.premium);
    });
  });

  group('offline', () {
    test('cached premium keeps working offline', () {
      // The cache is what a subscriber falls back on with no network.
      const cached = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      expect(cached.isPremium, isTrue);
      expect(adsAllowed(cached), isFalse);
    });

    test('offline with nothing cached is unknown, not free', () {
      // The repository throws SubscriptionStatusUnavailable rather than
      // returning a fabricated free status, so the provider keeps unknown.
      const state = SubscriptionState(isLoading: true);
      final afterUnavailable = state.copyWith(isLoading: false);

      expect(afterUnavailable.entitlement, Entitlement.unknown);
      expect(adsAllowed(afterUnavailable), isFalse);
    });
  });

  group('expiry, restore and account changes', () {
    test('expiry moves premium to free', () {
      const before = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      final after = before.copyWith(
        status: freeStatus,
        entitlement: Entitlement.free,
      );

      expect(after.isPremium, isFalse);
      expect(adsAllowed(after), isTrue);
    });

    test('a restore moves free to premium', () {
      const before = SubscriptionState(
        status: freeStatus,
        entitlement: Entitlement.free,
      );

      final after = before.copyWith(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      expect(after.isPremium, isTrue);
      expect(adsAllowed(after), isFalse);
    });

    test('switching accounts passes through unknown, never through free', () {
      const premium = SubscriptionState(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );

      // Signing out rebuilds the provider, which starts here.
      const duringSwitch = SubscriptionState(isLoading: true);

      expect(duringSwitch.entitlement, Entitlement.unknown);

      // Crucially, the previous account's Premium is not carried into the gap,
      // and neither is a guess that the next one is free.
      expect(duringSwitch.isPremium, isFalse);
      expect(adsAllowed(duringSwitch), isFalse);

      final nextAccount = duringSwitch.copyWith(
        status: freeStatus,
        entitlement: Entitlement.free,
      );

      expect(nextAccount.isPremium, isFalse);
      expect(adsAllowed(nextAccount), isTrue);
      expect(premium.isPremium, isTrue, reason: 'the old state is untouched');
    });

    test('a free account switching to a premium one stops ads', () {
      const free = SubscriptionState(
        status: freeStatus,
        entitlement: Entitlement.free,
      );
      expect(adsAllowed(free), isTrue);

      const duringSwitch = SubscriptionState(isLoading: true);
      expect(adsAllowed(duringSwitch), isFalse);

      final premium = duringSwitch.copyWith(
        status: premiumStatus,
        entitlement: Entitlement.premium,
      );
      expect(adsAllowed(premium), isFalse);
    });
  });
}
