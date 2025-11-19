import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/trips/presentation/screens/trips_dashboard_screen.dart';
import '../../features/trips/presentation/screens/trip_form_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Route paths
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String createTrip = '/create-trip';
  static const String editTrip = '/edit-trip';
}

/// GoRouter provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final isOnSplash = state.matchedLocation == AppRoutes.splash;
      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnRegister = state.matchedLocation == AppRoutes.register;

      // Show splash while checking auth
      if (isLoading && !isOnSplash) {
        return AppRoutes.splash;
      }

      // Redirect to home if authenticated and on auth screens
      if (isAuthenticated && (isOnLogin || isOnRegister || isOnSplash)) {
        return AppRoutes.home;
      }

      // Redirect to login if not authenticated and not on auth screens
      if (!isAuthenticated && !isOnLogin && !isOnRegister && !isLoading) {
        return AppRoutes.login;
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Login Screen
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          onRegisterTap: () => context.go(AppRoutes.register),
        ),
      ),

      // Register Screen
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterScreen(
          onLoginTap: () => context.go(AppRoutes.login),
        ),
      ),

      // Home Screen (Protected) - Trips Dashboard
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const TripsDashboardScreen(),
      ),

      // Create Trip (Protected)
      GoRoute(
        path: AppRoutes.createTrip,
        builder: (context, state) => const TripFormScreen(),
      ),

      // Edit Trip (Protected)
      // Note: Edit navigation is currently handled via MaterialPageRoute
      // in TripsDashboardScreen to pass the trip object directly
      GoRoute(
        path: '${AppRoutes.editTrip}/:id',
        builder: (context, state) {
          // TODO: Implement GoRouter-based edit with trip fetching from state
          return const TripFormScreen();
        },
      ),
    ],
  );
});
