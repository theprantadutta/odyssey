import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logger_service.dart';
import '../../features/auth/presentation/screens/intro_screen.dart';
import '../../features/auth/presentation/screens/legal_agreement_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/trips/presentation/screens/trips_dashboard_screen.dart';
import '../../features/trips/presentation/screens/trip_form_screen.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/trips/data/models/trip_model.dart';
import '../../features/sharing/presentation/screens/shared_trips_screen.dart';
import '../../features/sharing/presentation/screens/manage_shares_screen.dart';
import '../../features/sharing/presentation/screens/accept_invite_screen.dart';
import '../../features/templates/presentation/screens/template_gallery_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/statistics/presentation/screens/statistics_dashboard_screen.dart';
import '../../features/statistics/presentation/screens/year_in_review_screen.dart';
import '../../features/map/presentation/screens/world_map_screen.dart';
import '../../features/notifications/presentation/screens/notification_history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Route paths
class AppRoutes {
  static const String splash = '/splash';
  static const String intro = '/intro';
  static const String legalAgreement = '/legal';
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
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String subscription = '/subscription';
}

/// Listenable that notifies GoRouter when auth state changes
/// This triggers redirect re-evaluation without rebuilding the entire router
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _subscription = _ref.listen(authProvider, (previous, next) {
      // Only notify if relevant auth fields changed
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.isLoading != next.isLoading ||
          previous?.hasSeenIntro != next.hasSeenIntro ||
          previous?.hasAcceptedTerms != next.hasAcceptedTerms ||
          previous?.needsOnboarding != next.needsOnboarding) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  ProviderSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }
}

/// GoRouter provider - creates router once, uses refreshListenable for auth changes
final routerProvider = Provider<GoRouter>((ref) {
  // Create a notifier that listens to auth changes and triggers router refresh
  final authNotifier = AuthChangeNotifier(ref);
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Read current auth state (don't watch - we use refreshListenable instead)
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final hasSeenIntro = authState.hasSeenIntro;
      final hasAcceptedTerms = authState.hasAcceptedTerms;
      final needsOnboarding = authState.needsOnboarding;

      final currentLocation = state.matchedLocation;
      final isOnSplash = currentLocation == AppRoutes.splash;
      final isOnIntro = currentLocation == AppRoutes.intro;
      final isOnLegalAgreement = currentLocation == AppRoutes.legalAgreement;
      final isOnLogin = currentLocation == AppRoutes.login;
      final isOnRegister = currentLocation == AppRoutes.register;
      final isOnOnboarding = currentLocation == AppRoutes.onboarding;
      final isOnAuthScreen = isOnLogin || isOnRegister;

      // Show splash only during initial auth check (isLoading + not yet authenticated)
      // Don't redirect to splash during logout (isLoading + still authenticated)
      if (isLoading && !isAuthenticated && !isOnSplash && !isOnAuthScreen && !isOnIntro && !isOnLegalAgreement) {
        return AppRoutes.splash;
      }

      // Show intro for first-time users (before authentication)
      if (!isLoading && !hasSeenIntro && !isOnIntro) {
        AppLogger.navigation('Redirecting to intro (first-time user)');
        return AppRoutes.intro;
      }

      // Show legal agreement if intro seen but terms not accepted
      if (!isLoading && hasSeenIntro && !hasAcceptedTerms && !isOnLegalAgreement) {
        AppLogger.navigation('Redirecting to legal agreement (terms not accepted)');
        return AppRoutes.legalAgreement;
      }

      // Redirect to post-auth onboarding if user just registered/logged in
      if (isAuthenticated && needsOnboarding && !isOnOnboarding) {
        AppLogger.navigation('Redirecting to onboarding (new user)');
        return AppRoutes.onboarding;
      }

      // Redirect to home if authenticated and onboarding complete
      // Don't redirect during loading (e.g., logout in progress)
      if (!isLoading && isAuthenticated && !needsOnboarding && (isOnLogin || isOnRegister || isOnSplash || isOnOnboarding || isOnIntro || isOnLegalAgreement)) {
        AppLogger.navigation('Redirecting to home (authenticated)');
        return AppRoutes.home;
      }

      // Redirect to login if not authenticated (but has seen intro and accepted terms)
      if (!isAuthenticated && hasSeenIntro && hasAcceptedTerms && !isOnLogin && !isOnRegister && !isLoading && !isOnIntro) {
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
        path: AppRoutes.intro,
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: AppRoutes.legalAgreement,
        builder: (context, state) => const LegalAgreementScreen(),
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
          final trip = state.extra as TripModel?;
          return TripDetailScreen(tripId: tripId, initialTrip: trip);
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
      // Notifications route
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationHistoryScreen(),
      ),
      // Settings route
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // Subscription route
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
    ],
  );
});
