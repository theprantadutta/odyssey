import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/walkthrough_step_model.dart';

/// Styled tooltip card that matches the Odyssey app design.
/// Shows icon, title, description, step indicators, and navigation buttons.
class WalkthroughTooltip extends StatelessWidget {
  final WalkthroughStep step;
  final int currentIndex;
  final int totalSteps;
  final bool isAbove;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const WalkthroughTooltip({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.isAbove,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLastStep = currentIndex == totalSteps - 1;
    final isFirstStep = currentIndex == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: AppSizes.strongShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arrow pointing toward target (if tooltip is above)
          if (isAbove) _buildArrow(colorScheme, pointing: _ArrowDirection.down),

          Padding(
            padding: const EdgeInsets.all(AppSizes.space20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + Title row
                Row(
                  children: [
                    // Colored icon circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: step.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Icon(
                        step.icon,
                        color: step.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    // Title
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppTypography.headlineSmall.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space12),

                // Description
                Text(
                  step.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSizes.space20),

                // Bottom row: dots + buttons
                Row(
                  children: [
                    // Step indicator dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(totalSteps, (index) {
                        final isActive = index == currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? step.accentColor
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    // Skip button
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.space8),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        'Skip',
                        style: AppTypography.labelMedium.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // Back button (if not first step)
                    if (!isFirstStep) ...[
                      const SizedBox(width: AppSizes.space4),
                      TextButton(
                        onPressed: onPrevious,
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.space8),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          'Back',
                          style: AppTypography.labelMedium.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSizes.space4),
                    // Next / Got it! button
                    FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sunnyYellow,
                        foregroundColor: AppColors.charcoal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space16,
                          vertical: AppSizes.space8,
                        ),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                        ),
                      ),
                      child: Text(
                        isLastStep ? 'Got it!' : 'Next',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrow pointing toward target (if tooltip is below)
          if (!isAbove) _buildArrow(colorScheme, pointing: _ArrowDirection.up),
        ],
      ),
    );
  }

  Widget _buildArrow(ColorScheme colorScheme, {required _ArrowDirection pointing}) {
    return Align(
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(20, 10),
        painter: _ArrowPainter(
          color: colorScheme.surface,
          pointing: pointing,
        ),
      ),
    );
  }
}

enum _ArrowDirection { up, down }

class _ArrowPainter extends CustomPainter {
  final Color color;
  final _ArrowDirection pointing;

  _ArrowPainter({required this.color, required this.pointing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointing == _ArrowDirection.up) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointing != pointing;
}
