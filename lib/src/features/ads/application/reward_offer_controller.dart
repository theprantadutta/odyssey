import 'dart:async';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../../subscription/data/repositories/feature_grant_repository.dart';
import 'pending_reward_store.dart';
import 'rewarded_ad_manager.dart';

/// Where a watch-to-unlock offer stands.
///
/// These are deliberately distinct rather than collapsed into "loading" and
/// "done". Each one means something different to the user and deserves a
/// different thing said to them:
///
/// * [setupUnavailable] — this build cannot deliver rewards at all. Do not offer.
/// * [adUnavailable] — no ad filled right now. Worth trying again shortly.
/// * [ready] — an offer can be made.
/// * [showing] — the ad is on screen.
/// * [pendingConfirmation] — watched, and the reward is travelling to us.
/// * [confirmed] — the server has granted it.
/// * [confirmationFailed] — earned, but not confirmed yet. **Not lost.**
enum RewardOfferState {
  setupUnavailable,
  adUnavailable,
  ready,
  showing,
  pendingConfirmation,
  confirmed,
  confirmationFailed,
}

/// The outcome of one watch-to-unlock attempt.
class RewardAttempt {
  const RewardAttempt(this.state, {this.grants});

  final RewardOfferState state;

  /// The server's grants, when the reward was confirmed.
  final FeatureGrants? grants;

  bool get isConfirmed => state == RewardOfferState.confirmed;
}

/// Runs one watch-to-unlock attempt end to end.
///
/// The order matters and is the point of this class: the offer is recorded on the
/// server **before** the ad is shown. An ad watched without an offer earns
/// nothing, so it must never be shown first and reconciled afterwards.
class RewardOfferController {
  RewardOfferController({
    required RewardedAdManager adManager,
    FeatureGrantRepository? repository,
    PendingRewardStore? pendingStore,
  })  : _ads = adManager,
        _repository = repository ?? FeatureGrantRepository(),
        _pending = pendingStore ?? PendingRewardStore();

  final RewardedAdManager _ads;
  final FeatureGrantRepository _repository;
  final PendingRewardStore _pending;

  /// Whether this deployment can deliver rewards, once known.
  ///
  /// Starts null - *unknown*, not *no*. Treating unknown as no would hide the
  /// offer on every cold start before the first response arrives.
  bool? _fulfilmentConfigured;

  bool? get fulfilmentConfigured => _fulfilmentConfigured;

  /// Asks the server whether rewards can be delivered at all.
  Future<bool?> refreshAvailability() async {
    final configured = await _repository.fetchFulfilmentConfigured();
    if (configured != null) _fulfilmentConfigured = configured;
    return _fulfilmentConfigured;
  }

  /// Watches an ad for [featureKey] and returns where it ended up.
  Future<RewardAttempt> watchFor({
    required String userId,
    required String featureKey,
  }) async {
    // 1. Record the offer first. This is what binds the account, the feature and
    //    the ad unit on the server side; everything after it is just delivery.
    final offer = await _repository.createOffer(
      feature: featureKey,
      adUnitId: AdMobConfig.rewardedAdUnitId,
    );

    if (!offer.isSuccess) {
      switch (offer.refusal!) {
        case OfferRefusal.notConfigured:
          _fulfilmentConfigured = false;
          return const RewardAttempt(RewardOfferState.setupUnavailable);

        case OfferRefusal.alreadyEntitled:
          // Nothing to watch an ad for. Treated as success so the caller opens
          // the feature rather than reporting a failure the user cannot act on.
          final grants = await _safeGrants();
          return RewardAttempt(RewardOfferState.confirmed, grants: grants);

        case OfferRefusal.refused:
        case OfferRefusal.unavailable:
          return const RewardAttempt(RewardOfferState.adUnavailable);
      }
    }

    _fulfilmentConfigured = true;
    final intentId = offer.offer!.intentId;

    // 2. Show the ad, carrying the intent id and nothing else that matters.
    final earned = await _ads.showRewarded(
      userId: userId,
      intentId: intentId,
    );

    if (!earned) {
      // Nothing was earned, so there is nothing to chase. The offer is left to
      // expire on its own.
      return const RewardAttempt(RewardOfferState.adUnavailable);
    }

    // 3. Recorded before the wait, not after. If the app dies while waiting, the
    //    user still earned this and it must survive to be resolved later.
    await _pending.add(
      userId,
      PendingReward(
        feature: featureKey,
        intentId: intentId,
        earnedAt: DateTime.now().toUtc(),
      ),
    );

    // 4. Wait, briefly and finitely, for the reward to reach us through the ad
    //    network. A spinner with no end is not an option: the delay is outside
    //    this app's control and can exceed any reasonable wait.
    final grants = await _repository.awaitGrant(featureKey);

    if (grants == null) {
      return const RewardAttempt(RewardOfferState.confirmationFailed);
    }

    await _pending.remove(userId, intentId);
    return RewardAttempt(RewardOfferState.confirmed, grants: grants);
  }

  /// Resolves rewards earned earlier whose grants had not arrived yet.
  ///
  /// Run on resume and after sign-in. This is what turns "your unlock is taking a
  /// moment" into an unlock that actually appears, without the user having to
  /// watch another ad for something they already earned.
  Future<FeatureGrants?> resolvePending(String userId) async {
    final pending = await _pending.load(userId);
    if (pending.isEmpty) return null;

    FeatureGrants? grants;
    try {
      grants = await _repository.fetchGrants();
    } catch (e) {
      AppLogger.debug('Could not resolve pending rewards: $e');
      return null;
    }

    for (final reward in pending) {
      final arrived = grants.grants.any((g) =>
          g.feature == reward.feature && g.expiresAt.isAfter(grants!.serverTime));

      if (arrived) {
        await _pending.remove(userId, reward.intentId);
        AppLogger.info('A pending reward for ${reward.feature} has arrived');
      }
    }

    return grants;
  }

  Future<FeatureGrants?> _safeGrants() async {
    try {
      return await _repository.fetchGrants();
    } catch (_) {
      return null;
    }
  }
}
