import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/notifications/application/notification_permission_policy.dart';

/// When the app is allowed to raise notifications, and when it must not.
///
/// The rules matter more than most, because getting them wrong is not
/// recoverable. The iOS permission dialog is shown once: if the app spends it at
/// a bad moment and the answer is no, that answer is final and no amount of
/// asking later can change it. So these check the two directions separately -
/// that a reasonable moment is allowed through, and that an unreasonable one is
/// refused.
void main() {
  late _FakeStorage storage;

  setUp(() => storage = _FakeStorage());

  NotificationPermissionPolicy policyFor(AuthorizationStatus status) =>
      NotificationPermissionPolicy(
        messaging: _FakeMessaging(status),
        storage: storage,
      );

  group('whether to ask at all', () {
    test('a first opportunity is taken', () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      expect(await policy.shouldAskAsync('trip-created'), isTrue);
    });

    test('an account that already allowed notifications is not asked', () async {
      final policy = policyFor(AuthorizationStatus.authorized);

      expect(await policy.shouldAskAsync('trip-created'), isFalse);
    });

    test('provisional authorization counts as allowed', () async {
      final policy = policyFor(AuthorizationStatus.provisional);

      expect(await policy.shouldAskAsync('trip-created'), isFalse);
    });

    test('a refusal at the OS level is not asked about again', () async {
      // The dialog is spent. Showing our sheet here would offer a button that
      // cannot do what it says, so the settings screen owns this case instead.
      final policy = policyFor(AuthorizationStatus.denied);

      expect(await policy.shouldAskAsync('trip-created'), isFalse);
    });
  });

  group('the backoff after a decline', () {
    test('a second opportunity the same day is refused', () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      await policy.recordAskedAsync();

      expect(await policy.shouldAskAsync('trip-created'), isFalse);
    });

    test('a fortnight later the next opportunity is taken', () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      await policy.recordAskedAsync();
      storage.rewind(const Duration(days: 15));

      expect(await policy.shouldAskAsync('trip-created'), isTrue);
    });

    test('the wait widens, so a fortnight is not enough the second time',
        () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      await policy.recordAskedAsync();
      await policy.recordAskedAsync();
      storage.rewind(const Duration(days: 20));

      // Two declines is a signal. The third ask has to read as a new occasion
      // rather than a continuation of the same conversation.
      expect(await policy.shouldAskAsync('trip-created'), isFalse);

      storage.rewind(const Duration(days: 30));
      expect(await policy.shouldAskAsync('trip-created'), isTrue);
    });

    test('the app eventually stops asking on its own', () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      for (var i = 0; i < 4; i++) {
        await policy.recordAskedAsync();
      }

      // However long has passed. Four refusals is an answer, and the settings
      // screen is where it can still be changed.
      storage.rewind(const Duration(days: 3650));

      expect(await policy.shouldAskAsync('trip-created'), isFalse);
    });
  });

  group('signing out', () {
    test('the next person starts from nothing', () async {
      final policy = policyFor(AuthorizationStatus.notDetermined);

      for (var i = 0; i < 4; i++) {
        await policy.recordAskedAsync();
      }
      expect(await policy.shouldAskAsync('trip-created'), isFalse);

      await policy.resetAsync();

      // Inheriting the previous account's refusals would deny this person the
      // prompt permanently, for answers they never gave.
      expect(await policy.shouldAskAsync('trip-created'), isTrue);
    });
  });
}

/// Records what the app would have stored, and lets a test move it into the past.
class _FakeStorage implements NotificationPrimingStore {
  int _count = 0;
  DateTime? _lastAsked;

  /// Pretends the last ask happened [by] earlier than it did.
  void rewind(Duration by) {
    final last = _lastAsked;
    if (last != null) _lastAsked = last.subtract(by);
  }

  @override
  Future<int> getNotificationAskCount() async => _count;

  @override
  Future<DateTime?> getNotificationLastAskedAt() async => _lastAsked;

  @override
  Future<void> recordNotificationAsked(int count, DateTime at) async {
    _count = count;
    _lastAsked = at;
  }

  @override
  Future<void> clearNotificationPriming() async {
    _count = 0;
    _lastAsked = null;
  }
}

class _FakeMessaging implements FirebaseMessaging {
  _FakeMessaging(this.status);

  final AuthorizationStatus status;

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      NotificationSettings(
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.disabled,
        authorizationStatus: status,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.enabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Only getNotificationSettings is used here');
}
