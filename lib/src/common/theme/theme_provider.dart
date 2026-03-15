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
    Future.microtask(() => _loadTheme());
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final storage = StorageService();
    final value = await storage.getThemeModeValue();
    state = _parseThemeMode(value);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await StorageService().setThemeModeValue(_themeModeToString(mode));
    final analytics = ref.read(analyticsServiceProvider);
    final modeStr = _themeModeToString(mode);
    unawaited(analytics.setUserProperty(name: 'theme_mode', value: modeStr));
  }

  Future<void> toggle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }

  ThemeMode _parseThemeMode(String value) => switch (value) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  String _themeModeToString(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'dark',
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
  };
}
