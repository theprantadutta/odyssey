import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/trips/presentation/screens/trips_dashboard_screen.dart';
import '../../features/trips/presentation/screens/trip_form_screen.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/sharing/presentation/screens/shared_trips_screen.dart';
import '../../features/sharing/presentation/screens/manage_shares_screen.dart';
import '../../features/sharing/presentation/screens/accept_invite_screen.dart';
import '../../features/templates/presentation/screens/template_gallery_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/statistics/presentation/screens/statistics_dashboard_screen.dart';
import '../../features/statistics/presentation/screens/year_in_review_screen.dart';
import '../../features/map/presentation/screens/world_map_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Route paths
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String createTrip = '/create-trip';
  static const String editTrip = '/edit-trip';
  static const String tripDetail = '/trips';
  static const String sharedTrips = '/shared';
  static const String manageShares = '/shares';
  static const String acceptInvite = '/invite';
  static const String templates = '/templates';
  static const String achievements = '/achievements';
  static const String statistics = '/statistics';
  static const String worldMap = '/map';
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
      final needsOnboarding = authState.needsOnboarding;
      final currentLocation = state.matchedLocation;
      final isOnSplash = currentLocation == AppRoutes.splash;
      final isOnLogin = currentLocation == AppRoutes.login;
      final isOnRegister = currentLocation == AppRoutes.register;
      final isOnOnboarding = currentLocation == AppRoutes.onboarding;
      final isOnAuthScreen = isOnLogin || isOnRegister;

      // Show splash while checking auth (but NOT if already on auth screens)
      if (isLoading && !isOnSplash && !isOnAuthScreen) {
        return AppRoutes.splash;
      }

      // Redirect to onboarding if user just registered
      if (isAuthenticated && needsOnboarding && !isOnOnboarding) {
        AppLogger.navigation('Redirecting to onboarding (new user)');
        return AppRoutes.onboarding;
      }

      // Redirect to home if authenticated and onboarding complete
      if (isAuthenticated && !needsOnboarding && (isOnLogin || isOnRegister || isOnSplash || isOnOnboarding)) {
        AppLogger.navigation('Redirecting to home (authenticated)');
        return AppRoutes.home;
      }

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isOnLogin && !isOnRegister && !isLoading) {
        AppLogger.navigation('Redirecting to login (not authenticated)');
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
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
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
      // Trip detail route
      GoRoute(
        path: '${AppRoutes.tripDetail}/:id',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripDetailScreen(tripId: tripId);
        },
        routes: [
          // Manage shares route nested under trip
          GoRoute(
            path: 'shares',
            builder: (context, state) {
              final tripId = state.pathParameters['id']!;
              final tripTitle = state.uri.queryParameters['title'] ?? 'Trip';
              return ManageSharesScreen(tripId: tripId, tripTitle: tripTitle);
            },
          ),
        ],
      ),
      // Shared trips screen
      GoRoute(
        path: AppRoutes.sharedTrips,
        builder: (context, state) => const SharedTripsScreen(),
      ),
      // Accept invite route
      GoRoute(
        path: '${AppRoutes.acceptInvite}/:code',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return AcceptInviteScreen(inviteCode: code);
        },
      ),
      // Templates route
      GoRoute(
        path: AppRoutes.templates,
        builder: (context, state) => const TemplateGalleryScreen(),
      ),
      // Achievements route
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      // Statistics routes
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) => const StatisticsDashboardScreen(),
        routes: [
          GoRoute(
            path: 'year-review',
            builder: (context, state) => const YearInReviewScreen(),
          ),
        ],
      ),
      // World Map route
      GoRoute(
        path: AppRoutes.worldMap,
        builder: (context, state) => const WorldMapScreen(),
      ),
    ],
  );
});
