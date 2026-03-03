import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/storage_service.dart';

part 'theme_provider.g.dart';

/// Theme mode state notifier provider
@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() {
    // Load theme preference after initialization
    Future.microtask(() => _loadTheme());
    return ThemeMode.light; // Default
  }

  Future<void> _loadTheme() async {
    final storage = StorageService();
    final isDark = await storage.getThemeMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    await StorageService().setThemeMode(newMode == ThemeMode.dark);
    final isDark = newMode == ThemeMode.dark;
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(analytics.trackDarkModeToggled(enabled: isDark));
    unawaited(analytics.setUserProperty(name: 'theme_mode', value: isDark ? 'dark' : 'light'));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await StorageService().setThemeMode(mode == ThemeMode.dark);
  }
}
