import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('reads the picture the identity provider gave', () {
      // The field the app used to drop. The backend has always sent it - it is
      // set from the Firebase user on a Google or Apple sign-in - but the model
      // had no place to put it, so every avatar fell back to an initial.
      final user = UserModel.fromJson(const {
        'id': 'u1',
        'email': 'someone@example.com',
        'is_active': true,
        'display_name': 'John Doe',
        'photo_url': 'https://lh3.googleusercontent.com/a/example=s96-c',
      });

      expect(user.photoUrl, 'https://lh3.googleusercontent.com/a/example=s96-c');
      expect(user.displayName, 'John Doe');
    });

    test('an email account simply has none', () {
      final user = UserModel.fromJson(const {
        'id': 'u2',
        'email': 'someone@example.com',
        'is_active': true,
      });

      expect(user.photoUrl, isNull);
    });

    test('survives a round trip, so the cached copy keeps the picture', () {
      // The signed-in user is cached as JSON for offline start-up. A field that
      // serialises but does not deserialise would lose the picture on relaunch.
      const original = UserModel(
        id: 'u3',
        email: 'someone@example.com',
        isActive: true,
        displayName: 'John Doe',
        photoUrl: 'https://lh3.googleusercontent.com/a/example=s96-c',
      );

      expect(UserModel.fromJson(original.toJson()), original);
    });
  });
}
