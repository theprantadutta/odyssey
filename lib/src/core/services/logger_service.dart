import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Beautiful logger service for Odyssey app
/// Provides consistent, colorful logging throughout the app
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  /// Network-specific logger with custom formatting
  static final Logger _networkLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  // ─────────────────────────────────────────────────────────────────
  // General Logging
  // ─────────────────────────────────────────────────────────────────

  /// Log trace messages (most verbose)
  static void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log debug messages
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info messages
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error messages
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal/critical messages
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // ─────────────────────────────────────────────────────────────────
  // Network Logging (for API calls)
  // ─────────────────────────────────────────────────────────────────

  /// Log HTTP request
  static void request({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────────');
    buffer.writeln('│ 📤 REQUEST');
    buffer.writeln('├─────────────────────────────────────────────────────────');
    buffer.writeln('│ $method $url');

    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('│ Headers:');
      headers.forEach((key, value) {
        // Hide sensitive data
        if (key.toLowerCase() == 'authorization') {
          buffer.writeln('│   $key: [HIDDEN]');
        } else {
          buffer.writeln('│   $key: $value');
        }
      });
    }

    if (body != null) {
      buffer.writeln('│ Body: ${_truncate(body.toString(), 500)}');
    }

    buffer.write('└─────────────────────────────────────────────────────────');
    _networkLogger.i(buffer.toString());
  }

  /// Log HTTP response
  static void response({
    required int statusCode,
    required String url,
    dynamic body,
    int? durationMs,
  }) {
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final emoji = isSuccess ? '✅' : '❌';
    final statusEmoji = _getStatusEmoji(statusCode);

    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────────');
    buffer.writeln('│ 📥 RESPONSE $emoji');
    buffer.writeln('├─────────────────────────────────────────────────────────');
    buffer.writeln('│ $statusEmoji $statusCode');
    buffer.writeln('│ $url');

    if (durationMs != null) {
      buffer.writeln('│ ⏱️ ${durationMs}ms');
    }

    if (body != null) {
      buffer.writeln('│ Body: ${_truncate(body.toString(), 500)}');
    }

    buffer.write('└─────────────────────────────────────────────────────────');

    if (isSuccess) {
      _networkLogger.i(buffer.toString());
    } else {
      _networkLogger.w(buffer.toString());
    }
  }

  /// Log HTTP error
  static void networkError({
    required String url,
    required String message,
    int? statusCode,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('┌─────────────────────────────────────────────────────────');
    buffer.writeln('│ 🚨 NETWORK ERROR');
    buffer.writeln('├─────────────────────────────────────────────────────────');
    buffer.writeln('│ $url');
    if (statusCode != null) {
      buffer.writeln('│ Status: $statusCode');
    }
    buffer.writeln('│ Message: $message');
    buffer.write('└─────────────────────────────────────────────────────────');

    _networkLogger.e(buffer.toString(), error: error, stackTrace: stackTrace);
  }

  // ─────────────────────────────────────────────────────────────────
  // Feature-specific Logging
  // ─────────────────────────────────────────────────────────────────

  /// Log authentication events
  static void auth(String message, {bool isError = false}) {
    final formatted = '🔐 AUTH: $message';
    if (isError) {
      _logger.e(formatted);
    } else {
      _logger.i(formatted);
    }
  }

  /// Log navigation events
  static void navigation(String message) {
    _logger.d('🧭 NAV: $message');
  }

  /// Log state changes
  static void state(String provider, String message) {
    _logger.d('📦 STATE [$provider]: $message');
  }

  /// Log user actions
  static void action(String message) {
    _logger.i('👆 ACTION: $message');
  }

  /// Log lifecycle events
  static void lifecycle(String message) {
    _logger.t('♻️ LIFECYCLE: $message');
  }

  /// Log storage operations
  static void storage(String message, {bool isError = false}) {
    final formatted = '💾 STORAGE: $message';
    if (isError) {
      _logger.e(formatted);
    } else {
      _logger.d(formatted);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Helper Methods
  // ─────────────────────────────────────────────────────────────────

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... [truncated]';
  }

  static String _getStatusEmoji(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '🟢';
    if (statusCode >= 300 && statusCode < 400) return '🟡';
    if (statusCode >= 400 && statusCode < 500) return '🟠';
    if (statusCode >= 500) return '🔴';
    return '⚪';
  }
}
