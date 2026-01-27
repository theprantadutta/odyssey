import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import '../animations/animated_widgets/animated_button.dart';

/// Playful empty state with colorful icons
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? backgroundColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with soft background
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: backgroundColor ?? AppColors.lemonLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (iconColor ?? AppColors.goldenGlow)
                              .withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 56,
                      color: iconColor ?? AppColors.goldenGlow,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSizes.space24),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space12),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space32),

            // Action button
            if (actionLabel != null && onAction != null)
              AnimatedButton(
                text: actionLabel!,
                onPressed: onAction,
                icon: Icons.add_rounded,
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
      message:
          'Start planning your next adventure!\nCreate your first trip to begin.',
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
      icon: Icons.event_note_rounded,
      title: 'No activities planned',
      message: 'Add activities to build your perfect itinerary.',
      actionLabel: 'Add Activity',
      onAction: onAddActivity,
      iconColor: AppColors.oceanTeal,
      backgroundColor: AppColors.statusOngoingBg,
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
      icon: Icons.photo_camera_rounded,
      title: 'No memories captured',
      message: 'Upload photos to remember this journey.',
      actionLabel: 'Add Photo',
      onAction: onAddMemory,
      iconColor: AppColors.lavenderDream,
      backgroundColor: const Color(0xFFF3E8FF),
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
            // Error icon with bounce animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: AppColors.coralBurst,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSizes.space24),

            // Title
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space12),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space32),

            // Retry button
            if (onRetry != null)
              AnimatedButton(
                text: 'Try Again',
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                backgroundColor: AppColors.coralBurst,
                foregroundColor: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
