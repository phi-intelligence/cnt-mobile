import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/environment.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  
  IO.Socket? _socket;
  bool _isConnected = false;
  
  // Stream controllers for different event types
  final _liveStreamStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _speakPermissionRequestedController = StreamController<Map<String, dynamic>>.broadcast();
  
  WebSocketService._internal();
  
  bool get isConnected => _isConnected;
  
  // Streams for listening to events
  Stream<Map<String, dynamic>> get liveStreamStarted => _liveStreamStartedController.stream;
  Stream<Map<String, dynamic>> get speakPermissionRequested => _speakPermissionRequestedController.stream;
  
  Future<void> connect() async {
    if (_isConnected) return;
    try {
      // Use centralized Environment configuration for WebSocket URL
      final url = Environment.webSocketUrl;
      _socket = IO.io(url, <String, dynamic>{
        'path': '/socket.io/',
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
      });

      _socket!.on('connect', (_) {
        _isConnected = true;
        print('✅ WebSocket connected');
      });
      _socket!.on('disconnect', (_) {
        _isConnected = false;
        print('❌ WebSocket disconnected');
      });
      _socket!.on('message', (data) {
        try {
          if (data is String) {
            _handleMessage(json.decode(data));
          } else if (data is Map<String, dynamic>) {
            _handleMessage(data);
          }
        } catch (_) {}
      });
      _socket!.on('live_stream_started', (data) {
        try {
          if (data is Map<String, dynamic>) {
            _liveStreamStartedController.add(data);
            print('📺 Live stream started notification: $data');
          }
        } catch (e) {
          print('Error handling live_stream_started: $e');
        }
      });
      _socket!.on('speak_permission_requested', (data) {
        try {
          if (data is Map<String, dynamic>) {
            _speakPermissionRequestedController.add(data);
            print('🎤 Speak permission requested: $data');
          }
        } catch (e) {
          print('Error handling speak_permission_requested: $e');
        }
      });
      _socket!.on('error', (_) {
        _isConnected = false;
      });
    } catch (_) {
      _isConnected = false;
    }
  }
  
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
    _socket = null;
    _liveStreamStartedController.close();
    _speakPermissionRequestedController.close();
  }
  
  void send(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      print('WebSocket not connected - message not sent');
      return;
    }
    
    try {
      _socket!.emit('message', data);
    } catch (e) {
      print('Error sending WebSocket message: $e');
      _isConnected = false;
      _socket = null;
    }
  }
  
  void _handleMessage(Map<String, dynamic> data) {
    // Handle incoming WebSocket messages
    print('WebSocket message: $data');
    // TODO: Notify listeners based on message type
  }
  
  // Stream listener for specific events
  Stream<String> listenToEvent(String eventType) {
    if (_socket == null) return const Stream.empty();
    return const Stream.empty();
  }
}

