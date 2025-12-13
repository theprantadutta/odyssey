import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/activity_model.dart';

/// Activity card widget for displaying a single activity
class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDragHandle;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onDelete,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final category = _parseCategory(activity.category);
    final scheduledTime = DateTime.tryParse(activity.scheduledTime);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: AppSizes.softShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Row(
            children: [
              // Category indicator strip
              Container(
                width: 4,
                height: AppSizes.activityCardHeight,
                color: _getCategoryColor(category),
              ),
              // Category icon
              Container(
                width: 64,
                height: AppSizes.activityCardHeight,
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.space12,
                    horizontal: AppSizes.space8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        activity.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.space4),
                      // Scheduled time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: AppSizes.iconXs,
                            color: AppColors.slate,
                          ),
                          const SizedBox(width: AppSizes.space4),
                          Text(
                            scheduledTime != null
                                ? DateFormat('MMM d, h:mm a')
                                    .format(scheduledTime)
                                : 'No time set',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                      // Description (if available)
                      if (activity.description != null &&
                          activity.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.space4),
                        Text(
                          activity.description!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.mutedGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions and drag handle
              SizedBox(
                width: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showDragHandle)
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.mutedGray,
                        size: AppSizes.iconMd,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ActivityCategory _parseCategory(String categoryStr) {
    return ActivityCategory.values.firstWhere(
      (c) => c.name == categoryStr.toLowerCase(),
      orElse: () => ActivityCategory.explore,
    );
  }

  Color _getCategoryColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.food:
        return AppColors.coralBurst;
      case ActivityCategory.travel:
        return AppColors.skyBlue;
      case ActivityCategory.stay:
        return AppColors.lavenderDream;
      case ActivityCategory.explore:
        return AppColors.oceanTeal;
    }
  }
}

/// Compact activity card for smaller displays
class ActivityCardCompact extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;

  const ActivityCardCompact({
    super.key,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = _parseCategory(activity.category);
    final scheduledTime = DateTime.tryParse(activity.scheduledTime);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space12),
        decoration: BoxDecoration(
          color: AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: _getCategoryColor(category).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (scheduledTime != null) ...[
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      DateFormat('h:mm a').format(scheduledTime),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedGray,
              size: AppSizes.iconSm,
            ),
          ],
        ),
      ),
    );
  }

  ActivityCategory _parseCategory(String categoryStr) {
    return ActivityCategory.values.firstWhere(
      (c) => c.name == categoryStr.toLowerCase(),
      orElse: () => ActivityCategory.explore,
    );
  }

  Color _getCategoryColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.food:
        return AppColors.coralBurst;
      case ActivityCategory.travel:
        return AppColors.skyBlue;
      case ActivityCategory.stay:
        return AppColors.lavenderDream;
      case ActivityCategory.explore:
        return AppColors.oceanTeal;
    }
  }
}
