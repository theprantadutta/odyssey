import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/services/storage_service.dart';

/// The slice of storage the notification priming policy needs.
///
/// Narrow on purpose. The policy's rules are the part worth testing, and
/// StorageService writes to the platform keychain - which needs a running engine
/// and platform channels, so a unit test of "how long before we ask again" would
/// otherwise have to boot one.
abstract class NotificationPrimingStore {
  Future<int> getNotificationAskCount();

  Future<DateTime?> getNotificationLastAskedAt();

  Future<void> recordNotificationAsked(int count, DateTime at);

  Future<void> clearNotificationPriming();
}

/// When it is reasonable to ask about notifications, and when it is not.
///
/// Two rules shape this.
///
/// The first is Apple's, and it is the reason any of this exists: the system
/// permission dialog can be presented **once**. Spending it during launch, before
/// the person has seen the app, is both a review rejection and the surest way to
/// get a refusal - and a refusal is permanent. Nothing here calls
/// `requestPermission` until the person has said yes to our own sheet first.
///
/// The second is ordinary manners. Someone who declined should be asked again
/// eventually, because they may simply not have had a reason yet - but asking on
/// a timer turns the app into something that nags. So a re-ask needs two things
/// at once: a moment where notifications would obviously be useful (a trip was
/// just created), and enough distance from the last time we asked. The distance
/// grows each time, and after [_maxAsks] the app stops asking and leaves it to
/// the settings screen.
class NotificationPermissionPolicy {
  NotificationPermissionPolicy({
    FirebaseMessaging? messaging,
    NotificationPrimingStore? storage,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _storage = storage ?? StorageService();

  final FirebaseMessaging _messaging;
  final NotificationPrimingStore _storage;

  /// How long to wait after each decline before the next opportunity counts.
  ///
  /// Widening rather than fixed. Someone who has said no twice is telling us
  /// something, and the third ask should be far enough away that it reads as a
  /// new occasion rather than a continuation of the same conversation.
  static const _backoff = <Duration>[
    Duration(days: 14),
    Duration(days: 45),
    Duration(days: 90),
  ];

  /// After this many asks the app stops raising it on its own.
  static int get _maxAsks => _backoff.length + 1;

  /// Whether the OS has already made a decision we cannot change from here.
  ///
  /// On iOS the dialog is one-shot: once it has been answered, calling
  /// `requestPermission` again returns the existing answer without showing
  /// anything. At that point the only route to notifications is the system
  /// settings app, so offering an "Enable" button that silently does nothing
  /// would be a lie.
  Future<NotificationPermissionState> currentStateAsync() async {
    try {
      final settings = await _messaging.getNotificationSettings();

      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          NotificationPermissionState.granted,
        AuthorizationStatus.denied => NotificationPermissionState.blocked,
        _ => NotificationPermissionState.undetermined,
      };
    } catch (e) {
      AppLogger.error('Could not read notification settings', e);

      // Treated as undetermined rather than blocked: the worst outcome is
      // showing our own sheet to someone who did not need it, which is
      // recoverable. Treating it as blocked would send them to the settings app
      // for no reason.
      return NotificationPermissionState.undetermined;
    }
  }

  /// Whether to raise the subject now, at a moment that warrants it.
  ///
  /// [occasion] is the thing that just happened. It does not change the rules;
  /// it is recorded so the logs say why the sheet appeared.
  Future<bool> shouldAskAsync(String occasion) async {
    final state = await currentStateAsync();

    if (state != NotificationPermissionState.undetermined) {
      // Already granted, or already refused at the OS level. Either way there
      // is nothing our sheet can do, and the settings screen is the right place
      // for the second case.
      return false;
    }

    final asked = await _storage.getNotificationAskCount();

    if (asked >= _maxAsks) {
      AppLogger.info(
        'Not raising notifications for "$occasion": asked $asked times already',
      );
      return false;
    }

    if (asked == 0) return true;

    final lastAsked = await _storage.getNotificationLastAskedAt();
    if (lastAsked == null) return true;

    final wait = _backoff[(asked - 1).clamp(0, _backoff.length - 1)];
    final due = lastAsked.add(wait);

    if (DateTime.now().isBefore(due)) {
      AppLogger.info(
        'Not raising notifications for "$occasion": next opportunity after $due',
      );
      return false;
    }

    return true;
  }

  /// Records that the sheet was shown, whatever the person then chose.
  ///
  /// Counted on display rather than on refusal. A sheet that was dismissed
  /// without a choice is still an interruption, and counting only refusals would
  /// let a person who keeps swiping it away be asked at every opportunity.
  Future<void> recordAskedAsync() async {
    final asked = await _storage.getNotificationAskCount();
    await _storage.recordNotificationAsked(asked + 1, DateTime.now());
  }

  /// Forgets the history, so the next opportunity counts as the first.
  ///
  /// For a sign-out: the counters describe a person's answers, and the next
  /// person to use this device has not answered anything.
  Future<void> resetAsync() => _storage.clearNotificationPriming();
}

/// What the operating system currently thinks, which is not always what the app
/// would like to believe.
enum NotificationPermissionState {
  /// Never asked. The one state in which the system dialog will actually appear.
  undetermined,

  /// Allowed, including provisionally.
  granted,

  /// Refused at the OS level. Only the system settings app can change this.
  blocked,
}
