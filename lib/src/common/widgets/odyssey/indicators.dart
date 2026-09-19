import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'buttons.dart';
import 'chips.dart';
import 'pressable.dart';
import 'surfaces.dart';

/// A rounded progress bar.
///
/// On a lime hero tile pass the on-lime pair explicitly — the tile's fill is
/// the same colour the bar would otherwise use:
///
/// ```dart
/// ProgressTrack(
///   value: packedFraction,
///   trackColor: AppColors.onAccentTrack,
///   fillColor: AppColors.onAccent,
/// )
/// ```
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    this.height = AppSizes.progressHeight,
    this.trackColor,
    this.fillColor,
  });

  /// 0–1. Values outside the range are clamped.
  final double value;

  final double height;
  final Color? trackColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final fraction = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: trackColor ?? t.track,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction,
          child: AnimatedContainer(
            duration: AppSizes.durationState,
            curve: AppSizes.curveState,
            decoration: BoxDecoration(
              color: fillColor ?? t.action,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
          ),
        ),
      ),
    );
  }
}

/// One slice of a [SegmentedBar].
class BarSegment {
  const BarSegment({required this.label, required this.value, this.color});

  final String label;
  final double value;

  /// Defaults to the matching tone of the theme's 4-tone data ramp.
  final Color? color;

  /// Folds a list down to at most four slices, rolling the tail into one.
  ///
  /// The ramp has four tones and wraps, so a fifth category comes back round
  /// to the first and two legend swatches end up identical. Rolling the tail
  /// up keeps every swatch distinct and the total honest.
  static List<BarSegment> capped(
    List<BarSegment> segments, {
    int max = 4,
    String tailLabel = 'Other',
  }) {
    if (segments.length <= max) return segments;

    final head = segments.take(max - 1).toList();
    final tail = segments.skip(max - 1);
    return [
      ...head,
      BarSegment(
        label: tailLabel,
        value: tail.fold<double>(0, (sum, s) => sum + s.value),
      ),
    ];
  }
}

/// The multi-tone category bar used by the spend panel and the budget total —
/// a row of rounded slices sized by share, with a 3px gap between them.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    super.key,
    required this.segments,
    this.height = AppSizes.spendBarHeight,
    this.gap = 3,
  });

  final List<BarSegment> segments;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return ProgressTrack(value: 0, height: height);
    }

    return SizedBox(
      height: height,
      child: Row(
        // Stretch, not the default centre: a DecoratedBox with no child gets
        // loose constraints from a centred Row and collapses to nothing, which
        // is exactly how this bar went missing.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              // `flex` wants an int, so shares are scaled up before rounding
              // to keep small categories from collapsing to zero width.
              flex: (segments[i].value / total * 10000).round().clamp(1, 10000),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: segments[i].color ?? t.rampAt(i),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The wrapping legend that sits under a [SegmentedBar]: a small rounded
/// swatch plus a label.
class BarLegend extends StatelessWidget {
  const BarLegend({super.key, required this.segments});

  final List<BarSegment> segments;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Wrap(
      spacing: AppSizes.space16,
      runSpacing: AppSizes.space10,
      children: [
        for (var i = 0; i < segments.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: segments[i].color ?? t.rampAt(i),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSizes.space6),
              Text(
                segments[i].label,
                style: AppTypography.legend.copyWith(color: t.ink2),
              ),
            ],
          ),
      ],
    );
  }
}

/// The statistics bar chart: a flex row of bars scaled to the largest value,
/// with the peak picked out in the action colour.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 112,
    this.gap = AppSizes.space6,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    if (values.isEmpty) return const SizedBox.shrink();

    final peak = values.reduce((a, b) => a > b ? a : b);
    final idleColor = t.isDark
        ? const Color(0x29FFFFFF)
        : const Color(0x1F0A0B0D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppSizes.durationPanel,
                    curve: AppSizes.curveState,
                    height: peak <= 0
                        ? 2
                        : (values[i] / peak * height).clamp(2.0, height),
                    decoration: BoxDecoration(
                      color: values[i] == peak ? t.action : idleColor,
                      borderRadius: BorderRadius.circular(AppSizes.radiusBar),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTypography.microLabel.copyWith(
                    color: i < values.length && values[i] == peak
                        ? t.limeText
                        : t.ink3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The three-bar progress indicator on the onboarding screen: the active step
/// is a wide lime bar, the rest are short neutral ones.
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final idle = t.isDark
        ? const Color(0x2EFFFFFF)
        : const Color(0x240A0B0D);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.space6),
          AnimatedContainer(
            duration: AppSizes.durationState,
            curve: AppSizes.curveState,
            width: i == index ? 26 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: i == index ? AppColors.accent : idle,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
          ),
        ],
      ],
    );
  }
}

/// A loading placeholder: a block in the card colour at the real component's
/// radius, pulsing between 0.4 and 0.7 opacity over 1.2s.
///
/// The design permits no spinners outside button submit, so lists and cards
/// load as skeletons shaped like the thing that is coming.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppSizes.radiusChipXs,
  });

  /// A skeleton shaped like a list row.
  const Skeleton.row({super.key})
      : width = double.infinity,
        height = 74,
        radius = AppSizes.radiusRow;

  /// A skeleton shaped like a feature tile.
  const Skeleton.tile({super.key, this.height = 150})
      : width = double.infinity,
        radius = AppSizes.radiusTile;

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSizes.durationPulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (reduceMotion) {
      return Opacity(opacity: 0.55, child: block);
    }

    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.7).animate(_controller),
      child: block,
    );
  }
}

/// The empty-state pattern: a one-line explanation in [OdysseyTokens.ink3]
/// above a dashed affordance.
class OdysseyEmptyState extends StatelessWidget {
  const OdysseyEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.rowMeta.copyWith(color: t.ink3),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSizes.space14),
          PillButton(
            label: actionLabel!,
            onPressed: onAction,
            style: PillStyle.dashed,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ],
      ],
    );
  }
}

/// The error-state pattern. There is no red in this palette, so failure is
/// signalled with copy on an ordinary card plus a text action.
class OdysseyErrorState extends StatelessWidget {
  const OdysseyErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return OdysseyCard(
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel('Something went wrong'),
          const SizedBox(height: AppSizes.space10),
          Text(message, style: AppTypography.subtitle.copyWith(color: t.ink)),
          if (onRetry != null) ...[
            const SizedBox(height: AppSizes.space14),
            Pressable(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
              child: Text(
                retryLabel,
                style: AppTypography.buttonSmall.copyWith(color: t.limeText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact stat card: a display numeral over a small label. Three of these
/// sit in the trip detail stat row.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;

  /// Fills with lime in both themes — the "82% ready" tile.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final fg = highlight ? AppColors.onAccent : t.ink;
    final labelColor = highlight ? AppColors.onAccent2 : t.ink3;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space14),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accent : t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusRow),
        border: highlight ? null : Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.statSmall.copyWith(color: fg),
            maxLines: 1,
          ),
          const SizedBox(height: AppSizes.space6),
          Text(
            label,
            style: AppTypography.statLabel.copyWith(color: labelColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
