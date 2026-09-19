import 'package:flutter/material.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/walkthrough_step_model.dart';

/// The coach mark that sits beside a highlighted control.
///
/// [WalkthroughStep.accentColor] is ignored. The steps each carried their own
/// colour under the old palette; this system has one accent, and six different
/// tints on six consecutive tooltips is exactly what it exists to stop.
class WalkthroughTooltip extends StatelessWidget {
  const WalkthroughTooltip({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.isAbove,
  });

  final WalkthroughStep step;
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  /// True when the tooltip sits above its target, so the arrow points down.
  final bool isAbove;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final isLast = currentIndex == totalSteps - 1;
    final isFirst = currentIndex == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAbove) _Arrow(pointingDown: true, color: t.sheet),

          Container(
            padding: const EdgeInsets.all(AppSizes.space20),
            decoration: BoxDecoration(
              color: Color.alphaBlend(t.sheet, t.canvas),
              borderRadius: BorderRadius.circular(AppSizes.radiusTile),
              border: Border.all(color: t.hairlineStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChip(
                      icon: step.icon,
                      size: 44,
                      radius: AppSizes.radiusChip,
                      iconSize: AppSizes.iconLg,
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppTypography.cardTitleLarge.copyWith(
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  step.description,
                  style: AppTypography.subtitle.copyWith(color: t.ink2),
                ),
                const SizedBox(height: AppSizes.space20),

                Row(
                  children: [
                    StepDots(count: totalSteps, index: currentIndex),
                    const Spacer(),
                    _TextAction(label: 'Skip', onTap: onSkip),
                    if (!isFirst) ...[
                      const SizedBox(width: AppSizes.space10),
                      _TextAction(label: 'Back', onTap: onPrevious),
                    ],
                    const SizedBox(width: AppSizes.space10),
                    PillButton(
                      label: isLast ? 'Got it' : 'Next',
                      expand: false,
                      onPressed: onNext,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space18,
                        vertical: AppSizes.space10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!isAbove) _Arrow(pointingDown: false, color: t.sheet),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space6,
          vertical: AppSizes.space6,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(color: t.ink3),
        ),
      ),
    );
  }
}

/// The little triangle that ties the tooltip to whatever it is pointing at.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.pointingDown, required this.color});

  final bool pointingDown;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(
        pointingDown: pointingDown,
        color: Color.alphaBlend(t.sheet, t.canvas),
        border: t.hairlineStrong,
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.pointingDown,
    required this.color,
    required this.border,
  });

  final bool pointingDown;
  final Color color;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointingDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.hairlineWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.pointingDown != pointingDown || old.color != color;
}
