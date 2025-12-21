import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/auth_service.dart';

class LiveStreamNotification {
  final int streamId;
  final String hostName;
  final int? hostId;
  final String streamTitle;
  final String roomName;
  final DateTime timestamp;

  LiveStreamNotification({
    required this.streamId,
    required this.hostName,
    this.hostId,
    required this.streamTitle,
    required this.roomName,
    required this.timestamp,
  });
}

class NotificationProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final AuthService _authService = AuthService();
  StreamSubscription<Map<String, dynamic>>? _liveStreamSubscription;
  
  LiveStreamNotification? _currentNotification;
  bool _isDismissed = false;
  int? _currentUserId;
  bool _isUserIdInitialized = false;
  Completer<void>? _initCompleter;

  LiveStreamNotification? get currentNotification => _currentNotification;
  bool get hasNotification => _currentNotification != null && !_isDismissed;

  NotificationProvider() {
    _initializeAsync();
  }

  /// Initialize asynchronously to ensure user ID is loaded before processing notifications
  Future<void> _initializeAsync() async {
    await _initCurrentUser();
    _setupListeners();
  }

  Future<void> _initCurrentUser() async {
    // Use completer to ensure concurrent calls wait for the same initialization
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    _initCompleter = Completer<void>();
    
    try {
      final user = await _authService.getUser();
      if (user != null) {
        // Handle both int and String ID types
        final idRaw = user['id'];
        if (idRaw is int) {
          _currentUserId = idRaw;
        } else if (idRaw is String) {
          _currentUserId = int.tryParse(idRaw);
        } else if (idRaw != null) {
          _currentUserId = int.tryParse(idRaw.toString());
        }
        debugPrint('✅ NotificationProvider: Current user ID set to $_currentUserId');
      } else {
        debugPrint('⚠️ NotificationProvider: No user found');
      }
      _isUserIdInitialized = true;
    } catch (e) {
      debugPrint('❌ Error getting current user for notifications: $e');
      _isUserIdInitialized = true; // Mark as initialized even on error to avoid infinite waits
    } finally {
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  void _setupListeners() {
    _liveStreamSubscription = _wsService.liveStreamStarted.listen((data) async {
      // Ensure current user ID is loaded - wait with timeout
      if (!_isUserIdInitialized || _currentUserId == null) {
        await _initCurrentUser();
        // Add small delay and retry once more if still null
        if (_currentUserId == null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await _initCurrentUser();
        }
      }
      
      // Extract host_id - handle both int and String types
      final hostIdRaw = data['host_id'];
      int? hostId;
      if (hostIdRaw is int) {
        hostId = hostIdRaw;
      } else if (hostIdRaw is String) {
        hostId = int.tryParse(hostIdRaw);
      } else if (hostIdRaw != null) {
        hostId = int.tryParse(hostIdRaw.toString());
      }
      
      // Skip notification if the current user is the host
      if (hostId != null) {
        if (_currentUserId != null && hostId == _currentUserId) {
          debugPrint('📺 Skipping self-notification for live stream (host_id: $hostId, current_user_id: $_currentUserId)');
        return;
        }
        // If we still don't have user ID but have host ID, skip to be safe
        // (better to miss notification than show to host)
        if (_currentUserId == null) {
          debugPrint('⚠️ Cannot determine if user is host - user ID not available. Skipping notification for safety.');
          return;
        }
      }
      
      debugPrint('📺 Showing live stream notification (host_id: $hostId, current_user_id: $_currentUserId)');
      
      _currentNotification = LiveStreamNotification(
        streamId: data['stream_id'] as int? ?? 0,
        hostName: data['host_name'] as String? ?? 'Unknown',
        hostId: hostId,
        streamTitle: data['stream_title'] as String? ?? 'Live Stream',
        roomName: data['room_name'] as String? ?? '',
        timestamp: DateTime.now(),
      );
      _isDismissed = false;
      notifyListeners();
    });
  }

  /// Update the current user ID (call after login)
  void updateCurrentUserId(int? userId) {
    _currentUserId = userId;
    debugPrint('✅ NotificationProvider: User ID updated to $_currentUserId');
  }
  
  /// Refresh current user ID from auth service
  Future<void> refreshCurrentUserId() async {
    await _initCurrentUser();
  }

  void dismissNotification() {
    _isDismissed = true;
    notifyListeners();
  }

  void clearNotification() {
    _currentNotification = null;
    _isDismissed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _liveStreamSubscription?.cancel();
    super.dispose();
  }
}
