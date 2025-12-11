import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool needsOnboarding;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.needsOnboarding = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? needsOnboarding,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
    );
  }
}

/// Auth repository provider
@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

/// Auth state notifier provider
@riverpod
class Auth extends _$Auth {
  late final AuthRepository _authRepository;

  @override
  AuthState build() {
    _authRepository = ref.read(authRepositoryProvider);
    
    // Delay auth check until after provider is fully initialized
    // This avoids the "uninitialized provider" error in Riverpod 3
    Future.microtask(() => _checkAuthStatus());
    
    return const AuthState(isLoading: true);
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    AppLogger.auth('Checking authentication status...');
    state = state.copyWith(isLoading: true);
    try {
      final isAuth = await _authRepository.isAuthenticated();
      if (isAuth) {
        AppLogger.auth('Token found, fetching user data...');
        final user = await _authRepository.getCurrentUser();
        AppLogger.auth('User authenticated: ${user?.email}');
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          isLoading: false,
        );
      } else {
        AppLogger.auth('No valid token found');
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    } catch (e) {
      AppLogger.auth('Auth check failed: $e', isError: true);
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Register new user
  Future<void> register({
    required String email,
    required String password,
  }) async {
    AppLogger.auth('Registering new user: $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.register(
        email: email,
        password: password,
      );

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      AppLogger.auth('Registration successful: ${user?.email}');

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        needsOnboarding: true, // New user needs onboarding
      );
    } catch (e) {
      AppLogger.auth('Registration failed: $e', isError: true);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Login existing user
  Future<void> login({
    required String email,
    required String password,
  }) async {
    AppLogger.auth('Logging in user: $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.login(
        email: email,
        password: password,
      );

      // Fetch user details
      final user = await _authRepository.getCurrentUser();
      AppLogger.auth('Login successful: ${user?.email}');

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.auth('Login failed: $e', isError: true);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    AppLogger.auth('Logging out user');
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.logout();
      AppLogger.auth('Logout successful');
      state = const AuthState(
        isAuthenticated: false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.auth('Logout failed: $e', isError: true);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
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
}
