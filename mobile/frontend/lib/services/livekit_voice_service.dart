import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'api_service.dart';

/// Service for managing LiveKit voice agent connections
class LiveKitVoiceService {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _isConnected = false;
  final ApiService _apiService = ApiService();
  
  // Streams for UI updates
  final _connectionStateController = StreamController<lk.ConnectionState>.broadcast();
  final _agentStateController = StreamController<String>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  
  Stream<lk.ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get agentState => _agentStateController.stream;
  Stream<String> get transcript => _transcriptController.stream;
  
  bool get isConnected => _isConnected;
  lk.Room? get room => _room;
  
  /// Connect to LiveKit room for voice agent
  /// Retries up to 3 times with exponential backoff
  Future<void> connectToRoom({
    required String roomName,
    String? userIdentity,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;
    
    while (attempt < maxRetries) {
    try {
        attempt++;
        print('🎤 LiveKit: Connection attempt $attempt/$maxRetries for room: $roomName');
      
        // Get access token from backend with timeout
      final tokenResponse = await _apiService.getLiveKitVoiceToken(
        roomName,
        userIdentity: userIdentity,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Token request timed out after 10 seconds');
          },
      );
        
        if (!tokenResponse.containsKey('token') || tokenResponse['token'] == null) {
          throw Exception('Invalid token response: missing token');
        }
      
      final token = tokenResponse['token'] as String;
      // Always use frontend's URL detection (ignores backend's ws_url which may be localhost)
      // Frontend knows the correct IP for the device (192.168.0.14 for physical devices)
      final wsUrl = _apiService.getLiveKitUrl();
      
      print('🎤 LiveKit: Token received, connecting to $wsUrl');
      print('🎤 LiveKit: Backend suggested URL: ${tokenResponse['ws_url']} (ignored for device compatibility)');
      
      // Create room with audio-only options
      final roomOptions = lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: const lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
      
        // Create room instance and connect with timeout
      _room = lk.Room(roomOptions: roomOptions);
        await _room!.connect(wsUrl, token).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Connection to LiveKit server timed out after 30 seconds. Check server URL: $wsUrl');
          },
        );
      
        print('🎤 LiveKit: Connected to room successfully');
      
      // Set up event listener
      _listener = _room!.createListener();
      _setupEventHandlers();
      
      // Enable microphone
      if (_room != null && _room!.localParticipant != null) {
        await _room!.localParticipant!.setMicrophoneEnabled(true);
          print('🎤 LiveKit: Microphone enabled');
      }
      
      _isConnected = true;
      _connectionStateController.add(_room!.connectionState);
      
        // Success - exit retry loop
        return;
        
      } on TimeoutException catch (e) {
        lastError = e;
        print('❌ LiveKit: Connection timeout (attempt $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = 1 << (attempt - 1);
          print('🔄 LiveKit: Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
    } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('❌ LiveKit: Connection error (attempt $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = 1 << (attempt - 1);
          print('🔄 LiveKit: Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      } finally {
        // Clean up on failure
        if (!_isConnected && _room != null) {
          try {
            await _room!.disconnect();
          } catch (_) {}
          _room = null;
          _listener?.dispose();
          _listener = null;
        }
      }
    }
    
    // All retries failed
    _isConnected = false;
    final errorMessage = lastError?.toString() ?? 'Unknown connection error';
    throw Exception('Failed to connect after $maxRetries attempts. Last error: $errorMessage');
  }
  
  void _setupEventHandlers() {
    if (_listener == null || _room == null) return;
    
    // Connection state changes
    _room!.addListener(_onRoomChanged);
    
    // Participant events
    _listener!
      ..on<lk.ParticipantConnectedEvent>((event) {
        print('🎤 LiveKit: Participant connected: ${event.participant.identity}');
        if (event.participant.kind == lk.ParticipantKind.AGENT) {
          _onAgentConnected(event.participant as lk.RemoteParticipant);
        }
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        print('🎤 LiveKit: Participant disconnected: ${event.participant.identity}');
        if (event.participant.kind == lk.ParticipantKind.AGENT) {
          _onAgentDisconnected();
        }
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        print('🎤 LiveKit: Track subscribed: ${event.track.kind}, participant: ${event.participant.identity}, kind: ${event.participant.kind}');
        if (event.participant.kind == lk.ParticipantKind.AGENT) {
          if (event.track.kind == lk.TrackType.AUDIO) {
            final audioTrack = event.track as lk.RemoteAudioTrack;
            print('🎤 LiveKit: Agent audio track subscribed - sid: ${audioTrack.sid}');
            _onAgentAudioTrack(audioTrack);
          }
        }
      })
      ..on<lk.DataReceivedEvent>((event) {
        // Handle text transcripts or other data
        if (event.participant?.kind == lk.ParticipantKind.AGENT) {
          // DataReceivedEvent.data is Uint8List
          final data = event.data;
          if (data is Uint8List) {
            _handleAgentData(data);
          } else if (data is List<int>) {
            _handleAgentData(Uint8List.fromList(data));
          }
        }
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        print('🎤 LiveKit: Room disconnected');
        _isConnected = false;
        _connectionStateController.add(lk.ConnectionState.disconnected);
      });
  }
  
  void _onRoomChanged() {
    if (_room != null) {
      _connectionStateController.add(_room!.connectionState);
    }
  }
  
  void _onAgentConnected(lk.RemoteParticipant agent) {
    print('🎤 LiveKit: Agent connected, identity: ${agent.identity}, kind: ${agent.kind}');
    print('🎤 LiveKit: Agent metadata: ${agent.metadata}');
    
    // Function to parse and update agent state from metadata
    void updateAgentStateFromMetadata(String? metadata) {
      print('🎤 LiveKit: Updating agent state from metadata: $metadata');
      if (metadata == null || metadata.isEmpty) {
        // If no metadata, check if we have audio tracks (agent is ready)
        // Don't set to initializing if agent has audio tracks
        final hasAudioTracks = agent.audioTrackPublications.isNotEmpty;
        if (hasAudioTracks) {
          print('🎤 LiveKit: Agent has audio tracks but no metadata, setting to listening');
          _agentStateController.add('listening');
        } else {
          _agentStateController.add('initializing');
        }
        return;
      }
      
        try {
        // First try: Parse as JSON
        final jsonData = jsonDecode(metadata) as Map<String, dynamic>;
        final state = jsonData['lk.agent.state'] ?? 
                     jsonData['state'] ?? 
                     jsonData['agent_state'] ??
                     jsonData['status'];
        if (state is String && state.isNotEmpty) {
            _agentStateController.add(state);
          return;
          }
      } catch (_) {
        // Not JSON, continue to next parsing method
      }
      
      try {
        // Second try: Parse as query string
        final queryParams = Uri.splitQueryString(metadata);
        final state = queryParams['lk.agent.state'] ?? 
                     queryParams['state'] ?? 
                     queryParams['agent_state'] ??
                     queryParams['status'];
        if (state != null && state.isNotEmpty) {
          _agentStateController.add(state);
          return;
        }
      } catch (_) {
        // Not query string, continue
      }
      
      // Third try: Check if metadata contains state keywords
      final lowerMetadata = metadata.toLowerCase();
      if (lowerMetadata.contains('speaking')) {
        _agentStateController.add('speaking');
      } else if (lowerMetadata.contains('listening')) {
        _agentStateController.add('listening');
      } else if (lowerMetadata.contains('thinking')) {
        _agentStateController.add('thinking');
      } else if (lowerMetadata.contains('initializing')) {
        _agentStateController.add('initializing');
      } else {
        // Default: use metadata as-is or set default state
        _agentStateController.add(metadata.length > 50 ? 'initializing' : metadata);
      }
    }
    
    // Monitor agent state from participant metadata changes
    agent.addListener(() {
      updateAgentStateFromMetadata(agent.metadata);
    });
    
    // Check existing metadata immediately
    updateAgentStateFromMetadata(agent.metadata);
    
    // Also check for agent in room's remote participants
    if (_room != null) {
      for (final participant in _room!.remoteParticipants.values) {
        if (participant.kind == lk.ParticipantKind.AGENT && participant.identity == agent.identity) {
          updateAgentStateFromMetadata(participant.metadata);
          break;
        }
      }
    }
  }
  
  void _onAgentDisconnected() {
    _agentStateController.add('disconnected');
  }
  
  void _onAgentAudioTrack(lk.RemoteAudioTrack track) {
    print('🎤 LiveKit: Agent audio track ready - sid: ${track.sid}');
    
    try {
      // On web, LiveKit SDK automatically attaches tracks to HTML audio elements
      // The track should start playing automatically once subscribed
      // The SDK handles all audio playback internally
      print('🎤 LiveKit: Agent audio track is ready for playback');
      print('🎤 LiveKit: Track details - sid: ${track.sid}, kind: ${track.kind}');
      print('🎤 LiveKit: Audio track should now be playing in browser automatically');
      print('🎤 LiveKit: If no audio, check browser console for autoplay restrictions');
      
      // Update state to indicate agent is ready (since we have audio track)
      // The agent should be speaking or listening now
      _agentStateController.add('listening');
    } catch (e) {
      print('⚠️ LiveKit: Error handling agent audio track: $e');
    }
  }
  
  void _handleAgentData(Uint8List data) {
    // Handle text transcripts or other data from agent
    try {
      // Try to decode as UTF-8 string
      final text = String.fromCharCodes(data);
      if (text.isNotEmpty) {
        _transcriptController.add(text);
      }
    } catch (e) {
      print('⚠️ LiveKit: Error decoding agent data: $e');
    }
  }
  
  /// Disconnect from room
  Future<void> disconnect() async {
    try {
      if (_room != null) {
        if (_room!.localParticipant != null) {
          await _room!.localParticipant!.setMicrophoneEnabled(false);
        }
        await _room!.disconnect();
      }
      _listener?.dispose();
      _room = null;
      _listener = null;
      _isConnected = false;
      _connectionStateController.add(lk.ConnectionState.disconnected);
    } catch (e) {
      print('❌ LiveKit: Disconnect error: $e');
    }
  }
  
  /// Toggle microphone mute
  Future<void> toggleMute() async {
    if (_room == null) return;
    final localParticipant = _room!.localParticipant;
    if (localParticipant != null) {
      final isEnabled = localParticipant.isMicrophoneEnabled();
      await localParticipant.setMicrophoneEnabled(!isEnabled);
    }
  }
  
  bool get isMuted {
    if (_room == null) return true;
    final localParticipant = _room!.localParticipant;
    if (localParticipant == null) return true;
    return !localParticipant.isMicrophoneEnabled();
  }
  
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _agentStateController.close();
    _transcriptController.close();
  }
}

