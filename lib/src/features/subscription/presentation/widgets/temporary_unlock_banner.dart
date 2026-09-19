import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../common/theme/app_typography.dart';
import '../providers/feature_access_provider.dart';

/// Tells the user how long their earned unlock has left.
///
/// A temporary unlock that looks identical to Premium is a small deception: the
/// feature simply stops working a day later with no warning. Showing the time
/// remaining is the difference between "it broke" and "it ran out, as it said it
/// would".
///
/// Renders nothing for a Premium subscriber or for a feature that is not
/// currently unlocked by a grant, so it can be placed unconditionally.
class TemporaryUnlockBanner extends ConsumerStatefulWidget {
  const TemporaryUnlockBanner({super.key, required this.feature});

  final PremiumFeature feature;

  @override
  ConsumerState<TemporaryUnlockBanner> createState() =>
      _TemporaryUnlockBannerState();
}

class _TemporaryUnlockBannerState extends ConsumerState<TemporaryUnlockBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();

    // The remaining time changes with the clock, not with any event, so nothing
    // else would ever rebuild this. A minute is the finest granularity the label
    // shows, so anything faster is wasted work.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref.watch(unlockRemainingProvider(widget.feature));
    if (remaining == null) return const SizedBox.shrink();

    final t = context.odyssey;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.space12,
        ),
        child: GlassBar(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: t.ink2),
              const SizedBox(width: AppSizes.space10),
              Expanded(
                child: Text(
                  '${widget.feature.displayName} unlocked — '
                  '${_describe(remaining)} left',
                  style: AppTypography.legend.copyWith(color: t.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A rounded, readable duration rather than a countdown.
  ///
  /// "23 hours left" is what the user wants to know. A ticking clock would
  /// suggest a precision the expiry does not have - the server decides it, and
  /// the two clocks are not the same one.
  static String _describe(Duration remaining) {
    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    final minutes = remaining.inMinutes;
    if (minutes >= 1) {
      return minutes == 1 ? '1 minute' : '$minutes minutes';
    }

    return 'less than a minute';
  }
}
