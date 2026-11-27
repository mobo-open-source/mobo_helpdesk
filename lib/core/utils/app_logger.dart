import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Debug-only logger: every method is a no-op in release builds, so nothing
/// (including error text that may contain URLs) reaches the device log.
class AppLogger {
  static const String _name = 'MoboHelpdesk';

  static void info(String message, {String? tag}) {
    if (!kDebugMode) return;
    developer.log(message, name: tag ?? _name, level: 800);
  }

  static void warning(String message, {String? tag}) {
    if (!kDebugMode) return;
    developer.log('⚠️ $message', name: tag ?? _name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!kDebugMode) return;
    developer.log(
      '❌ $message',
      name: tag ?? _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void flutter(FlutterErrorDetails details) {
    if (!kDebugMode) return;
    developer.log(
      '🐛 Flutter error: ${details.exceptionAsString()}',
      name: _name,
      level: 1000,
      error: details.exception,
      stackTrace: details.stack,
    );
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  static void platform(Object exception, StackTrace stack) {
    if (!kDebugMode) return;
    developer.log(
      '💥 Uncaught platform error: $exception',
      name: _name,
      level: 1000,
      error: exception,
      stackTrace: stack,
    );
  }
}
