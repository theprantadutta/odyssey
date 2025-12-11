import 'package:flutter/foundation.dart';
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

/// A simple listenable for router refresh
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Global refresh notifier
final _routerRefreshNotifier = RouterRefreshNotifier();

/// GoRouter provider
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state - triggers rebuild when auth changes
  final authState = ref.watch(authProvider);

  // Schedule router refresh after this build
  Future.microtask(() => _routerRefreshNotifier.refresh());

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    refreshListenable: _routerRefreshNotifier,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final currentLocation = state.matchedLocation;
      final isOnSplash = currentLocation == AppRoutes.splash;
      final isOnLogin = currentLocation == AppRoutes.login;
      final isOnRegister = currentLocation == AppRoutes.register;
      final isOnAuthScreen = isOnLogin || isOnRegister;

      // Show splash while checking auth (but NOT if already on auth screens)
      if (isLoading && !isOnSplash && !isOnAuthScreen) {
        return AppRoutes.splash;
      }

      // Redirect to home if authenticated
      if (isAuthenticated && (isOnLogin || isOnRegister || isOnSplash)) {
        return AppRoutes.home;
      }

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isOnLogin && !isOnRegister && !isLoading) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          onRegisterTap: () => context.go(AppRoutes.register),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterScreen(
          onLoginTap: () => context.go(AppRoutes.login),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const TripsDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTrip,
        builder: (context, state) => const TripFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.editTrip}/:id',
        builder: (context, state) => const TripFormScreen(),
      ),
    ],
  );
});
