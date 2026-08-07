import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../providers/ads_providers.dart';

/// A "watch a short ad to unlock for 24 hours" button for free users.
///
/// Renders nothing unless [rewardedAdsEnabledProvider] is true, so premium users
/// (and unsupported platforms) never see it. It is deliberately gated on the
/// rewarded-specific provider rather than the master [adsEnabledProvider]: this
/// is an opt-in trial of a premium feature, so it stays available during the
/// new-user grace period when passive ad formats are suppressed.
///
/// On a completed rewarded view it grants a
/// [kTemporaryUnlockDuration] unlock for [feature] and invokes [onUnlocked]
/// (typically used to pop the paywall / refresh the gated screen).
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Warm up a rewarded ad so it's ready by the time the user taps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(rewardedAdManagerProvider).preload();
    });
  }

  Future<void> _watch() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    final earned = await ref.read(rewardedAdManagerProvider).showRewarded();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!earned) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ad not ready yet — please try again in a moment.'),
        ),
      );
      return;
    }

    await ref.read(temporaryUnlocksProvider.notifier).unlock(widget.feature);
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.trackRewardedEarned(featureName: widget.feature.storageKey),
    );
    unawaited(
      analytics.trackTemporaryUnlock(
        featureName: widget.feature.storageKey,
        hours: kTemporaryUnlockDuration.inHours,
      ),
    );
    if (!mounted) return;
    widget.onUnlocked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(rewardedAdsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _watch,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: AppColors.sunnyYellow, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.space12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
        ),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.sunnyYellow,
                ),
              )
            : const Icon(Icons.play_circle_outline, size: 20),
        label: Text(
          _busy ? 'Loading ad…' : 'Watch a short ad to unlock for 24 hours',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
