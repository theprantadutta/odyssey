import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/common/theme/app_theme.dart';
import 'src/core/network/dio_client.dart';
import 'src/core/router/app_router.dart';
import 'src/core/services/logger_service.dart';
import 'src/core/services/notification_service.dart';

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

    return MaterialApp.router(
      title: 'Odyssey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
