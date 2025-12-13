import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'logger_service.dart';

/// Service for handling Google Sign-In with Firebase
class GoogleSignInService {
  // Singleton pattern
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignInService._internal() {
    // Initialize Google Sign-In with client ID from environment
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];

    if (webClientId != null &&
        webClientId.isNotEmpty &&
        webClientId != 'YOUR_GOOGLE_WEB_CLIENT_ID_HERE') {
      _googleSignIn.initialize(
        serverClientId: webClientId,
      );
      AppLogger.info('GoogleSignIn initialized with serverClientId');
    } else {
      AppLogger.warning(
        'GOOGLE_WEB_CLIENT_ID not properly configured in .env file',
      );
    }
  }

  /// Get current Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is signed in to Firebase
  bool get isSignedIn => currentUser != null;

  /// Stream of Firebase auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with Google and authenticate with Firebase
  ///
  /// Returns a [UserCredential] on success, null if cancelled or unsupported
  ///
  /// Flow:
  /// 1. Check if Google Sign-In authenticate is supported
  /// 2. Trigger Google Sign-In flow
  /// 3. Get Google authentication tokens
  /// 4. Create Firebase credential
  /// 5. Sign in to Firebase with the credential
  Future<UserCredential?> signInWithGoogle() async {
    try {
      AppLogger.info('Starting Google Sign-In flow');

      // Check if authentication is supported on this platform
      if (_googleSignIn.supportsAuthenticate()) {
        // Use authenticate method for supported platforms
        final GoogleSignInAccount googleUser =
            await _googleSignIn.authenticate();

        AppLogger.info('Google user signed in: ${googleUser.email}');

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth =
            googleUser.authentication;

        if (googleAuth.idToken == null) {
          AppLogger.error('Failed to get Google ID token');
          throw Exception('Failed to get Google ID token');
        }

        // Create a new Firebase credential
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        AppLogger.info('Creating Firebase credential...');

        // Sign in to Firebase with the credential
        final UserCredential result =
            await _firebaseAuth.signInWithCredential(credential);

        if (result.user != null) {
          AppLogger.info('Firebase sign-in successful: ${result.user!.uid}');
        }

        return result;
      } else {
        AppLogger.warning(
          'Google authenticate not supported on this platform',
        );
        return null;
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase Auth error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error signing in with Google: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get Firebase ID token for backend authentication
  ///
  /// This token should be sent to the backend for verification
  Future<String?> getFirebaseIdToken() async {
    try {
      final user = currentUser;
      if (user == null) {
        AppLogger.warning('Cannot get ID token: no user signed in');
        return null;
      }

      final token = await user.getIdToken();
      AppLogger.info('Retrieved Firebase ID token');
      return token;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting Firebase ID token: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out from Google and Firebase...');
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      AppLogger.info('Sign out successful');
    } catch (e, stackTrace) {
      AppLogger.error('Error signing out: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Disconnect Google account completely (more aggressive than signOut)
  Future<void> disconnect() async {
    try {
      AppLogger.info('Disconnecting Google account...');
      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
      AppLogger.info('Disconnect successful');
    } catch (e, stackTrace) {
      AppLogger.error('Error disconnecting: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - disconnect can fail if already disconnected
    }
  }
}
