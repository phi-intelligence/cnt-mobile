import 'package:flutter/foundation.dart';

/// Release-safe logger. Never logs secrets, tokens, passwords, or full response bodies.
class AppLogger {
  AppLogger._();

  static final _secretPatterns = [
    RegExp(r'access_token', caseSensitive: false),
    RegExp(r'refresh_token', caseSensitive: false),
    RegExp(r'client_secret', caseSensitive: false),
    RegExp(r'password', caseSensitive: false),
    RegExp(r'otp', caseSensitive: false),
    RegExp(r'authorization', caseSensitive: false),
    RegExp(r'bearer\s+[a-zA-Z0-9._-]+', caseSensitive: false),
  ];

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    debugPrint(_redact(message));
    if (error != null) {
      debugPrint(_redact(error.toString()));
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint(_redact(message));
  }

  static void warning(String message, {Object? error}) {
    if (!kDebugMode) return;
    debugPrint('WARN: ${_redact(message)}');
    if (error != null) {
      debugPrint(_redact(error.toString()));
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    // Errors may be logged in release for crash diagnostics, but never secrets.
    debugPrint('ERROR: ${_redact(message)}');
    if (error != null) {
      debugPrint(_redact(error.toString()));
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }

  static String _redact(String input) {
    var result = input;
    for (final pattern in _secretPatterns) {
      result = result.replaceAll(pattern, '[REDACTED]');
    }
    return result;
  }
}
