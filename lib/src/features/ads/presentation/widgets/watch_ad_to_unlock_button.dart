import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../application/reward_offer_controller.dart';
import '../providers/ads_providers.dart';

/// A "watch a short ad to unlock for 24 hours" button for free users.
///
/// Renders nothing unless [rewardedAdsEnabledProvider] is true, so premium users
/// (and unsupported platforms) never see it. It is deliberately gated on the
/// rewarded-specific provider rather than the master [adsEnabledProvider]: this
/// is an opt-in trial of a premium feature, so it stays available during the
/// new-user grace period when passive ad formats are suppressed.
///
/// It also hides itself when the server cannot deliver a reward at all, and when
/// nobody is signed in to grant one to. Showing an ad for a reward that cannot
/// arrive is the one outcome worse than not offering it.
///
/// This widget grants nothing itself. The **server** records the offer before the
/// ad is shown and the **ad network** confirms the reward to the server
/// afterwards; all this does is wait, and say honestly where things stand.
class WatchAdToUnlockButton extends ConsumerStatefulWidget {
  const WatchAdToUnlockButton({
    super.key,
    required this.feature,
    this.onUnlocked,
  });

  final PremiumFeature feature;
  final VoidCallback? onUnlocked;

  @override
  ConsumerState<WatchAdToUnlockButton> createState() =>
      _WatchAdToUnlockButtonState();
}

class _WatchAdToUnlockButtonState extends ConsumerState<WatchAdToUnlockButton> {
  RewardOfferState _state = RewardOfferState.ready;

  /// Null until the server answers — *unknown*, not *no*.
  ///
  /// Hiding on unknown would blank the button on every cold start; showing on
  /// unknown for one request is the lesser fault, and the offer call resolves it
  /// before any ad is loaded.
  bool? _fulfilmentConfigured;

  RewardOfferController get _controller =>
      ref.read(rewardOfferControllerProvider);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Warm up a rewarded ad so it's ready by the time the user taps.
      ref.read(rewardedAdManagerProvider).preload();

      final configured = await _controller.refreshAvailability();
      if (mounted) setState(() => _fulfilmentConfigured = configured);
    });
  }

  bool get _busy =>
      _state == RewardOfferState.showing ||
      _state == RewardOfferState.pendingConfirmation;

  Future<void> _watch() async {
    final messenger = ScaffoldMessenger.of(context);

    // Should be unreachable: the button hides itself without an account. Checked
    // anyway, because showing an ad and then having nobody to grant the reward to
    // is the one outcome worse than not offering it.
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    setState(() => _state = RewardOfferState.showing);

    final attempt = await _controller.watchFor(
      userId: userId,
      featureKey: widget.feature.serverKey,
    );

    if (!mounted) return;

    setState(() {
      _state = attempt.state;
      if (attempt.state == RewardOfferState.setupUnavailable) {
        _fulfilmentConfigured = false;
      }
    });

    switch (attempt.state) {
      case RewardOfferState.setupUnavailable:
        // The button is about to disappear, so no snackbar: an explanation the
        // user can do nothing with, attached to a control that is going away.
        return;

      case RewardOfferState.adUnavailable:
        messenger.showSnackBar(const SnackBar(
          content: Text('Ad not ready yet — please try again in a moment.'),
        ));
        return;

      case RewardOfferState.confirmationFailed:
        // Earned, and *not lost*: it is recorded and will be picked up on the
        // next refresh. Saying "failed" would be untrue and would invite the user
        // to watch a second ad for something they already have coming.
        messenger.showSnackBar(const SnackBar(
          content: Text(
            'Thanks for watching. Your unlock is still on its way — '
            'it will appear shortly.',
          ),
        ));
        return;

      case RewardOfferState.confirmed:
        final analytics = ref.read(analyticsServiceProvider);
        unawaited(analytics.trackRewardedEarned(
          featureName: widget.feature.storageKey,
        ));

        if (attempt.grants != null) {
          await ref
              .read(temporaryUnlocksProvider.notifier)
              .applyGrants(attempt.grants!);
        }

        if (!mounted) return;

        unawaited(analytics.trackTemporaryUnlock(
          featureName: widget.feature.storageKey,
          hours: kTemporaryUnlockDuration.inHours,
        ));

        widget.onUnlocked?.call();
        return;

      case RewardOfferState.ready:
      case RewardOfferState.showing:
      case RewardOfferState.pendingConfirmation:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(rewardedAdsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    // The grant is bound to an account, so an offer with nobody to grant it to
    // cannot be fulfilled.
    if (ref.watch(authProvider).user?.id == null) return const SizedBox.shrink();

    // Explicitly false, not merely "not true": while it is unknown the offer
    // stands, because the offer call itself will settle the question before any
    // ad is loaded.
    if (_fulfilmentConfigured == false) return const SizedBox.shrink();

    return PillButton(
      label: _label,
      style: PillStyle.outline,
      icon: _busy ? null : Icons.play_circle_outline,
      isLoading: _busy,
      onPressed: _busy ? null : _watch,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space14),
    );
  }

  String get _label => switch (_state) {
        RewardOfferState.showing => 'Loading ad…',
        RewardOfferState.pendingConfirmation => 'Unlocking…',
        RewardOfferState.confirmationFailed => 'Unlock on its way…',
        _ => 'Watch a short ad to unlock for '
            '${kTemporaryUnlockDuration.inHours} hours',
      };
}
