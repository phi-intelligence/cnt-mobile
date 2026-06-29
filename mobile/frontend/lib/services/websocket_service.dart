import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/environment.dart';
import '../utils/app_logger.dart';
import 'auth_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  IO.Socket? _socket;
  bool _isConnected = false;
  final AuthService _authService = AuthService();

  final _liveStreamStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _speakPermissionRequestedController =
      StreamController<Map<String, dynamic>>.broadcast();

  WebSocketService._internal();

  bool get isConnected => _isConnected;

  Stream<Map<String, dynamic>> get liveStreamStarted =>
      _liveStreamStartedController.stream;
  Stream<Map<String, dynamic>> get speakPermissionRequested =>
      _speakPermissionRequestedController.stream;

  Future<void> connect() async {
    if (_isConnected) return;
    try {
      final url = Environment.webSocketUrl;
      final token = await _authService.getToken();

      final options = <String, dynamic>{
        'path': '/socket.io/',
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        if (token != null && token.isNotEmpty) 'auth': {'token': token},
        if (token != null && token.isNotEmpty)
          'extraHeaders': {'Authorization': 'Bearer $token'},
      };

      _socket = IO.io(url, options);

      _socket!.on('connect', (_) {
        _isConnected = true;
        AppLogger.debug('WebSocket connected');
      });
      _socket!.on('disconnect', (_) {
        _isConnected = false;
        AppLogger.debug('WebSocket disconnected');
      });
      _socket!.on('message', (data) {
        try {
          if (data is String) {
            _handleMessage(json.decode(data) as Map<String, dynamic>);
          } else if (data is Map<String, dynamic>) {
            _handleMessage(data);
          }
        } catch (_) {}
      });
      _socket!.on('live_stream_started', (data) {
        try {
          if (data is Map<String, dynamic>) {
            _liveStreamStartedController.add(data);
          }
        } catch (e) {
          AppLogger.warning('Error handling live_stream_started', error: e);
        }
      });
      _socket!.on('speak_permission_requested', (data) {
        try {
          if (data is Map<String, dynamic>) {
            _speakPermissionRequestedController.add(data);
          }
        } catch (e) {
          AppLogger.warning('Error handling speak_permission_requested', error: e);
        }
      });
      _socket!.on('error', (_) {
        _isConnected = false;
      });
    } catch (e) {
      _isConnected = false;
      AppLogger.error('WebSocket connection failed', error: e);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
    _socket = null;
    if (!_liveStreamStartedController.isClosed) {
      _liveStreamStartedController.close();
    }
    if (!_speakPermissionRequestedController.isClosed) {
      _speakPermissionRequestedController.close();
    }
  }

  void send(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      AppLogger.debug('WebSocket not connected - message not sent');
      return;
    }

    try {
      _socket!.emit('message', data);
    } catch (e) {
      AppLogger.error('Error sending WebSocket message', error: e);
      _isConnected = false;
      _socket = null;
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    AppLogger.debug('WebSocket message received');
  }

  Stream<String> listenToEvent(String eventType) {
    if (_socket == null) return const Stream.empty();
    return const Stream.empty();
  }
}
