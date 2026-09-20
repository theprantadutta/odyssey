import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Prefixed deliberately: material_ui re-exports the whole Material surface
// and would otherwise collide with package:flutter/material.dart on
// MaterialApp, ThemeData, Colors and the rest.
import 'package:material_ui/material_ui.dart' as material_ui;
import 'firebase_options.dart';
import 'src/core/config/admob_config.dart';
import 'src/features/ads/presentation/providers/ads_providers.dart';
import 'src/common/theme/app_theme.dart';
import 'src/common/theme/theme_provider.dart';
import 'src/core/database/database_service.dart';
import 'src/core/network/dio_client.dart';

import 'src/core/router/app_router.dart';
import 'src/core/services/app_update_service.dart';
import 'src/core/services/connectivity_service.dart';
import 'src/core/services/logger_service.dart';
import 'src/core/services/notification_service.dart';
import 'src/features/subscription/presentation/providers/purchase_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Hold the native splash until the Dart splash screen is on screen and can
  // take over without a seam. It lifts in SplashScreen.initState.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize the Google Mobile Ads SDK (ads are shown to free users only;
  // every ad surface is gated behind adsEnabledProvider). Failures are
  // swallowed so ad infrastructure can never block app startup.
  if (AdMobConfig.isSupportedPlatform) {
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: AdMobConfig.testDeviceIds),
      );
      AppLogger.info('Google Mobile Ads initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize Google Mobile Ads', e);
    }
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    AppLogger.info('Firebase initialized successfully');
  } catch (e) {
    AppLogger.error('Failed to initialize Firebase', e);
  }

  // Initialize notification service (must be after Firebase init)
  try {
    await NotificationService().initialize();
    AppLogger.info('Notification service initialized');
  } catch (e) {
    AppLogger.error('Failed to initialize notification service', e);
  }

  // Initialize Dio client with interceptors
  DioClient().init();

  // Initialize offline infrastructure
  await DatabaseService().initialize();
  await ConnectivityService().initialize();
  // The sync session is opened per account once someone is signed in; starting
  // it here would run unscoped work before we know whose it is.

  runApp(
    const ProviderScope(
      child: OdysseyApp(),
    ),
  );
}

class OdysseyApp extends ConsumerStatefulWidget {
  const OdysseyApp({super.key});

  @override
  ConsumerState<OdysseyApp> createState() => _OdysseyAppState();
}

class _OdysseyAppState extends ConsumerState<OdysseyApp>
    with WidgetsBindingObserver {
  /// Resume events arrive in bursts (the billing sheet closing is itself a
  /// resume), so reconciling is throttled just enough to collapse those.
  static const Duration _storeReconcileInterval = Duration(seconds: 10);

  DateTime? _lastStoreReconcile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
      // Bring the store connection up at launch, not on first paywall view.
      // StoreKit replays every unfinished transaction on launch, and Play
      // refunds anything left unacknowledged for 3 days - both need a listener
      // attached and a reconcile run before the user goes anywhere near a
      // purchase screen.
      ref.read(purchaseProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _reconcileStoreState();
    }
  }

  /// Fulfil anything the store now reports as owned.
  ///
  /// This is how a deferred ("slow test card", cash, parental approval) payment
  /// that cleared in the background finally unlocks Premium, and how a purchase
  /// whose verification was queued while we were offline gets replayed.
  void _reconcileStoreState() {
    final last = _lastStoreReconcile;
    if (last != null &&
        DateTime.now().difference(last) < _storeReconcileInterval) {
      return;
    }
    _lastStoreReconcile = DateTime.now();

    unawaited(ref.read(purchaseProvider.notifier).reconcileStoreState());
  }

  Future<void> _checkForAppUpdate() async {
    if (!mounted) return;
    await AppUpdateService.instance.checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // Bootstrap ad infrastructure for the session. These are no-ops for premium
    // users and unsupported platforms; the consent flow runs in the background
    // and the app-open manager begins observing the app lifecycle.
    ref.watch(adConsentProvider);
    ref.watch(appOpenAdManagerProvider);
    ref.watch(interstitialAdManagerProvider);
    ref.watch(rewardedAdManagerProvider);

    return MaterialApp.router(
      title: 'Odyssey',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppUpdateService.messengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // Material is being split out of the framework into package:material_ui,
      // and go_router 18 has already moved. That package declares its own
      // MaterialLocalizations - a distinct Dart type that the framework's
      // delegates cannot satisfy - so without these a migrated widget throws
      // "No MaterialLocalizations found" at runtime, from a stack frame in
      // material_ui, nowhere near whatever the user was actually doing.
      //
      // Both sets coexist. material_ui ships 80 locales, so this costs no
      // coverage. They come out again once the app itself has migrated.
      localizationsDelegates: const [
        ...material_ui.GlobalMaterialLocalizations.delegates,
      ],
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
