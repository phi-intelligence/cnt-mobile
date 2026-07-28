import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for CNT Mobile App.
///
/// Production builds must pass URLs via `--dart-define` (see [env.example]).
/// Do not bundle `.env` in release assets — use CI/build scripts instead.
///
/// Example release build (with obfuscation — see `scripts/release_build.sh`):
///   flutter build apk --release --obfuscate --split-debug-info=build/obfuscation \
///     --dart-define=ENVIRONMENT=production \
///     --dart-define=API_BASE_URL=https://api.christnewtabernacle.com/api/v1 \
///     --dart-define=WEBSOCKET_URL=wss://api.christnewtabernacle.com \
///     --dart-define=MEDIA_BASE_URL=https://d126sja5o8ue54.cloudfront.net \
///     --dart-define=LIVEKIT_WS_URL=wss://livekit.christnewtabernacle.com \
///     --dart-define=LIVEKIT_HTTP_URL=https://livekit.christnewtabernacle.com
///
/// Firebase (`google-services.json` / `GoogleService-Info.plist`): API keys are
/// expected in the repo. Restrict them in Google Cloud Console by Android
/// package name + signing SHA-1/SHA-256 and iOS bundle ID.
class Environment {
  static bool _initialized = false;
  static bool _dotenvLoaded = false;
  
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
      _dotenvLoaded = true;
      if (kDebugMode) {
        debugPrint('✅ Environment: Loaded .env file');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ Environment: .env not loaded ($e) — using --dart-define or dev defaults',
        );
      }
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint('📱 Environment Configuration:');
      debugPrint('   ENVIRONMENT: $environment');
      debugPrint('   isProduction: $isProduction');
      debugPrint('   API_BASE_URL: $apiBaseUrl');
      debugPrint('   WEBSOCKET_URL: $webSocketUrl');
      debugPrint('   MEDIA_BASE_URL: $mediaBaseUrl');
      debugPrint('   LIVEKIT_WS_URL: $liveKitWsUrl');
      debugPrint('   LIVEKIT_HTTP_URL: $liveKitHttpUrl');

      if (isProduction) {
        if (_dotenvGet('API_BASE_URL') == null &&
            const String.fromEnvironment('API_BASE_URL').isEmpty) {
          debugPrint('⚠️ WARNING: ENVIRONMENT=production but API_BASE_URL not set');
        }
        if (_dotenvGet('MEDIA_BASE_URL') == null &&
            const String.fromEnvironment('MEDIA_BASE_URL').isEmpty) {
          debugPrint('⚠️ WARNING: ENVIRONMENT=production but MEDIA_BASE_URL not set');
        }
      }
    }
  }

  static String? _dotenvGet(String key) {
    if (!_dotenvLoaded || !dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }
  
  // ============================================
  // ENVIRONMENT DETECTION
  // ============================================
  
  /// Current environment: 'development' or 'production'
  /// Priority: --dart-define > .env > default (development)
  static String get environment {
    const dartDefine = String.fromEnvironment('ENVIRONMENT');
    if (dartDefine.isNotEmpty) return dartDefine.toLowerCase();
    
    final dotenvValue = _dotenvGet('ENVIRONMENT');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue.toLowerCase();
    
    return 'development';
  }
  
  /// Check if running in production mode
  static bool get isProduction => environment == 'production';
  
  /// Check if running in development mode
  static bool get isDevelopment => environment == 'development';
  
  // ============================================
  // URL GETTERS (--dart-define > .env > dev defaults)
  // ============================================
  
  /// Backend API base URL
  static String get apiBaseUrl {
    const dartDefine = String.fromEnvironment('API_BASE_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = _dotenvGet('API_BASE_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devApiBaseUrl;
  }
  
  /// WebSocket URL for real-time communication
  static String get webSocketUrl {
    const dartDefine = String.fromEnvironment('WEBSOCKET_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = _dotenvGet('WEBSOCKET_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devWebSocketUrl;
  }
  
  /// Media/CDN base URL for images, audio, video
  static String get mediaBaseUrl {
    const dartDefine = String.fromEnvironment('MEDIA_BASE_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = _dotenvGet('MEDIA_BASE_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devMediaBaseUrl;
  }
  
  /// LiveKit WebSocket URL
  static String get liveKitWsUrl {
    const dartDefine = String.fromEnvironment('LIVEKIT_WS_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = _dotenvGet('LIVEKIT_WS_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devLiveKitWsUrl;
  }
  
  /// LiveKit HTTP URL
  static String get liveKitHttpUrl {
    const dartDefine = String.fromEnvironment('LIVEKIT_HTTP_URL');
    if (dartDefine.isNotEmpty) return dartDefine;
    
    final dotenvValue = _dotenvGet('LIVEKIT_HTTP_URL');
    if (dotenvValue != null && dotenvValue.isNotEmpty) return dotenvValue;
    
    return _devLiveKitHttpUrl;
  }

  /// Platform organization recipient for profile "Donate" (Paystack).
  static int get organizationRecipientUserId {
    const dartDefine = int.fromEnvironment(
      'ORGANIZATION_RECIPIENT_USER_ID',
      defaultValue: 0,
    );
    if (dartDefine > 0) return dartDefine;

    final dotenvValue = _dotenvGet('ORGANIZATION_RECIPIENT_USER_ID');
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return int.tryParse(dotenvValue) ?? 1;
    }
    return 1;
  }
}
