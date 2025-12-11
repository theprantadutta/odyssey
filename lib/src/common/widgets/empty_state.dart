import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import 'custom_button.dart';

/// Premium empty state with illustrations
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.midnightBlue,
              ),
            ),
            const SizedBox(height: AppSizes.space24),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space12),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space32),

            // Action button
            if (actionLabel != null && onAction != null)
              CustomButton(
                text: actionLabel!,
                onPressed: onAction,
                icon: Icons.add,
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for no trips
class NoTripsState extends StatelessWidget {
  final VoidCallback? onCreateTrip;

  const NoTripsState({
    super.key,
    this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.travel_explore,
      title: 'No trips yet',
      message: 'Start planning your next adventure!\nCreate your first trip to begin.',
      actionLabel: 'Create Trip',
      onAction: onCreateTrip,
    );
  }
}

/// Empty state for no activities
class NoActivitiesState extends StatelessWidget {
  final VoidCallback? onAddActivity;

  const NoActivitiesState({
    super.key,
    this.onAddActivity,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.event_note,
      title: 'No activities planned',
      message: 'Add activities to build your perfect itinerary.',
      actionLabel: 'Add Activity',
      onAction: onAddActivity,
    );
  }
}

/// Empty state for no memories
class NoMemoriesState extends StatelessWidget {
  final VoidCallback? onAddMemory;

  const NoMemoriesState({
    super.key,
    this.onAddMemory,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.photo_camera,
      title: 'No memories captured',
      message: 'Upload photos to remember this journey.',
      actionLabel: 'Add Photo',
      onAction: onAddMemory,
    );
  }
}

/// Error state widget
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space12),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space32),

            // Retry button
            if (onRetry != null)
              CustomButton(
                text: 'Try Again',
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
          ],
        ),
      ),
    );
  }
}
