import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/services/notification_service.dart';
import 'package:odyssey/src/features/notifications/presentation/providers/notification_provider.dart';

/// What a tap on a notification shown in the foreground carries back, and the
/// device token's lifecycle across a sign-out.
void main() {
  group('decodePayload', () {
    test('reads the JSON a foreground notification is now shown with', () {
      final data = {
        'type': 'trip_invite',
        'trip_id': '0f8c',
        'invite_code': 'a=b&c',
      };

      expect(NotificationService.decodePayload(jsonEncode(data)), data);
    });

    test('keeps values the old format could not carry', () {
      // `=` and `&` split the old key=value&key=value encoding apart.
      final decoded = NotificationService.decodePayload(
        jsonEncode({'title_hint': 'Rock & Roll = fun'}),
      );

      expect(decoded['title_hint'], 'Rock & Roll = fun');
    });

    test('still reads a notification shown by the previous version', () {
      expect(
        NotificationService.decodePayload('type=trip_reminder&trip_id=42'),
        {'type': 'trip_reminder', 'trip_id': '42'},
      );
    });

    test('splits an old-format pair on its first = only', () {
      expect(
        NotificationService.decodePayload('invite_code=ab=cd'),
        {'invite_code': 'ab=cd'},
      );
    });
  });

  group('NotificationState', () {
    const signedIn = NotificationState(
      isInitialized: true,
      hasPermission: true,
      fcmToken: 'old-token',
    );

    test('clears the token on sign-out', () {
      // Passing fcmToken: null means "unchanged"; signing out used to do that
      // and the next sign-in registered the token it had just deleted.
      final signedOut = signedIn.copyWith(clearFcmToken: true);

      expect(signedOut.fcmToken, isNull);
      expect(signedOut.isInitialized, isTrue);
    });

    test('leaves the token alone when not asked to clear it', () {
      expect(signedIn.copyWith(fcmToken: null).fcmToken, 'old-token');
      expect(signedIn.copyWith(fcmToken: 'new-token').fcmToken, 'new-token');
    });
  });
}
