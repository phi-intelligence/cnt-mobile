import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Platform detection utilities (Mobile-only app)
class PlatformHelper {
  /// Check if running on web platform (always false for mobile app)
  static bool isWebPlatform() {
    return kIsWeb;
  }
  
  /// Check if running on mobile platform (iOS or Android)
  static bool isMobilePlatform() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }
  
  /// Check if running on iOS
  static bool isIOS() {
    return !kIsWeb && Platform.isIOS;
  }
  
  /// Check if running on Android
  static bool isAndroid() {
    return !kIsWeb && Platform.isAndroid;
  }
  
  /// Get screen type based on width
  static ScreenType getScreenType(double width) {
    if (width < 600) {
      return ScreenType.mobile;
    } else if (width < 1024) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }
  
  /// Get base URL for API calls based on platform and environment
  /// 
  /// For development:
  /// - Android emulator: 10.0.2.2:8002 (maps to host localhost)
  /// - iOS simulator: localhost:8002
  /// - Physical device: Use --dart-define=API_BASE=http://YOUR_IP:8002/api/v1
  /// 
  /// For production:
  /// - Use --dart-define=API_BASE=https://your-production-backend.com/api/v1
  static String getApiBaseUrl() {
    // Check for environment variable first (production or custom dev)
    const envUrl = String.fromEnvironment('API_BASE');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Check if this is a production build
    const isProd = bool.fromEnvironment('dart.vm.product');
    if (isProd) {
      // Production: should always use API_BASE env var
      // Fallback to production URL placeholder - replace with actual URL
      return 'https://YOUR_BACKEND_URL/api/v1';
    }
    
    // Development defaults
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8002/api/v1';
    } else if (Platform.isIOS) {
      return 'http://localhost:8002/api/v1';
    }
    
    // Fallback
    return 'http://10.0.2.2:8002/api/v1';
  }
  
  /// Get WebSocket URL for real-time features
  static String getWebSocketUrl() {
    const envUrl = String.fromEnvironment('WS_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    const isProd = bool.fromEnvironment('dart.vm.product');
    if (isProd) {
      return 'wss://YOUR_BACKEND_URL';
    }
    
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8002';
    } else if (Platform.isIOS) {
      return 'ws://localhost:8002';
    }
    
    return 'ws://10.0.2.2:8002';
  }
  
  /// Get LiveKit WebSocket URL
  static String getLiveKitUrl() {
    const envUrl = String.fromEnvironment('LIVEKIT_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    const isProd = bool.fromEnvironment('dart.vm.product');
    if (isProd) {
      return 'wss://YOUR_LIVEKIT_URL';
    }
    
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:7880';
    } else if (Platform.isIOS) {
      return 'ws://localhost:7880';
    }
    
    return 'ws://10.0.2.2:7880';
  }
}

/// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
}
