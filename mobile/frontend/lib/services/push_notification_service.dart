import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/environment.dart';
import '../utils/pinned_http_client.dart';
import 'auth_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background handling
  await Firebase.initializeApp();
  
  if (kDebugMode) {
    debugPrint('🔔 Background message received: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
  }
  
  // Handle background message - e.g., show local notification
  // Note: On Android, FCM automatically shows notifications when app is in background
  // On iOS, the notification is shown by the system
}

/// Service for handling Firebase Cloud Messaging push notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();
  
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  
  /// Callback for when a notification is tapped (app opened from notification)
  void Function(Map<String, dynamic> data)? onNotificationTap;
  
  /// Callback for foreground notifications
  void Function(RemoteMessage message)? onForegroundMessage;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize the push notification service
  /// Call this after Firebase.initializeApp() in main.dart
  Future<void> initialize() async {
    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permissions (required for iOS, Android 13+)
      await _requestPermissions();
      
      // Get the initial FCM token
      await _getToken();
      
      // Listen for token refresh
      _setupTokenRefreshListener();
      
      // Handle foreground messages
      _setupForegroundMessageHandler();
      
      // Handle notification tap when app is in background/terminated
      _setupNotificationTapHandlers();
      
      if (kDebugMode) {
        debugPrint('✅ Push notification service initialized');
        debugPrint('   FCM Token: ${_fcmToken?.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing push notifications: $e');
      }
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (kDebugMode) {
      debugPrint('🔔 Notification permission status: ${settings.authorizationStatus}');
    }
    
    // For iOS, also configure foreground presentation options
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Get the FCM token and register with backend
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting FCM token: $e');
      }
    }
  }

  /// Set up listener for token refresh
  void _setupTokenRefreshListener() {
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      if (kDebugMode) {
        debugPrint('🔄 FCM token refreshed');
      }
      _fcmToken = newToken;
      await _registerTokenWithBackend(newToken);
    });
  }

  /// Set up handler for foreground messages
  void _setupForegroundMessageHandler() {
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('🔔 Foreground message received:');
        debugPrint('   Title: ${message.notification?.title}');
        debugPrint('   Body: ${message.notification?.body}');
        debugPrint('   Data: ${message.data}');
      }
      
      // Call the callback if set
      onForegroundMessage?.call(message);
      
      // Handle specific notification types
      _handleNotificationData(message.data);
    });
  }

  /// Set up handlers for notification taps
  void _setupNotificationTapHandlers() {
    // Handle notification tap when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('🔔 App opened from terminated state via notification');
        }
        _handleNotificationTap(message.data);
      }
    });
    
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('🔔 App opened from background via notification');
      }
      _handleNotificationTap(message.data);
    });
  }

  /// Handle notification tap - navigate to appropriate screen
  void _handleNotificationTap(Map<String, dynamic> data) {
    onNotificationTap?.call(data);
    
    // Handle specific notification types
    final type = data['type'] as String?;
    switch (type) {
      case 'live_stream':
        final streamId = data['stream_id'] as String?;
        if (streamId != null) {
          // Navigate to live stream - this will be handled by the callback
          if (kDebugMode) {
            debugPrint('📺 Navigating to live stream: $streamId');
          }
        }
        break;
      case 'new_content':
        final contentType = data['content_type'] as String?;
        final contentId = data['content_id'] as String?;
        if (contentType != null && contentId != null) {
          if (kDebugMode) {
            debugPrint('📦 Navigating to content: $contentType/$contentId');
          }
        }
        break;
      default:
        if (kDebugMode) {
          debugPrint('🔔 Unhandled notification type: $type');
        }
    }
  }

  /// Handle notification data payload
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'live_stream':
        // A live stream has started - could show an in-app banner
        if (kDebugMode) {
          debugPrint('📺 Live stream started: ${data['stream_title']}');
        }
        break;
      default:
        break;
    }
  }

  /// Register the FCM token with the backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      // Check if user is authenticated
      final authHeaders = await _authService.getAuthHeaders();
      if (authHeaders.isEmpty || !authHeaders.containsKey('Authorization')) {
        if (kDebugMode) {
          debugPrint('⚠️ User not authenticated, skipping token registration');
        }
        return;
      }
      
      final platform = Platform.isIOS ? 'ios' : 'android';
      final baseUrl = Environment.apiBaseUrl;
      
      final response = await PinnedHttpClient.instance.post(
        Uri.parse('$baseUrl/device-tokens/register'),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: json.encode({
          'token': token,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          debugPrint('✅ FCM token registered with backend');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ Failed to register token: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error registering FCM token with backend: $e');
      }
    }
  }

  /// Register token when user logs in
  /// Call this after successful authentication
  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    } else {
      await _getToken();
    }
  }

  /// Unregister token when user logs out
  /// Call this before clearing auth state
  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;
    
    try {
      final authHeaders = await _authService.getAuthHeaders();
      if (authHeaders.isEmpty) return;
      
      final baseUrl = Environment.apiBaseUrl;
      
      await PinnedHttpClient.instance.delete(
        Uri.parse('$baseUrl/device-tokens'),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: json.encode({
          'token': _fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        debugPrint('✅ FCM token unregistered from backend');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error unregistering FCM token: $e');
      }
    }
  }

  /// Subscribe to a topic (e.g., 'live_streams', 'announcements')
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('✅ Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error subscribing to topic $topic: $e');
      }
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('✅ Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error unsubscribing from topic $topic: $e');
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
  }
}

