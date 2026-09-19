import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../application/notification_permission_policy.dart';

/// Our own explanation, shown before the operating system's dialog.
///
/// The system dialog can be presented once and says nothing about what the app
/// would send - only that it "would like to send notifications". Answering that
/// with no context is a coin toss, and a no is permanent. So this sheet does the
/// explaining, and the system dialog is only reached by someone who has already
/// said yes to it. Someone who taps "Not now" leaves the one-shot dialog unspent,
/// which is the whole point: they can still be asked another day.
///
/// Presenting it at launch is also what App Review rejects, so nothing calls this
/// during startup.
Future<bool> showNotificationPermissionSheet(
  BuildContext context, {
  required String occasion,
  NotificationPermissionState state = NotificationPermissionState.undetermined,
}) async {
  final blocked = state == NotificationPermissionState.blocked;

  final optedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NotificationPermissionSheet(blocked: blocked),
  );

  if (optedIn != true) return false;

  if (blocked) {
    // The system dialog has already been answered and will not appear again, so
    // "Enable" here can only mean the settings app. Offering the same button and
    // silently doing nothing is how an app teaches people that its buttons are
    // decorative.
    await NotificationService().openSystemNotificationSettings();
    return false;
  }

  AppLogger.info('Notification permission requested after sheet ($occasion)');
  return NotificationService().requestPermission();
}

class _NotificationPermissionSheet extends StatelessWidget {
  const _NotificationPermissionSheet({required this.blocked});

  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              blocked
                  ? 'Notifications are turned off'
                  : 'Never miss a moment of your trip',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              blocked
                  ? 'Notifications for Odyssey are switched off in your device '
                      'settings. You can turn them back on there at any time.'
                  : 'Here is everything we would let you know about. Nothing '
                      'else, and you can change this whenever you like.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Named from what the server actually sends, so the list is a
            // promise the app keeps rather than a pitch.
            const _Benefit(
              icon: Icons.luggage_rounded,
              title: 'Trip reminders',
              detail: 'A nudge the day before you set off, and on the morning '
                  'you leave.',
            ),
            const SizedBox(height: 16),
            const _Benefit(
              icon: Icons.group_rounded,
              title: 'Shared trips',
              detail: 'Invitations, and when someone you travel with adds a '
                  'photo, expense or plan.',
            ),
            const SizedBox(height: 16),
            const _Benefit(
              icon: Icons.emoji_events_rounded,
              title: 'Achievements',
              detail: 'The moment you unlock one.',
            ),
            const SizedBox(height: 28),

            CustomButton(
              text: blocked ? 'Open settings' : 'Turn on notifications',
              icon: blocked
                  ? Icons.settings_rounded
                  : Icons.notifications_active_rounded,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Not now',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(icon, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
