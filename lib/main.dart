import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/common/theme/app_theme.dart';
import 'src/common/theme/theme_provider.dart';
import 'src/core/database/database_service.dart';
import 'src/core/network/dio_client.dart';
import 'src/core/providers/connectivity_provider.dart';
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

class OdysseyApp extends ConsumerWidget {
  const OdysseyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _OfflineBannerWrapper(),
            ),
          ],
        );
      },
    );
  }
}

/// Wrapper to show offline banner at the top of the app
class _OfflineBannerWrapper extends ConsumerWidget {
  const _OfflineBannerWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    if (isOnline) return const SizedBox.shrink();

    return Material(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              "You're offline. Changes will sync when connected.",
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
