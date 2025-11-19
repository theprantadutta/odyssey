import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/common/theme/app_theme.dart';
import 'src/core/network/dio_client.dart';
import 'src/core/router/app_router.dart';

void main() {
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
