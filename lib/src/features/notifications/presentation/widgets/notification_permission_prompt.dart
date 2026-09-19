import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/logger_service.dart';
import '../../application/notification_permission_policy.dart';
import '../providers/notification_provider.dart';
import 'notification_permission_sheet.dart';

/// Raises notifications at a moment that warrants it, if it is reasonable to.
///
/// The one entry point the app should call. It decides nothing itself: whether
/// to ask is [NotificationPermissionPolicy]'s business, and what to say is the
/// sheet's. What it owns is the order - ask, record, and tell the rest of the
/// app if the answer changed.
///
/// [occasion] names what just happened, for the log. It has no effect on the
/// decision; it exists so that "why did this appear now" has an answer.
///
/// Returns true only if permission ended up granted.
Future<bool> maybeAskAboutNotifications(
  BuildContext context,
  WidgetRef ref, {
  required String occasion,
  NotificationPermissionPolicy? policy,
}) async {
  final permissions = policy ?? NotificationPermissionPolicy();

  if (!await permissions.shouldAskAsync(occasion)) return false;

  // Awaiting crosses an async gap, and in that time the screen that asked may
  // have been popped - a trip created and then immediately navigated away from
  // is the ordinary case, not the exotic one.
  if (!context.mounted) return false;

  // Recorded before the sheet is shown rather than after it is answered. If the
  // app is killed while the sheet is up, the ask still happened as far as the
  // person is concerned, and the alternative - recording afterwards - would show
  // it again at the next opportunity.
  await permissions.recordAskedAsync();

  if (!context.mounted) return false;

  final granted = await showNotificationPermissionSheet(
    context,
    occasion: occasion,
  );

  AppLogger.info(
    'Notification priming shown for "$occasion"; '
    'granted: $granted',
  );

  if (granted) {
    // Carries the FCM token with it. Until permission exists there is no token
    // on iOS, so this is the first moment the device can be registered - without
    // it, someone could say yes and still never receive anything until the next
    // cold start.
    await ref.read(notificationsProvider.notifier).grantedPermission(true);
  }

  return granted;
}

/// The same, from a screen that is asking on the person's behalf rather than at
/// an opportune moment - the settings row.
///
/// Ignores the backoff, because the person went looking for this, and handles
/// the case the automatic path will not: permission already refused at the OS
/// level, where the only thing left is the system settings app.
Future<bool> askAboutNotificationsOnRequest(
  BuildContext context,
  WidgetRef ref, {
  NotificationPermissionPolicy? policy,
}) async {
  final permissions = policy ?? NotificationPermissionPolicy();
  final state = await permissions.currentStateAsync();

  if (state == NotificationPermissionState.granted) return true;
  if (!context.mounted) return false;

  final granted = await showNotificationPermissionSheet(
    context,
    occasion: 'settings',
    state: state,
  );

  if (granted) {
    await ref.read(notificationsProvider.notifier).grantedPermission(true);
  }

  return granted;
}
