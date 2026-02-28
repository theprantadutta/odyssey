import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/services/auth_event_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/token_refresh_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isGoogleLoading;
  final String? error;
  final bool isAuthenticated;
  final bool hasSeenIntro;
  final bool hasAcceptedTerms;
  final bool needsOnboarding;
  final bool needsAccountLinking;
  final String? pendingFirebaseToken;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.hasSeenIntro = true, // Default to true to avoid flash
    this.hasAcceptedTerms = true, // Default to true to avoid flash
    this.needsOnboarding = false,
    this.needsAccountLinking = false,
    this.pendingFirebaseToken,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isGoogleLoading,
    String? error,
    bool? isAuthenticated,
    bool? hasSeenIntro,
    bool? hasAcceptedTerms,
    bool? needsOnboarding,
    bool? needsAccountLinking,
    String? pendingFirebaseToken,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasSeenIntro: hasSeenIntro ?? this.hasSeenIntro,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      needsAccountLinking: needsAccountLinking ?? this.needsAccountLinking,
      pendingFirebaseToken: pendingFirebaseToken ?? this.pendingFirebaseToken,
    );
  }
}

/// Auth repository provider
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

/// Auth state notifier provider
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  late final AuthRepository _authRepository;
  StreamSubscription<AuthEvent>? _authEventSubscription;

  @override
  AuthState build() {
    _authRepository = ref.read(authRepositoryProvider);

    // Listen for forced logout events from interceptors
    _authEventSubscription?.cancel();
    _authEventSubscription = AuthEventService().events.listen(_handleAuthEvent);

    // Cancel subscription when provider is disposed
    ref.onDispose(() {
      _authEventSubscription?.cancel();
    });

    // Delay auth check until after provider is fully initialized
    // This avoids the "uninitialized provider" error in Riverpod 3
    Future.microtask(() => _checkAuthStatus());

    return const AuthState(isLoading: true);
  }

  /// Handle auth events from interceptors (e.g., session expired)
  void _handleAuthEvent(AuthEvent event) {
    AppLogger.auth('Auth event received: $event');

    // Don't process logout events while offline - these are likely
    // network failures, not actual auth rejections from the server
    if (!ConnectivityService().isOnline) {
      AppLogger.auth('Ignoring auth event while offline');
      return;
    }

    if (event == AuthEvent.sessionExpired ||
        event == AuthEvent.tokenRefreshFailed) {
      // Only update if currently authenticated to avoid redundant updates
      if (state.isAuthenticated) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          user: null,
          error: 'Your session has expired. Please log in again.',
        );
      }
    }
  }

  /// Check if an error is a network/connectivity error (not an auth error)
  bool _isNetworkError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown;
    }
    return false;
  }

  /// Load cached user data from storage
  Future<UserModel?> _loadCachedUser() async {
    final userJson = await StorageService().getCachedUserData();
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.auth('Failed to parse cached user data: $e', isError: true);
      return null;
    }
  }

  /// Authenticate from cached user data (offline fallback)
  Future<void> _authenticateFromCache(
    StorageService storageService,
    bool hasSeenIntro,
    bool hasAcceptedTerms,
  ) async {
    final cachedUser = await _loadCachedUser();
    if (cachedUser != null) {
      final hasCompletedOnboarding =
          await storageService.isOnboardingCompleted();
      AppLogger.auth(
        'Authenticated from cache: ${cachedUser.email}',
      );
      state = state.copyWith(
        user: cachedUser,
        isAuthenticated: true,
        isLoading: false,
        hasSeenIntro: hasSeenIntro,
        hasAcceptedTerms: hasAcceptedTerms,
        needsOnboarding: !hasCompletedOnboarding,
      );
    } else {
      AppLogger.auth('No cached user data available');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        hasSeenIntro: hasSeenIntro,
        hasAcceptedTerms: hasAcceptedTerms,
      );
    }
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    AppLogger.auth('Checking authentication status...');
    state = state.copyWith(isLoading: true);

    final storageService = StorageService();
    final tokenRefreshService = TokenRefreshService();

    try {
      // Check if user has seen intro (first-time app launch)
      final hasSeenIntro = await storageService.hasSeenIntro();
      final hasAcceptedTerms = await storageService.hasAcceptedTerms();
      AppLogger.auth('Has seen intro: $hasSeenIntro, has accepted terms: $hasAcceptedTerms');

      // Check if we have any tokens
      final hasAccessToken = await storageService.getAccessToken() != null;
      final hasRefreshToken = await storageService.getRefreshToken() != null;

      if (!hasAccessToken && !hasRefreshToken) {
        // No tokens at all - user needs to login
        AppLogger.auth('No tokens found, user needs to login');
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          hasSeenIntro: hasSeenIntro,
          hasAcceptedTerms: hasAcceptedTerms,
        );
        return;
      }

      final isOnline = ConnectivityService().isOnline;
      AppLogger.auth('Network status: ${isOnline ? "online" : "offline"}');

      if (isOnline) {
        // ONLINE: Try normal auth flow with network fallback
        final isExpired = await storageService.isAccessTokenExpired();
        AppLogger.auth('Access token expired: $isExpired');

        if (isExpired && hasRefreshToken) {
          AppLogger.auth('Attempting to refresh expired token...');
          final refreshSuccess = await tokenRefreshService.refreshToken();

          if (!refreshSuccess) {
            AppLogger.auth('Token refresh failed, clearing auth data');
            await storageService.clearAuthData();
            state = state.copyWith(
              isAuthenticated: false,
              isLoading: false,
              hasSeenIntro: hasSeenIntro,
              hasAcceptedTerms: hasAcceptedTerms,
            );
            return;
          }
          AppLogger.auth('Token refresh successful');
        }

        // Fetch user from server
        try {
          AppLogger.auth('Fetching user data from server...');
          final user = await _authRepository.getCurrentUser();

          // Cache user data for offline use
          await storageService
              .saveUserData(jsonEncode(user.toJson()));

          final hasCompletedOnboarding =
              await storageService.isOnboardingCompleted();
          AppLogger.auth(
            'User authenticated: ${user.email}, onboarding: $hasCompletedOnboarding',
          );
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
            hasSeenIntro: hasSeenIntro,
            hasAcceptedTerms: hasAcceptedTerms,
            needsOnboarding: !hasCompletedOnboarding,
          );

          _registerDeviceForNotifications();
          _triggerInitialSync();
        } catch (e) {
          if (_isNetworkError(e)) {
            // Network error while online (e.g., server unreachable)
            AppLogger.auth(
              'Network error fetching user, falling back to cache',
            );
            await _authenticateFromCache(storageService, hasSeenIntro, hasAcceptedTerms);
          } else {
            // Auth error (401, etc.) - clear auth
            AppLogger.auth('Auth error fetching user: $e', isError: true);
            await storageService.clearAuthData();
            state = state.copyWith(
              isAuthenticated: false,
              isLoading: false,
              hasSeenIntro: hasSeenIntro,
              hasAcceptedTerms: hasAcceptedTerms,
            );
          }
        }
      } else {
        // OFFLINE: Skip all network calls, use cached user
        AppLogger.auth('Offline - authenticating from cache');
        await _authenticateFromCache(storageService, hasSeenIntro, hasAcceptedTerms);
      }
    } catch (e) {
      AppLogger.auth('Auth check failed: $e', isError: true);
      // Safety net: try cache before giving up
      try {
        final hasSeenIntro = await storageService.hasSeenIntro();
        final hasAcceptedTerms = await storageService.hasAcceptedTerms();
        await _authenticateFromCache(storageService, hasSeenIntro, hasAcceptedTerms);
      } catch (_) {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    }
  }

  /// Register new user
  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    AppLogger.auth('Registering new user: $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.register(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      await StorageService().saveUserData(jsonEncode(user.toJson()));
      AppLogger.auth('Registration successful: ${user.email}');

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        needsOnboarding: true, // New user needs onboarding
      );

      // Register device for push notifications
      _registerDeviceForNotifications();

      // Trigger initial sync
      _triggerInitialSync();
    } catch (e) {
      AppLogger.auth('Registration failed: $e', isError: true);
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Login existing user
  Future<void> login({required String email, required String password}) async {
    AppLogger.auth('Logging in user: $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.login(email: email, password: password);

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      await StorageService().saveUserData(jsonEncode(user.toJson()));
      AppLogger.auth('Login successful: ${user.email}');

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );

      // Register device for push notifications
      _registerDeviceForNotifications();

      // Trigger initial sync
      _triggerInitialSync();
    } catch (e) {
      AppLogger.auth('Login failed: $e', isError: true);
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    AppLogger.auth('Logging out user');
    state = state.copyWith(isLoading: true);
    try {
      // Unregister device from push notifications
      await _unregisterDeviceForNotifications();

      await _authRepository.logout();

      // Clear local database on logout
      await DatabaseService().clearAllData();
      SyncService().dispose();
      SyncService().initialize();

      AppLogger.auth('Logout successful');
      state = const AuthState(isAuthenticated: false, isLoading: false);
    } catch (e) {
      AppLogger.auth('Logout failed: $e', isError: true);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Complete onboarding (mark as done and update state)
  Future<void> completeOnboarding() async {
    await StorageService().setOnboardingCompleted(true);
    state = state.copyWith(needsOnboarding: false);
  }

  /// Sign in with Google
  ///
  /// Returns true if account linking is required
  Future<bool> signInWithGoogle() async {
    AppLogger.auth('Starting Google Sign-In');
    state = state.copyWith(isGoogleLoading: true, error: null);

    try {
      final response = await _authRepository.signInWithGoogle();

      if (response == null) {
        // User cancelled
        AppLogger.auth('Google Sign-In cancelled by user');
        state = state.copyWith(isGoogleLoading: false);
        return false;
      }

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      await StorageService().saveUserData(jsonEncode(user.toJson()));
      AppLogger.auth('Google Sign-In successful: ${user.email}');

      // Check if onboarding was completed
      final hasCompletedOnboarding = await StorageService()
          .isOnboardingCompleted();

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isGoogleLoading: false,
        needsOnboarding:
            !hasCompletedOnboarding, // Show onboarding if not completed
      );

      // Register device for push notifications
      _registerDeviceForNotifications();

      // Trigger initial sync
      _triggerInitialSync();

      return false;
    } on AccountLinkingRequiredException catch (e) {
      AppLogger.auth('Account linking required: ${e.message}');
      state = state.copyWith(
        isGoogleLoading: false,
        needsAccountLinking: true,
        pendingFirebaseToken: e.firebaseToken,
        error: e.message,
      );
      return true;
    } catch (e) {
      AppLogger.auth('Google Sign-In failed: $e', isError: true);
      state = state.copyWith(isGoogleLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Link Google account to existing email/password account
  Future<void> linkGoogleAccount(String password) async {
    if (state.pendingFirebaseToken == null) {
      throw Exception('No pending Firebase token for account linking');
    }

    AppLogger.auth('Linking Google account');
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.linkGoogleAccount(
        firebaseToken: state.pendingFirebaseToken!,
        password: password,
      );

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      await StorageService().saveUserData(jsonEncode(user.toJson()));
      AppLogger.auth('Account linking successful: ${user.email}');

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        needsAccountLinking: false,
        pendingFirebaseToken: null,
      );

      // Register device for push notifications
      _registerDeviceForNotifications();

      // Trigger initial sync
      _triggerInitialSync();
    } catch (e) {
      AppLogger.auth('Account linking failed: $e', isError: true);
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Auto-link Google account to existing email/password account
  /// This uses Google's email verification for security (no password required)
  Future<void> autoLinkGoogleAccount() async {
    if (state.pendingFirebaseToken == null) {
      throw Exception('No pending Firebase token for account linking');
    }

    AppLogger.auth('Auto-linking Google account');
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.autoLinkGoogleAccount(
        firebaseToken: state.pendingFirebaseToken!,
      );

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      await StorageService().saveUserData(jsonEncode(user.toJson()));
      AppLogger.auth('Auto-link successful: ${user.email}');

      // Check if onboarding was completed
      final hasCompletedOnboarding = await StorageService()
          .isOnboardingCompleted();

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        needsAccountLinking: false,
        pendingFirebaseToken: null,
        needsOnboarding: !hasCompletedOnboarding,
      );

      // Register device for push notifications
      _registerDeviceForNotifications();

      // Trigger initial sync
      _triggerInitialSync();
    } catch (e) {
      AppLogger.auth('Auto-link failed: $e', isError: true);
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Cancel account linking
  void cancelAccountLinking() {
    state = state.copyWith(
      needsAccountLinking: false,
      pendingFirebaseToken: null,
      error: null,
    );
  }

  /// Mark intro as seen (updates both storage and state)
  Future<void> setIntroSeen() async {
    await StorageService().setIntroSeen(true);
    state = state.copyWith(hasSeenIntro: true);
  }

  /// Mark terms as accepted (updates both storage and state)
  Future<void> setTermsAccepted() async {
    await StorageService().setTermsAccepted(true);
    state = state.copyWith(hasAcceptedTerms: true);
  }

  /// Trigger initial sync to pull latest data (fire and forget)
  void _triggerInitialSync() {
    Future.microtask(() async {
      try {
        await SyncService().performInitialSync();
        AppLogger.auth('Initial sync completed');
      } catch (e) {
        AppLogger.auth('Initial sync failed: $e', isError: true);
      }
    });
  }

  /// Register device for push notifications (fire and forget)
  void _registerDeviceForNotifications() {
    Future.microtask(() async {
      try {
        final notificationsNotifier = ref.read(notificationsProvider.notifier);
        await notificationsNotifier.initialize();
        final success = await notificationsNotifier.registerDevice();
        if (success) {
          AppLogger.auth('Device registered for push notifications');
        } else {
          AppLogger.auth('Failed to register device for push notifications');
        }
      } catch (e) {
        AppLogger.auth('Error registering device for notifications: $e', isError: true);
      }
    });
  }

  /// Unregister device from push notifications
  Future<void> _unregisterDeviceForNotifications() async {
    try {
      final notificationsNotifier = ref.read(notificationsProvider.notifier);
      final success = await notificationsNotifier.unregisterDevice();
      if (success) {
        AppLogger.auth('Device unregistered from push notifications');
      }
    } catch (e) {
      AppLogger.auth('Error unregistering device from notifications: $e', isError: true);
    }
  }
}
