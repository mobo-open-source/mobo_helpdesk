import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _name = 'MoboHelpdesk';

  static void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? _name, level: 800);
  }

  static void warning(String message, {String? tag}) {
    developer.log('⚠️ $message', name: tag ?? _name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    developer.log(
      '❌ $message',
      name: tag ?? _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void flutter(FlutterErrorDetails details) {
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
    developer.log(
      '💥 Uncaught platform error: $exception',
      name: _name,
      level: 1000,
      error: exception,
      stackTrace: stack,
    );
  }
}
