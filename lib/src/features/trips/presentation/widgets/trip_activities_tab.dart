import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../activities/data/models/activity_model.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../activities/presentation/screens/activity_form_screen.dart';
import '../../../activities/presentation/widgets/activity_list_widget.dart';

class TripActivitiesTab extends ConsumerWidget {
  final String tripId;

  const TripActivitiesTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activitiesState = ref.watch(tripActivitiesProvider(tripId));

    return Stack(
      children: [
        // Main content
        _buildContent(context, ref, activitiesState, theme, colorScheme),
        // FAB
        Positioned(
          right: AppSizes.space16,
          bottom: AppSizes.space16,
          child: _buildFAB(context),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ActivitiesState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Loading state
    if (state.isLoading && state.activities.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (state.error != null && state.activities.isEmpty) {
      return _buildErrorState(context, ref, state.error!, colorScheme);
    }

    // Empty state
    if (state.activities.isEmpty) {
      return NoActivitiesState(
        onAddActivity: () => _navigateToAddActivity(context),
      );
    }

    // Activities list
    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      onRefresh: () async {
        await ref.read(tripActivitiesProvider(tripId).notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: AppSizes.space16,
          bottom: AppSizes.space80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.activities.length} ${state.activities.length == 1 ? 'Activity' : 'Activities'}',
                    style: AppTypography.titleSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.activities.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space12,
                        vertical: AppSizes.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lemonLight,
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: AppSizes.iconXs,
                            color: AppColors.goldenGlow,
                          ),
                          const SizedBox(width: AppSizes.space4),
                          Text(
                            'Drag to reorder',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.goldenGlow,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            // Activities list
            ActivityListWidget(
              activities: state.activities,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(tripActivitiesProvider(tripId).notifier)
                    .reorderActivities(oldIndex, newIndex);
              },
              onActivityTap: (activity) =>
                  _navigateToEditActivity(context, activity),
              onActivityDelete: (activity) =>
                  _showDeleteDialog(context, ref, activity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: AppSizes.space16),
            height: AppSizes.activityCardHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load activities',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(tripActivitiesProvider(tripId).notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
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

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToAddActivity(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.sunnyYellow,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.sunnyYellow.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: AppColors.charcoal,
          size: 28,
        ),
      ),
    );
  }

  void _navigateToAddActivity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityFormScreen(tripId: tripId),
      ),
    );
  }

  void _navigateToEditActivity(BuildContext context, ActivityModel activity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityFormScreen(
          tripId: tripId,
          activity: activity,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    ActivityModel activity,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Activity',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${activity.title}"? This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
              try {
                await ref
                    .read(tripActivitiesProvider(tripId).notifier)
                    .deleteActivity(activity.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: AppSizes.space12),
                          Text('Activity deleted'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
