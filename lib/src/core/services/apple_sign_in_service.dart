import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'logger_service.dart';

/// Service for handling Sign in with Apple, bridged into Firebase Auth.
///
/// Sign in with Apple is required by App Store Review Guideline 4.8 because the
/// app also offers Google Sign-In. We route the Apple credential through the
/// same Firebase Auth backend flow used by Google, so the backend
/// (`/auth/firebase`) needs no Apple-specific verification code.
class AppleSignInService {
  // Singleton pattern (matches GoogleSignInService).
  static final AppleSignInService _instance = AppleSignInService._internal();
  factory AppleSignInService() => _instance;
  AppleSignInService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Whether Sign in with Apple is available on this device/platform.
  ///
  /// Apple only allows the native flow on iOS 13+/macOS. On other platforms
  /// the button should be hidden.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }
    try {
      return await SignInWithApple.isAvailable();
    } catch (e) {
      AppLogger.warning('SignInWithApple.isAvailable() failed: $e');
      return false;
    }
  }

  /// Generates a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA256 of the raw nonce, sent to Apple; the raw nonce goes to Firebase.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Sign in with Apple and authenticate with Firebase.
  ///
  /// Returns a [UserCredential] on success. Throws
  /// [SignInWithAppleAuthorizationException] with code `canceled` if the user
  /// cancels — callers should treat that as a cancellation, not an error.
  ///
  /// Flow:
  /// 1. Generate a nonce (raw + SHA256).
  /// 2. Request an Apple ID credential (identity token + optional name).
  /// 3. Build a Firebase OAuth credential for `apple.com`.
  /// 4. Sign in to Firebase with that credential.
  /// 5. Persist the display name on the first sign-in (Apple only returns it once).
  Future<UserCredential?> signInWithApple() async {
    try {
      AppLogger.info('Starting Sign in with Apple flow');

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        AppLogger.error('Apple credential missing identityToken');
        throw Exception('Failed to get Apple identity token');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      AppLogger.info('Creating Firebase credential for Apple...');
      final UserCredential result =
          await _firebaseAuth.signInWithCredential(oauthCredential);

      // Apple only returns the full name on the very first authorization.
      // Firebase does not persist it automatically, so set it once.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final fullName = [givenName, familyName]
          .where((p) => p != null && p.isNotEmpty)
          .join(' ')
          .trim();
      if (fullName.isNotEmpty &&
          (result.user?.displayName == null ||
              result.user!.displayName!.isEmpty)) {
        try {
          await result.user?.updateDisplayName(fullName);
          await result.user?.reload();
        } catch (e) {
          AppLogger.warning('Failed to set Apple display name: $e');
        }
      }

      if (result.user != null) {
        AppLogger.info('Firebase Apple sign-in successful: ${result.user!.uid}');
      }
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Re-throw; the repository/provider maps `canceled` to a no-op.
      AppLogger.info('Sign in with Apple authorization result: ${e.code}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase Auth error (Apple): ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error signing in with Apple: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get the current Firebase ID token for backend authentication.
  Future<String?> getFirebaseIdToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        AppLogger.warning('Cannot get ID token: no user signed in');
        return null;
      }
      return await user.getIdToken();
    } catch (e) {
      AppLogger.error('Error getting Firebase ID token (Apple): $e');
      return null;
    }
  }
}
