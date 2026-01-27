import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/activity_model.dart';
import 'activity_card.dart';

/// Reorderable list of activities with drag-and-drop support
class ActivityListWidget extends StatelessWidget {
  final List<ActivityModel> activities;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(ActivityModel activity)? onActivityTap;
  final Function(ActivityModel activity)? onActivityDelete;
  final bool isReordering;

  const ActivityListWidget({
    super.key,
    required this.activities,
    required this.onReorder,
    this.onActivityTap,
    this.onActivityDelete,
    this.isReordering = false,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group activities by date (for future grouping implementation)
    // ignore: unused_local_variable
    final groupedActivities = _groupActivitiesByDate(activities);

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: activities.length,
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.mediumImpact();
        // ReorderableListView requires adjustment when moving down
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        onReorder(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final double elevation = Tween<double>(begin: 0, end: 8)
                .animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ))
                .value;

            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: AppColors.sunnyYellow.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final activity = activities[index];

        return ActivityCard(
          key: ValueKey(activity.id),
          activity: activity,
          onTap: () => onActivityTap?.call(activity),
          onDelete: () => onActivityDelete?.call(activity),
          showDragHandle: true,
          dragIndex: index, // Pass index for drag handle only
        );
      },
    );
  }

  Map<String, List<ActivityModel>> _groupActivitiesByDate(
      List<ActivityModel> activities) {
    final grouped = <String, List<ActivityModel>>{};

    for (final activity in activities) {
      final date = DateTime.tryParse(activity.scheduledTime);
      final dateKey = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : 'Unknown';

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(activity);
    }

    return grouped;
  }
}

/// Activity list grouped by date with section headers
class ActivityListGrouped extends StatelessWidget {
  final List<ActivityModel> activities;
  final Function(int oldIndex, int newIndex)? onReorder;
  final Function(ActivityModel activity)? onActivityTap;
  final Function(ActivityModel activity)? onActivityDelete;

  const ActivityListGrouped({
    super.key,
    required this.activities,
    this.onReorder,
    this.onActivityTap,
    this.onActivityDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedActivities = _groupActivitiesByDate(activities);
    final sortedDates = groupedActivities.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateActivities = groupedActivities[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space12,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space12,
                      vertical: AppSizes.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lemonLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      _formatDateHeader(dateKey),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.goldenGlow,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            // Activities for this date
            ...dateActivities.map((activity) {
              return ActivityCard(
                key: ValueKey(activity.id),
                activity: activity,
                onTap: () => onActivityTap?.call(activity),
                onDelete: () => onActivityDelete?.call(activity),
                showDragHandle: onReorder != null,
              );
            }),
          ],
        );
      },
    );
  }

  Map<String, List<ActivityModel>> _groupActivitiesByDate(
      List<ActivityModel> activities) {
    final grouped = <String, List<ActivityModel>>{};

    for (final activity in activities) {
      final date = DateTime.tryParse(activity.scheduledTime);
      final dateKey = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : 'Unknown';

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(activity);
    }

    return grouped;
  }

  String _formatDateHeader(String dateKey) {
    if (dateKey == 'Unknown') return 'Unscheduled';

    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final activityDate = DateTime(date.year, date.month, date.day);

      if (activityDate == today) {
        return 'Today';
      } else if (activityDate == tomorrow) {
        return 'Tomorrow';
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${months[date.month - 1]} ${date.day}';
      }
    } catch (e) {
      return dateKey;
    }
  }
}

/// Empty state for activities list
class NoActivitiesState extends StatelessWidget {
  final VoidCallback? onAddActivity;

  const NoActivitiesState({
    super.key,
    this.onAddActivity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Center(
                child: Text(
                  '📋',
                  style: TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            // Title
            Text(
              'No Activities Yet',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            // Description
            Text(
              'Plan your trip by adding activities like places to visit, restaurants to try, or transportation.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            // Add button
            if (onAddActivity != null)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAddActivity?.call();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Activity'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sunnyYellow,
                  backgroundColor: AppColors.lemonLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
