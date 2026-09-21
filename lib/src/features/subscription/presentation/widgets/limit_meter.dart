import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/subscription_model.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';

/// One of the caps a free account works inside.
///
/// The limit itself is not spelled out here - it comes from the server, so the
/// app never has a second, drifting copy of the numbers.
enum LimitKind {
  activeTrips('Trips', 'Active trips'),
  documentsPerTrip('Documents', 'Documents per trip'),
  memoriesPerTrip('Memories', 'Memories per trip'),
  templates('Templates', 'Templates');

  const LimitKind(this.label, this.featureName);

  /// The eyebrow above the meter.
  final String label;

  /// What the paywall says the user was reaching for.
  final String featureName;

  int valueFrom(TierLimits limits) => switch (this) {
        LimitKind.activeTrips => limits.activeTrips,
        LimitKind.documentsPerTrip => limits.documentsPerTrip,
        LimitKind.memoriesPerTrip => limits.memoriesPerTrip,
        LimitKind.templates => limits.templates,
      };
}

/// Says how much of a free plan's cap is left, shortly before it runs out.
///
/// The app already stops a free account at the cap, with a paywall carrying the
/// numbers. What it did not do was say anything beforehand: somebody filling in
/// a trip met the wall mid-task, having had no idea it was coming. This is the
/// warning - shown where the thing being capped actually lives, and only once
/// the cap is close enough to be worth mentioning.
///
/// It renders nothing at all unless the account is **known** to be free. Not
/// `!isPremium`: an entitlement that has not resolved yet is neither, and
/// treating it as free is how a paying subscriber gets asked to upgrade.
class LimitMeter extends ConsumerWidget {
  const LimitMeter(this.kind, {super.key, required this.count});

  final LimitKind kind;
  final int count;

  /// How full a cap has to be before it is worth saying anything.
  ///
  /// Two thirds. Lower nags - a fresh account would meet this on its second
  /// trip - and higher leaves no room to act: at 90% of a five-item cap there
  /// is nothing left to warn about.
  static const double threshold = 2 / 3;

  /// Whether a cap of [limit] with [count] used is worth showing.
  ///
  /// A negative or zero limit means there is no cap, which is how the API says
  /// 'unlimited' and also what an unloaded limit looks like; neither is
  /// something to draw a meter for.
  static bool shouldShow({required int count, required int limit}) {
    if (limit <= 0) return false;
    if (count <= 0) return false;
    return count / limit >= threshold;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The gate, before anything else is even read.
    if (!ref.watch(isKnownFreeProvider)) return const SizedBox.shrink();

    final limits = ref.watch(
      subscriptionProvider.select((s) => s.limits?.free),
    );
    if (limits == null) return const SizedBox.shrink();

    final limit = kind.valueFrom(limits);
    if (!shouldShow(count: count, limit: limit)) return const SizedBox.shrink();

    final t = context.odyssey;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space12),
      child: OdysseyCard(
        radius: AppSizes.radiusTile,
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: EyebrowLabel(kind.label)),
                Text(
                  '$count of $limit',
                  style: AppTypography.numeral.copyWith(color: t.ink),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space12),
            ProgressTrack(value: count / limit),
            const SizedBox(height: AppSizes.space12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    remainingCopy(count: count, limit: limit),
                    style: AppTypography.rowMeta.copyWith(color: t.ink3),
                  ),
                ),
                const SizedBox(width: AppSizes.space10),
                Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PaywallUtils.showPaywall(
                      context,
                      featureName: kind.featureName,
                    );
                  },
                  borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                  semanticLabel: 'Upgrade to Pro',
                  child: Text(
                    'Upgrade to Pro',
                    style: AppTypography.buttonSmall.copyWith(
                      color: t.limeText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Plain about what is left, including when the answer is none or less.
  ///
  /// Over the cap is a real state, not a rounding error: a limit can be lowered,
  /// and an account that was Premium keeps everything it made. Saying "that is
  /// the last one" to somebody holding seven of five is simply untrue.
  static String remainingCopy({required int count, required int limit}) {
    if (count > limit) return 'That is more than the free plan holds.';
    if (count == limit) return 'That is the last one on the free plan.';
    if (limit - count == 1) return 'One left on the free plan.';
    return '${limit - count} left on the free plan.';
  }
}
