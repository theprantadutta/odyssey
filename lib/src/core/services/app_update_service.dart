import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import 'logger_service.dart';

/// Wraps the Android in-app update flow with a policy-correct approach:
///
///  * **Immediate** (blocking, full-screen) updates only for high-priority or
///    very stale versions — NOT for every release.
///  * **Flexible** (background download) updates otherwise, installed only after
///    the user accepts a non-disruptive "Restart to update" prompt.
///  * **Resumes** an interrupted immediate update on the next launch.
///
/// This feature is Android-only and requires a store install, so it is a no-op
/// on iOS/web and silently no-ops in debug/sideloaded builds (where
/// `checkForUpdate` throws ERROR_APP_NOT_OWNED etc.).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// Lets the flexible "ready to install" prompt surface without a local
  /// [BuildContext]. Wire into `MaterialApp.router(scaffoldMessengerKey: ...)`.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// `updatePriority` (0–5, set per release in the Play Console) at/above which
  /// we escalate to a forced immediate update.
  static const int _immediatePriorityThreshold = 4;

  /// Days a user may be behind before we escalate to an immediate update.
  static const int _immediateStalenessDays = 30;

  bool _checking = false;

  /// Checks for an update and drives the appropriate flow. Safe to call on every
  /// app start / resume; re-entrant calls are ignored.
  Future<void> checkForUpdate() async {
    // In-app updates are Android-only.
    if (kIsWeb || !Platform.isAndroid) return;
    if (_checking) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      AppLogger.info(
        'Update check: availability=${info.updateAvailability}, '
        'immediate=${info.immediateUpdateAllowed}, '
        'flexible=${info.flexibleUpdateAllowed}, '
        'priority=${info.updatePriority}, '
        'staleness=${info.clientVersionStalenessDays}',
      );

      // Resume an immediate update that was interrupted (e.g. app killed mid
      // update) — Google requires handling this on the next launch.
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (_shouldUpdateImmediately(info)) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await _runFlexibleUpdate();
      }
    } catch (e) {
      // Expected outside a store install (debug/sideload) and on transient failures.
      AppLogger.debug('App update check failed: $e');
    } finally {
      _checking = false;
    }
  }

  /// Force a blocking immediate update only when the release is flagged
  /// high-priority or the installed version is badly out of date.
  bool _shouldUpdateImmediately(AppUpdateInfo info) {
    if (!info.immediateUpdateAllowed) return false;
    final staleness = info.clientVersionStalenessDays ?? 0;
    return info.updatePriority >= _immediatePriorityThreshold ||
        staleness >= _immediateStalenessDays;
  }

  /// Download in the background, then ask the user to install — keeping the app
  /// usable throughout (the whole point of a "flexible" update).
  Future<void> _runFlexibleUpdate() async {
    final result = await InAppUpdate.startFlexibleUpdate();
    if (result == AppUpdateResult.success) {
      _promptInstall();
    }
  }

  void _promptInstall() {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Update downloaded and ready to install.'),
          duration: const Duration(days: 1),
          action: SnackBarAction(
            label: 'Restart',
            onPressed: () async {
              try {
                await InAppUpdate.completeFlexibleUpdate();
              } catch (e) {
                AppLogger.debug('completeFlexibleUpdate failed: $e');
              }
            },
          ),
        ),
      );
  }
}
