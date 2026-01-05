import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';

/// A badge indicating premium status
class PremiumBadge extends StatelessWidget {
  final bool isPremium;
  final bool showLabel;
  final double? size;

  const PremiumBadge({
    super.key,
    required this.isPremium,
    this.showLabel = true,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPremium) return const SizedBox.shrink();

    final iconSize = size ?? 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? AppSizes.space8 : AppSizes.space4,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        boxShadow: [
          BoxShadow(
            color: AppColors.sunnyYellow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: AppColors.charcoal,
            size: iconSize,
          ),
          if (showLabel) ...[
            const SizedBox(width: AppSizes.space4),
            Text(
              'Premium',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small icon-only premium indicator
class PremiumIcon extends StatelessWidget {
  final double size;

  const PremiumIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sunnyYellow,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.workspace_premium,
        color: AppColors.charcoal,
        size: size,
      ),
    );
  }
}

/// A lock icon overlay for premium-only features
class PremiumLockOverlay extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final VoidCallback? onTap;
  final String? message;

  const PremiumLockOverlay({
    super.key,
    required this.child,
    required this.isLocked,
    this.onTap,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Grayed out child
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.grey,
              BlendMode.saturation,
            ),
            child: Opacity(
              opacity: 0.5,
              child: AbsorbPointer(child: child),
            ),
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: AppColors.sunnyYellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sunnyYellow.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: AppColors.charcoal,
                      size: 24,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: AppSizes.space8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
                      child: Text(
                        message!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space12,
                      vertical: AppSizes.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sunnyYellow,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      'Upgrade to Premium',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
