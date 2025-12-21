import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform detection utilities matching React Native implementation
class PlatformUtils {
  PlatformUtils._();

  /// Check if running on iOS
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  /// Check if running on Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on mobile (iOS or Android)
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Get platform name
  static String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  /// Get API URL based on platform (matching React Native logic)
  static String get apiUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (isIOS) {
      return 'http://localhost:8000';
    } else if (isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://10.0.2.2:8002';
    }
    return 'http://localhost:8000';
  }

  /// Get bottom tab bar height based on platform
  static double get bottomTabBarHeight {
    if (isIOS) return 85.0;
    if (isAndroid) return 60.0;
    return 60.0; // Web default
  }

  /// Get bottom tab bar padding
  static EdgeInsets get bottomTabBarPadding {
    if (isIOS) {
      return const EdgeInsets.only(top: 8, bottom: 20);
    }
    return const EdgeInsets.only(top: 8, bottom: 8);
  }
}

