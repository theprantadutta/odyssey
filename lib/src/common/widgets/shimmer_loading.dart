import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// Premium shimmer loading effect for skeleton screens
///
/// Usage:
/// ```dart
/// ShimmerLoading(
///   child: Container(
///     height: 200,
///     decoration: BoxDecoration(
///       color: Colors.white,
///       borderRadius: BorderRadius.circular(12),
///     ),
///   ),
/// )
/// ```
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = highlightColor ??
        (isDark ? AppColors.navyAccent : Colors.grey[100]!);

    return child
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shimmer(
          duration: 1500.ms,
          color: highlight,
          size: 0.5,
        );
  }
}

/// Pre-built shimmer skeleton for trip cards
class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: AppSizes.tripCardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: AppSizes.tripCardImageHeight,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title placeholder
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  // Subtitle placeholder
                  Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-built shimmer skeleton for activity list items
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: AppSizes.activityCardHeight,
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Row(
          children: [
            // Icon placeholder
            Container(
              width: AppSizes.iconXl,
              height: AppSizes.iconXl,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            const SizedBox(width: AppSizes.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title placeholder
                  Container(
                    height: 18,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  // Subtitle placeholder
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for list of items
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final Widget itemSkeleton;

  const ListSkeleton({
    super.key,
    this.itemCount = 3,
    required this.itemSkeleton,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSizes.space16),
      itemCount: itemCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSizes.space16),
      itemBuilder: (context, index) => itemSkeleton,
    );
  }
}

/// Generic box shimmer placeholder
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppSizes.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Circle shimmer placeholder (for avatars, profile pics)
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({
    super.key,
    this.size = AppSizes.iconXl,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
