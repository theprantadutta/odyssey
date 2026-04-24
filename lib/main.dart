import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:in_app_update/in_app_update.dart';
import 'firebase_options.dart';
import 'src/common/theme/app_theme.dart';
import 'src/common/theme/theme_provider.dart';
import 'src/core/database/database_service.dart';
import 'src/core/network/dio_client.dart';

import 'src/core/router/app_router.dart';
import 'src/core/services/connectivity_service.dart';
import 'src/core/services/logger_service.dart';
import 'src/core/services/notification_service.dart';
import 'src/core/sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

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
  SyncService().initialize();

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

class _OdysseyAppState extends ConsumerState<OdysseyApp> {
  /// Check for app updates and perform immediate update if available
  Future<void> checkForAppUpdate() async {
    AppLogger.info('Checking for app update...');

    if (!mounted) return;

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      AppLogger.info('Update availability: ${updateInfo.updateAvailability}');
      AppLogger.info(
        'Immediate update allowed: ${updateInfo.immediateUpdateAllowed}',
      );
      AppLogger.info(
        'Flexible update allowed: ${updateInfo.flexibleUpdateAllowed}',
      );

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        AppLogger.info('Update available! Starting immediate update flow.');

        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          AppLogger.info('Immediate update completed.');
        } else if (updateInfo.flexibleUpdateAllowed) {
          AppLogger.info(
            'Immediate update not allowed, falling back to flexible update.',
          );
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          AppLogger.info('Flexible update completed.');
        }
      } else {
        AppLogger.info('No update available.');
      }
    } catch (e) {
      AppLogger.error('Error checking for app update', e);
      // Silently fail - don't block the user if update check fails
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForAppUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'Odyssey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
