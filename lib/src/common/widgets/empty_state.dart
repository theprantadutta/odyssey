import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import '../theme/odyssey_tokens.dart';
import 'odyssey/indicators.dart';

/// The pre-2.0 empty state, rebuilt on the Odyssey pattern.
///
/// The design's empty state is a one-line explanation over a dashed
/// affordance — no illustration, no 120px circle, no bounce. The [icon] and
/// its colours are accepted and ignored so the remaining call sites keep
/// compiling; prefer [OdysseyEmptyState] in new code.
@Deprecated('Use OdysseyEmptyState')
class EmptyState extends StatelessWidget {
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

  /// Ignored — this system's empty state is typographic.
  final IconData icon;

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Ignored, along with [icon].
  final Color? iconColor;

  /// Ignored, along with [icon].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space10),
            OdysseyEmptyState(
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// The empty trips list.
class NoTripsState extends StatelessWidget {
  const NoTripsState({super.key, this.onCreateTrip});

  final VoidCallback? onCreateTrip;

  @override
  Widget build(BuildContext context) {
    return OdysseyEmptyState(
      message: 'No trips yet. The next one starts here.',
      actionLabel: 'Plan a trip',
      onAction: onCreateTrip,
    );
  }
}

/// The empty activity list.
class NoActivitiesState extends StatelessWidget {
  const NoActivitiesState({super.key, this.onAddActivity});

  final VoidCallback? onAddActivity;

  @override
  Widget build(BuildContext context) {
    return OdysseyEmptyState(
      message: 'No plans yet. Days fill up one idea at a time.',
      actionLabel: 'Add a plan',
      onAction: onAddActivity,
    );
  }
}

/// The empty memory wall.
class NoMemoriesState extends StatelessWidget {
  const NoMemoriesState({super.key, this.onAddMemory});

  final VoidCallback? onAddMemory;

  @override
  Widget build(BuildContext context) {
    return OdysseyEmptyState(
      message: 'No photos yet. The journal fills itself as you go.',
      actionLabel: 'Add a photo',
      onAction: onAddMemory,
    );
  }
}

/// A failure. There is no red in this palette, so it says what went wrong and
/// offers the way back rather than colouring the problem.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.space20),
      child: OdysseyErrorState(message: message, onRetry: onRetry),
    );
  }
}
