import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';
import 'entitlement_state.dart';
import '../../../../core/session/account_session.dart';

part 'subscription_provider.g.dart';

/// Subscription state
///
/// [entitlement] is deliberately separate from [status] and is the only thing
/// feature gates and ad eligibility should read. It has three values, and the
/// third one matters: *unknown* is not *free*. Reading entitlement as
/// `status?.isPremium ?? false` meant that during startup, and after any failure
/// to load, a paying subscriber was treated as a free user and shown ads.
///
/// The supporting data — usage, limits, pricing — is loaded separately and may
/// be absent without affecting entitlement. Pricing in particular comes from the
/// store and fails on its own schedule; it used to be fetched in the same
/// `Future.wait` as the entitlement, so an unreachable store silently downgraded
/// the user.
class SubscriptionState {
  final SubscriptionStatus? status;
  final UsageInfo? usage;
  final SubscriptionLimits? limits;
  final PricingInfo? pricing;

  /// What is known about this account's entitlement.
  final Entitlement entitlement;

  /// Whether an entitlement load is in flight.
  final bool isLoading;

  /// Why the last entitlement load failed, if it did.
  final String? error;

  /// Why the last pricing load failed, if it did.
  ///
  /// Separate from [error] because it means something different to the user:
  /// prices cannot be shown, but their access is unaffected.
  final String? pricingError;

  const SubscriptionState({
    this.status,
    this.usage,
    this.limits,
    this.pricing,
    this.entitlement = Entitlement.unknown,
    this.isLoading = false,
    this.error,
    this.pricingError,
  });

  /// Whether the account is **known** to be Premium.
  bool get isPremium => entitlement.isPremium;

  /// Whether the account is **known** not to be Premium.
  bool get isKnownFree => entitlement.isKnownFree;

  /// Whether entitlement has been established at all.
  bool get isEntitlementResolved => entitlement.isResolved;

  SubscriptionTier get tier => status?.tier ?? SubscriptionTier.free;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    UsageInfo? usage,
    SubscriptionLimits? limits,
    PricingInfo? pricing,
    Entitlement? entitlement,
    bool? isLoading,
    String? error,
    String? pricingError,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      usage: usage ?? this.usage,
      limits: limits ?? this.limits,
      pricing: pricing ?? this.pricing,
      entitlement: entitlement ?? this.entitlement,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pricingError: pricingError,
    );
  }
}

/// Subscription repository provider
@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(Ref ref) {
  return SubscriptionRepository();
}

/// Subscription state notifier provider
@Riverpod(keepAlive: true)
class Subscription extends _$Subscription {
  late final SubscriptionRepository _repository;

  /// Counts entitlement answers applied, so a slower one cannot undo a newer one.
  int _statusSerial = 0;

  /// Issue-order of the newest server answer applied here.
  ///
  /// The repository refuses to publish or cache an answer older than one it has
  /// already accepted, which covers the stream. This covers the other half: an
  /// answer handed straight back from [SubscriptionRepository.getStatusFresh]
  /// or an uncached [SubscriptionRepository.getStatus], which the repository
  /// cannot withhold because the caller asked for it by name.
  int _appliedStatusSequence = SubscriptionStatusAnswer.unordered;

  @override
  SubscriptionState build() {
    _repository = ref.read(subscriptionRepositoryProvider);

    // The cached read answers first and the network answers second. Listening is
    // what makes the second answer count: without it the refresh reached the
    // database and stopped there, so an upgrade bought on another device - or a
    // subscription that lapsed - did not change what this screen was gating on
    // until something happened to read the cache again.
    final updates = _repository.statusUpdates.listen(_applyStatus);
    ref.onDispose(updates.cancel);

    // ...and again when a session opens.
    //
    // beginSession is started but not awaited when someone signs in, so the
    // session can open a moment *after* the auth state flips and after this
    // provider has already asked. The answer then comes back tagged to session
    // zero, the guard drops it as belonging to an account that has signed out,
    // and nothing writes it to the cache either - so a fresh install of a
    // Premium account showed Free, and kept showing Free on every launch,
    // because the cache it would have read on the next start was never filled.
    final sessions = AccountSession().opened.listen((_) => refresh());
    ref.onDispose(sessions.cancel);

    // Load subscription data after initialization
    Future.microtask(() => refresh());

    return const SubscriptionState(isLoading: true);
  }

  /// Records an entitlement answer, whichever path it arrived by.
  ///
  /// Returns whether it was applied. Anything issued before the newest answer
  /// already applied is refused: arrival order is not freshness, and a status
  /// read issued before a purchase completed answers `free` truthfully enough
  /// to take Premium away from somebody who has just paid for it. See
  /// `SubscriptionRepository._issueStatusRequest` for why the order is taken at
  /// the request rather than at the response.
  bool _applyStatus(SubscriptionStatusAnswer answer) {
    if (answer.sequence < _appliedStatusSequence) {
      AppLogger.info(
          'Ignored entitlement answer ${answer.sequence}; '
          '$_appliedStatusSequence is newer');
      return false;
    }

    _appliedStatusSequence = answer.sequence;
    _statusSerial++;

    final status = answer.status;

    state = state.copyWith(
      status: status,
      entitlement: status.isPremium ? Entitlement.premium : Entitlement.free,
      isLoading: false,
    );

    AppLogger.info('Entitlement resolved: ${state.entitlement.name}');

    unawaited(ref.read(analyticsServiceProvider).setUserProperty(
      name: 'subscription_tier',
      value: state.tier.name,
    ));

    return true;
  }

  /// Refresh all subscription data.
  ///
  /// Entitlement is loaded on its own and first. Everything else is supporting
  /// detail: useful, but not worth letting a failure in it decide whether
  /// somebody is a paying customer.
  Future<void> refresh() async {
    AppLogger.info('Refreshing subscription data...');
    state = state.copyWith(isLoading: true, error: null);

    await _loadEntitlement(fresh: false);
    await _loadSupportingData(fresh: false);
  }

  /// Loads the one thing that decides access.
  ///
  /// On failure the entitlement is left **as it was**, not reset to free. A
  /// network blip must not downgrade a subscriber; if nothing was known before,
  /// it stays unknown, and callers that need a definite answer wait rather than
  /// assume the cheaper one.
  Future<void> _loadEntitlement({required bool fresh}) async {
    final serial = _statusSerial;

    try {
      final answer =
          fresh ? await _repository.getStatusFresh() : await _repository.getStatus();

      // The guard applies to a *cached* read only.
      //
      // A background refresh started by this very read can answer before the
      // read itself returns. Its answer came from the server and is the newer
      // one, so a cached value must not be written over the top of it.
      //
      // A fresh read is not a cached value - it is a direct server answer, and
      // discarding it here threw away the one that matters most. The sequence:
      // the billing sheet closes, a resume-triggered refresh answers `free`
      // from cache and bumps the serial, and the forceRefresh carrying
      // `premium` is then dropped for being "stale". The customer has paid and
      // keeps seeing ads until the next refresh, which is throttled to once
      // every five minutes.
      //
      // Two *server* answers are ordered by when each request was issued, which
      // [_applyStatus] enforces. This guard stays for the cached read, which is
      // not a request at all and so has no place in that order.
      if (!fresh && _statusSerial != serial) {
        state = state.copyWith(isLoading: false);
        return;
      }

      if (!_applyStatus(answer)) {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      AppLogger.error('Failed to load entitlement: $e');

      // Note what is kept: a previously resolved entitlement survives. Only a
      // first load that fails leaves it unknown.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads usage, limits and pricing, none of which gate access.
  ///
  /// Each is allowed to fail on its own. Pricing comes from the store and is the
  /// most likely to; it used to share a `Future.wait` with the entitlement, so an
  /// unreachable store took the subscriber's Premium with it.
  Future<void> _loadSupportingData({required bool fresh}) async {
    try {
      final results = await Future.wait([
        fresh ? _repository.getUsageFresh() : _repository.getUsage(),
        fresh ? _repository.getLimitsFresh() : _repository.getLimits(),
      ]);

      state = state.copyWith(
        usage: results[0] as UsageInfo,
        limits: results[1] as SubscriptionLimits,
      );
    } catch (e) {
      AppLogger.error('Failed to load usage and limits: $e');
    }

    try {
      state = state.copyWith(
        pricing: await _repository.getPricing(),
        pricingError: null,
      );
    } catch (e) {
      // Reported separately: the user cannot see prices, but their access is
      // unaffected and nothing should suggest otherwise.
      AppLogger.error('Failed to load pricing: $e');
      state = state.copyWith(pricingError: e.toString());
    }
  }

  /// Force refresh from server, bypassing cache. Used after purchase/restore.
  Future<void> forceRefresh() async {
    AppLogger.info('Force-refreshing subscription data from server...');
    state = state.copyWith(isLoading: true, error: null);

    await _loadEntitlement(fresh: true);
    await _loadSupportingData(fresh: true);
  }

  /// Forgets what was known, for a change of account.
  ///
  /// Resetting to *unknown* rather than to free is the point: between signing out
  /// and the next account's entitlement arriving, the honest answer is that we do
  /// not know - and nothing should show ads, or Premium, on a guess.
  void resetForAccountChange() {
    // The answer order is forgotten with everything else. It ranks answers about
    // one account; the next account's cached status is not "older" than the
    // previous account's server answer, it is about a different question. An
    // answer still in flight for the account that left is stopped by the session
    // guard, not by this.
    _appliedStatusSequence = SubscriptionStatusAnswer.unordered;
    _statusSerial = 0;
    state = const SubscriptionState(entitlement: Entitlement.unknown, isLoading: true);
    Future.microtask(() => forceRefresh());
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Simple provider to check if user is premium
@Riverpod(keepAlive: true)
bool isPremium(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.isPremium;
}

/// What is known about the account's entitlement: unknown, free, or Premium.
///
/// Read this rather than [isPremiumProvider] wherever the *absence* of Premium
/// would cause something to happen - showing an ad, showing an upsell. `false`
/// from [isPremiumProvider] means "not known to be Premium", which during startup
/// is also true of every subscriber.
@Riverpod(keepAlive: true)
Entitlement entitlement(Ref ref) =>
    ref.watch(subscriptionProvider).entitlement;

/// Whether the account is **known** not to have Premium.
@Riverpod(keepAlive: true)
bool isKnownFree(Ref ref) => ref.watch(entitlementProvider).isKnownFree;

/// Provider for current tier
@Riverpod(keepAlive: true)
SubscriptionTier currentTier(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.tier;
}

/// Provider for usage info
@Riverpod(keepAlive: true)
UsageInfo? usageInfo(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.usage;
}

/// Provider for pricing info
@Riverpod(keepAlive: true)
PricingInfo? pricingInfo(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.pricing;
}
