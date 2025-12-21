import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for CNT Mobile App
/// 
/// All URLs are read from .env file - NO hardcoded values.
/// 
/// Required .env variables for production:
/// - ENVIRONMENT=production
/// - API_BASE_URL=https://api.yourdomain.com/api/v1
/// - WEBSOCKET_URL=wss://api.yourdomain.com
/// - MEDIA_BASE_URL=https://your-cloudfront-url.cloudfront.net
/// - LIVEKIT_WS_URL=wss://livekit.yourdomain.com
/// - LIVEKIT_HTTP_URL=https://livekit.yourdomain.com
/// 
/// For development, only ENVIRONMENT=development is needed (uses localhost defaults).
class Environment {
  static bool _initialized = false;
  
  // ============================================
  // DEVELOPMENT URLs (platform-specific defaults)
  // Used when ENVIRONMENT=development and no override in .env
  // ============================================
  static String get _devApiBaseUrl {
    if (kIsWeb) return 'http://localhost:8002/api/v1';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8002/api/v1';
    if (!kIsWeb && Platform.isIOS) return 'http://localhost:8002/api/v1';
    return 'http://localhost:8002/api/v1';
  }
  
  static String get _devWebSocketUrl {
    if (kIsWeb) return 'ws://localhost:8002';
    if (!kIsWeb && Platform.isAndroid) return 'ws://10.0.2.2:8002';
    if (!kIsWeb && Platform.isIOS) return 'ws://localhost:8002';
    return 'ws://localhost:8002';
  }
  
  static String get _devMediaBaseUrl {
    if (kIsWeb) return 'http://localhost:8002';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8002';
    if (!kIsWeb && Platform.isIOS) return 'http://localhost:8002';
    return 'http://localhost:8002';
  }
  
  static String get _devLiveKitWsUrl {
    if (kIsWeb) return 'ws://localhost:7880';
    if (!kIsWeb && Platform.isAndroid) return 'ws://10.0.2.2:7880';
    if (!kIsWeb && Platform.isIOS) return 'ws://localhost:7880';
    return 'ws://localhost:7880';
  }
  
  static String get _devLiveKitHttpUrl {
    if (kIsWeb) return 'http://localhost:7880';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:7880';
    if (!kIsWeb && Platform.isIOS) return 'http://localhost:7880';
    return 'http://localhost:7880';
  }
  
  /// Initialize environment - call this in main() before runApp()
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ Environment: Loaded .env file');
    } catch (e) {
      debugPrint('⚠️ Environment: .env file not found, using defaults (development)');
    }
    
    _initialized = true;
    
    // Log configuration
    debugPrint('📱 Environment Configuration:');
    debugPrint('   ENVIRONMENT: $environment');
    debugPrint('   isProduction: $isProduction');
    debugPrint('   API_BASE_URL: $apiBaseUrl');
    debugPrint('   WEBSOCKET_URL: $webSocketUrl');
    debugPrint('   MEDIA_BASE_URL: $mediaBaseUrl');
    debugPrint('   LIVEKIT_WS_URL: $liveKitWsUrl');
    debugPrint('   LIVEKIT_HTTP_URL: $liveKitHttpUrl');
    
    // Warn if production but missing URLs
    if (isProduction) {
      if (dotenv.maybeGet('API_BASE_URL') == null) {
        debugPrint('⚠️ WARNING: ENVIRONMENT=production but API_BASE_URL not set in .env');
      }
      if (dotenv.maybeGet('MEDIA_BASE_URL') == null) {
        debugPrint('⚠️ WARNING: ENVIRONMENT=production but MEDIA_BASE_URL not set in .env');
      }
    }
  }
  
  // ============================================
  // ENVIRONMENT DETECTION
  // ============================================
  
  /// Current environment: 'development' or 'production'
  /// Priority: --dart-define > .env > default (development)
  static String get environment {
    // 1. Check --dart-define (for CI/CD builds)
    const dartDefine = String.fromEnvironment('ENVIRONMENT');
    if (dartDefine.isNotEmpty) return dartDefine.toLowerCase();
    
    // 2. Check .env file
    final dotenvValue = dotenv.maybeGet('ENVIRONMENT');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue.toLowerCase();
    
    // 3. Default to development
    return 'development';
  }
  
  /// Check if running in production mode
  static bool get isProduction => environment == 'production';
  
  /// Check if running in development mode
  static bool get isDevelopment => environment == 'development';
  
  // ============================================
  // URL GETTERS (from .env or development defaults)
  // ============================================
  
  /// Backend API base URL
  /// Production: MUST be set in .env as API_BASE_URL
  /// Development: Uses localhost (or 10.0.2.2 on Android emulator)
  static String get apiBaseUrl {
    // 1. Check --dart-define override
    const dartDefine = String.fromEnvironment('API_BASE_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    // 2. Check .env file (REQUIRED for production)
    final dotenvValue = dotenv.maybeGet('API_BASE_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    // 3. Development default
    return _devApiBaseUrl;
  }
  
  /// WebSocket URL for real-time communication
  static String get webSocketUrl {
    const dartDefine = String.fromEnvironment('WEBSOCKET_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = dotenv.maybeGet('WEBSOCKET_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devWebSocketUrl;
  }
  
  /// Media/CDN base URL for images, audio, video
  static String get mediaBaseUrl {
    const dartDefine = String.fromEnvironment('MEDIA_BASE_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = dotenv.maybeGet('MEDIA_BASE_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devMediaBaseUrl;
  }
  
  /// LiveKit WebSocket URL
  static String get liveKitWsUrl {
    const dartDefine = String.fromEnvironment('LIVEKIT_WS_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = dotenv.maybeGet('LIVEKIT_WS_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devLiveKitWsUrl;
  }
  
  /// LiveKit HTTP URL
  static String get liveKitHttpUrl {
    const dartDefine = String.fromEnvironment('LIVEKIT_HTTP_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = dotenv.maybeGet('LIVEKIT_HTTP_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devLiveKitHttpUrl;
  }
}
