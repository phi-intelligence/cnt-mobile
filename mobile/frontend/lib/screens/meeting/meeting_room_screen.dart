import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/livekit_meeting_service.dart';
import '../../services/websocket_service.dart';
import '../../services/api_service.dart';
import '../../widgets/meeting/video_track_view.dart';
import '../../widgets/meeting/meeting_controls.dart';
import '../../widgets/meeting/pip_meeting_overlay.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Meeting Room Screen - LiveKit meeting UI
/// Custom UI built on top of LiveKit SDK
class MeetingRoomScreen extends StatefulWidget {
  final String meetingId;
  final String roomName;
  final String jwtToken;
  final String userName;
  final bool isHost;
  final String? wsUrl;
  final bool initialCameraEnabled;
  final bool initialMicEnabled;
  final String? avatarUrl;
  final bool isLiveStream;

  const MeetingRoomScreen({
    super.key,
    required this.meetingId,
    required this.roomName,
    required this.jwtToken,
    required this.userName,
    this.isHost = false,
    this.wsUrl,
    this.initialCameraEnabled = true,
    this.initialMicEnabled = true,
    this.avatarUrl,
    this.isLiveStream = false,
  });

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final LiveKitMeetingService _meetingService = LiveKitMeetingService();
  bool _joining = true;
  bool _error = false;
  String? _errorMessage;
  final List<lk.RemoteParticipant> _currentParticipants = [];
  final Set<String> _admittedParticipantSids = {};
  final Set<String> _waitingParticipantSids = {};
  StreamSubscription<List<lk.RemoteParticipant>>? _participantSubscription;
  
  // Permission request handling for live streams
  final Map<String, Map<String, dynamic>> _permissionRequests = {};
  StreamSubscription<Map<String, dynamic>>? _permissionRequestSubscription;

  // Flag to prevent duplicate host joined notifications
  bool _hostJoinedNotificationSent = false;

  @override
  void initState() {
    super.initState();
    _joinMeeting();
    if (widget.isLiveStream) {
      _setupPermissionRequestListener();
    }
  }
  
  void _setupPermissionRequestListener() {
    final wsService = WebSocketService();
    _permissionRequestSubscription = wsService.speakPermissionRequested.listen((data) {
      if (mounted && widget.isHost) {
        setState(() {
          final requestId = data['request_id'] as String? ?? 
              '${data['participant_id']}_${DateTime.now().millisecondsSinceEpoch}';
          _permissionRequests[requestId] = data;
        });
      }
    });
  }
  
  Future<void> _requestSpeakPermission() async {
    if (!widget.isLiveStream || widget.isHost) return;
    
    try {
      final wsService = WebSocketService();
      final requestId = '${widget.userName}_${DateTime.now().millisecondsSinceEpoch}';
      wsService.send({
        'event': 'request_speak_permission',
        'stream_id': int.tryParse(widget.meetingId) ?? 0,
        'participant_id': widget.userName,
        'participant_name': widget.userName,
        'request_id': requestId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission request sent to host'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request permission: $e')),
        );
      }
    }
  }
  
  Future<void> _grantPermission(String requestId, String participantId) async {
    try {
      final room = _meetingService.currentRoom;
      if (room == null) return;
      
      // Find participant and enable their mic
      final participants = room.remoteParticipants.values;
      for (final participant in participants) {
        if (participant.identity == participantId) {
          // Enable mic for this participant via LiveKit
          // Note: This requires LiveKit server-side permissions or track control
          // For now, we'll emit an event that the participant can listen to
          final wsService = WebSocketService();
          wsService.send({
            'event': 'permission_granted',
            'stream_id': int.tryParse(widget.meetingId) ?? 0,
            'participant_id': participantId,
            'request_id': requestId,
          });
          
          setState(() {
            _permissionRequests.remove(requestId);
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Permission granted to $participantId')),
            );
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to grant permission: $e')),
        );
      }
    }
  }
  
  void _denyPermission(String requestId) {
    setState(() {
      _permissionRequests.remove(requestId);
    });
  }

  Future<void> _joinMeeting() async {
    try {
      await _meetingService.joinMeeting(
        roomName: widget.roomName,
        jwtToken: widget.jwtToken,
        displayName: widget.userName,
        audioMuted: !widget.initialMicEnabled,
        videoMuted: !widget.initialCameraEnabled,
        isModerator: widget.isHost,
        wsUrl: widget.wsUrl,
      );
      
      if (mounted) {
        setState(() {
          _joining = false;
        });
        _participantSubscription ??=
            _meetingService.participants.listen(_handleParticipantsUpdate);
        _handleParticipantsUpdate(_meetingService.getParticipants());
        
        // If host, wait for room to be fully connected before notifying
        if (widget.isHost) {
          // Wait for room connection to be established
          await _waitForRoomConnection();
          // Only notify after confirming room is connected
          _notifyHostJoined();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = true;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join meeting: $e')),
        );
      }
    }
  }
  
  /// Wait for the LiveKit room to be fully connected before sending notifications.
  /// This ensures the host is actually in the room before notifying other users.
  Future<void> _waitForRoomConnection() async {
    final room = _meetingService.currentRoom;
    if (room == null) {
      // Wait a bit and retry
      await Future.delayed(const Duration(milliseconds: 500));
      return _waitForRoomConnection();
    }
    
    // Wait for room state to be ready
    int retries = 0;
    const maxRetries = 20; // 4 seconds total (20 * 200ms)
    
    while (retries < maxRetries) {
      // Check if room is connected
      if (room.connectionState == lk.ConnectionState.connected) {
        // Additional check: ensure local participant is in the room
        if (room.localParticipant != null) {
          print('✅ Room connection verified - host is connected');
          return;
        }
      }
      
      // Wait before retrying
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    
    // If we reach here, connection verification timed out
    // Log warning but proceed anyway (room might still be connecting)
    print('⚠️ Room connection verification timed out, proceeding with notification');
  }
  
  /// Notify backend that host has joined the room.
  /// This triggers notifications to other users that the stream/meeting is live.
  /// Debounced to prevent duplicate calls.
  Future<void> _notifyHostJoined() async {
    // Prevent duplicate notifications
    if (_hostJoinedNotificationSent) {
      print('ℹ️ Host joined notification already sent, skipping');
      return;
    }
    
    try {
      final api = ApiService();
      final meetingIdInt = int.tryParse(widget.meetingId);
      if (meetingIdInt != null) {
        _hostJoinedNotificationSent = true; // Set flag before API call
        await api.notifyHostJoined(meetingIdInt);
        print('✅ Host joined notification sent for meeting: ${widget.meetingId}');
      }
    } catch (e) {
      // Don't fail the meeting if notification fails
      // Reset flag to allow retry on next opportunity
      _hostJoinedNotificationSent = false;
      print('⚠️ Failed to send host joined notification: $e');
    }
  }

  void _handleParticipantsUpdate(List<lk.RemoteParticipant> participants) {
    if (!mounted) return;
    setState(() {
      _currentParticipants
        ..clear()
        ..addAll(participants);
      if (!widget.isHost) {
        _admittedParticipantSids
          ..clear()
          ..addAll(participants.map((p) => p.sid));
        _waitingParticipantSids.clear();
        return;
      }

      final activeSids = participants.map((p) => p.sid).toSet();
      _admittedParticipantSids.removeWhere((sid) => !activeSids.contains(sid));
      _waitingParticipantSids.removeWhere((sid) => !activeSids.contains(sid));

      for (final sid in activeSids) {
        if (!_admittedParticipantSids.contains(sid) &&
            !_waitingParticipantSids.contains(sid)) {
          _waitingParticipantSids.add(sid);
        }
      }
    });
  }

  void _admitParticipant(String sid) {
    if (!widget.isHost) return;
    setState(() {
      if (_waitingParticipantSids.remove(sid)) {
        _admittedParticipantSids.add(sid);
      }
    });
  }

  void _admitAllWaiting() {
    if (!widget.isHost) return;
    setState(() {
      _admittedParticipantSids.addAll(_waitingParticipantSids);
      _waitingParticipantSids.clear();
    });
  }

  List<lk.RemoteParticipant> _waitingList() {
    return _currentParticipants
        .where((p) => _waitingParticipantSids.contains(p.sid))
        .toList();
  }

  List<lk.RemoteParticipant> _visibleParticipants(List<lk.RemoteParticipant> participants) {
    if (!widget.isHost) return participants;
    return participants
        .where((p) => _admittedParticipantSids.contains(p.sid))
        .toList();
  }

  void _showParticipantsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _meetingBackgroundAccent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final admitted = _currentParticipants
            .where((p) => _admittedParticipantSids.contains(p.sid))
            .toList();
        final waiting = _waitingList();
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people, color: AppColors.warmBrown),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Participants (${admitted.length + waiting.length})',
                    style: AppTypography.heading4.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (waiting.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Waiting (${waiting.length})',
                      style: AppTypography.body.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _admitAllWaiting,
                      child: const Text('Admit all'),
                    ),
                  ],
                ),
                ...waiting.map(
                  (p) => ListTile(
                    leading: const Icon(Icons.person_outline, color: Colors.white70),
                    title: Text(p.identity, style: TextStyle(color: Colors.white)),
                    trailing: TextButton(
                      onPressed: () => _admitParticipant(p.sid),
                      child: const Text('Admit'),
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
              ],
              Text(
                'In call (${admitted.length})',
                style: AppTypography.body.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...admitted.map(
                (p) => ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.white54),
                  title: Text(p.identity, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitingRoomBanner(List<lk.RemoteParticipant> waiting) {
    if (waiting.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warmBrown.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warmBrown.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.doorbell_outlined, color: AppColors.warmBrown),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${waiting.length} participant${waiting.length == 1 ? '' : 's'} waiting to join',
                    style: AppTypography.body.copyWith(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _admitAllWaiting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Admit all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: waiting.take(3).map((participant) {
                return Chip(
                  label: Text(participant.identity),
                  backgroundColor: _meetingBackgroundAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                  side: BorderSide(color: AppColors.warmBrown.withOpacity(0.5)),
                  deleteIcon: const Icon(Icons.check, color: Colors.greenAccent),
                  onDeleted: () => _admitParticipant(participant.sid),
                );
              }).toList(),
            ),
            if (waiting.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${waiting.length - 3} more',
                  style: AppTypography.caption.copyWith(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequestsBanner() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_external_on, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_permissionRequests.length} permission request${_permissionRequests.length == 1 ? '' : 's'}',
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_permissionRequests.length > 1)
                  TextButton(
                    onPressed: () {
                      // Approve all
                      for (final entry in _permissionRequests.entries) {
                        _grantPermission(entry.key, entry.value['participant_id'] as String);
                      }
                    },
                    child: const Text(
                      'Approve All',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._permissionRequests.entries.map((entry) {
              final request = entry.value;
              final participantName = request['participant_name'] as String? ?? 'Participant';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$participantName wants to speak',
                        style: AppTypography.bodySmall.copyWith(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _grantPermission(entry.key, request['participant_id'] as String),
                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _denyPermission(entry.key),
                      child: const Text('Deny', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handlePresentTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Screen sharing coming soon.'),
      ),
    );
  }

  /// Show exit dialog for hosts to choose between ending for all or just leaving
  Future<void> _showHostExitDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.warmBrown),
            const SizedBox(width: 12),
            Text(
              'Leave Meeting',
              style: AppTypography.heading4.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Would you like to end the meeting for everyone or just leave?',
          style: AppTypography.body.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: Text(
              'Leave Meeting',
              style: TextStyle(color: AppColors.warmBrown),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'end_all'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('End for All'),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;
    
    if (result == 'end_all') {
      // End meeting for all participants
      await _endMeetingForAll();
    } else if (result == 'leave') {
      // Enter PiP mode and leave
      await _enterPipAndLeave();
    }
  }
  
  /// Enter Picture-in-Picture mode and navigate away
  Future<void> _enterPipAndLeave() async {
    final room = _meetingService.currentRoom;
    if (room == null) {
      await _leaveMeetingCompletely();
      return;
    }
    
    // Get local video track
    final localParticipant = room.localParticipant;
    lk.LocalVideoTrack? localVideoTrack;
    
    if (localParticipant != null) {
      for (final pub in localParticipant.trackPublications.values) {
        if (pub.track is lk.LocalVideoTrack && !pub.isScreenShare) {
          localVideoTrack = pub.track as lk.LocalVideoTrack;
          break;
        }
      }
    }
    
    // Get remote video track (first available)
    lk.RemoteVideoTrack? remoteVideoTrack;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.trackPublications.values) {
        if (pub.track is lk.RemoteVideoTrack && !pub.isScreenShare) {
          remoteVideoTrack = pub.track as lk.RemoteVideoTrack;
          break;
        }
      }
      if (remoteVideoTrack != null) break;
    }
    
    // Enter PiP mode
    final pipManager = context.read<PipMeetingManager>();
    pipManager.enterPipMode(
      localVideoTrack: localVideoTrack,
      remoteVideoTrack: remoteVideoTrack,
      meetingId: widget.meetingId,
      meetingTitle: widget.roomName,
      isHost: widget.isHost,
      isCameraEnabled: _meetingService.isCameraEnabled(),
      isMicEnabled: _meetingService.isMicrophoneEnabled(),
      onExpand: () {
        // Return to meeting room - need to navigate back here
        pipManager.exitPipMode();
        // Navigate back to the meeting room screen would require storing state
        // For simplicity, we'll just expand to full and the user will see the video
      },
      onEnd: () async {
        pipManager.exitPipMode();
        await _leaveMeetingCompletely();
      },
      onToggleCamera: () async {
        await _meetingService.toggleCamera();
        pipManager.updateCameraState(_meetingService.isCameraEnabled());
      },
      onToggleMic: () async {
        await _meetingService.toggleMicrophone();
        pipManager.updateMicState(_meetingService.isMicrophoneEnabled());
      },
      startTime: DateTime.now(), // Would be better to track actual start time
    );
    
    // Navigate back to main screen
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/');
    }
  }
  
  /// End meeting for all participants
  Future<void> _endMeetingForAll() async {
    // Call backend to end the meeting, which will:
    // 1. Update database status to "ended"
    // 2. Delete the LiveKit room (disconnecting all participants)
    // 3. Send Socket.io notification to inform all clients
    try {
      final meetingIdInt = int.tryParse(widget.meetingId);
      if (meetingIdInt != null) {
        await ApiService().endMeeting(meetingIdInt);
        print('✅ Meeting ended for all participants: ${widget.meetingId}');
      }
    } catch (e) {
      print('⚠️ Failed to end meeting on server: $e');
      // Continue with local cleanup even if server call fails
    }
    await _leaveMeetingCompletely();
  }
  
  /// Completely leave the meeting (disconnect and close)
  Future<void> _leaveMeetingCompletely() async {
    // Exit PiP mode if active
    try {
      final pipManager = context.read<PipMeetingManager>();
      if (pipManager.isInPipMode) {
        pipManager.exitPipMode();
      }
    } catch (e) {
      // PipMeetingManager might not be available in some contexts
    }
    
    await _participantSubscription?.cancel();
    _participantSubscription = null;
    await _meetingService.leaveMeeting();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/');
    }
  }
  
  /// Legacy method for backward compatibility - now shows dialog for hosts
  Future<void> _leaveMeeting() async {
    if (widget.isHost) {
      await _showHostExitDialog();
    } else {
      // Non-hosts can enter PiP mode directly or leave completely
      await _enterPipAndLeave();
    }
  }

  @override
  void dispose() {
    _participantSubscription?.cancel();
    _permissionRequestSubscription?.cancel();
    _meetingService.leaveMeeting();
    super.dispose();
  }

  // Meeting-specific dark brown theme colors
  static const Color _meetingBackgroundDark = Color(0xFF2A1F1A); // Dark warm brown
  static const Color _meetingBackgroundAccent = Color(0xFF3D2E25); // Slightly lighter
  static const Color _meetingBorderAccent = Color(0xFF5D4837); // Border/accent brown

  @override
  Widget build(BuildContext context) {
    if (_joining) {
      return Scaffold(
        backgroundColor: _meetingBackgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.warmBrown),
              const SizedBox(height: 16),
              Text(
                'Joining meeting...',
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_error) {
      return Scaffold(
        backgroundColor: _meetingBackgroundDark,
        appBar: AppBar(
          backgroundColor: _meetingBackgroundDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Failed to join meeting',
                  style: AppTypography.heading4.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: AppTypography.body.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final room = _meetingService.currentRoom;
    if (room == null) {
      return Scaffold(
        backgroundColor: _meetingBackgroundDark,
        body: const Center(
          child: Text('No room connection', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _meetingBackgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Meeting header with warm brown theme
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warmBrown,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Meeting icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.roomName,
                          style: AppTypography.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        StreamBuilder<int>(
                          stream: Stream.value(_meetingService.getParticipantCount()),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 1;
                            return Text(
                              '$count participant${count != 1 ? 's' : ''}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withOpacity(0.85),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
                      // Show meeting info
                    },
                  ),
                ],
              ),
            ),

            if (widget.isHost && _waitingParticipantSids.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildWaitingRoomBanner(_waitingList()),
            ],

            // Video grid
            Expanded(
              child: StreamBuilder<List<lk.RemoteParticipant>>(
                stream: _meetingService.participants,
                builder: (context, snapshot) {
                  // Prevent rebuilds during disposal
                  if (!mounted) {
                    return const SizedBox.shrink();
                  }
                  
                  final participants = snapshot.data ?? [];
                  final visibleParticipants = _visibleParticipants(participants);
                  final localParticipant = room.localParticipant;

                  if (visibleParticipants.isEmpty && localParticipant == null) {
                    return Center(
                      child: Text(
                        widget.isHost && _waitingParticipantSids.isNotEmpty
                            ? 'Admit participants to let them appear in the call'
                            : 'No participants',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // Create grid of all participants (local + remote)
                  final allParticipants = <Widget>[];
                  
                  // Add local participant video
                  if (localParticipant != null) {
                    final localVideoTrackPub = localParticipant.trackPublications.values
                        .where((pub) => pub.kind == lk.TrackType.VIDEO && pub.track != null && !pub.muted)
                        .map((pub) => pub.track as lk.LocalVideoTrack)
                        .firstOrNull;
                    final localVideoTrack = localVideoTrackPub;
                    
                    allParticipants.add(
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          clipBehavior: Clip.antiAlias,
                          child: localVideoTrack != null
                              ? VideoTrackView(track: localVideoTrack, isLocal: true, mirror: true)
                              : PlaceholderVideoView(name: widget.userName, avatarUrl: widget.avatarUrl),
                        ),
                      ),
                    );
                  }

                  // Add remote participants videos
                  for (final participant in visibleParticipants) {
                    final videoTracks = participant.trackPublications.values
                        .where((pub) => pub.kind == lk.TrackType.VIDEO && pub.track != null && pub.subscribed && !pub.isScreenShare && !pub.muted)
                        .map((pub) => pub.track as lk.RemoteVideoTrack);
                    
                    final videoTrack = videoTracks.isNotEmpty ? videoTracks.first : null;
                    
                    allParticipants.add(
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: videoTrack != null
                              ? VideoTrackView(track: videoTrack, isLocal: false)
                              : PlaceholderVideoView(name: participant.identity),
                        ),
                      ),
                    );
                  }

                  // Display grid
                  if (allParticipants.length == 1) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: allParticipants.first,
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: allParticipants.length <= 2 ? 1 : 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 16 / 9,
                        ),
                        itemCount: allParticipants.length,
                        itemBuilder: (context, index) => allParticipants[index],
                      ),
                    );
                  }
                },
              ),
            ),

            // Meeting controls
            MeetingControls(
              room: room,
              onLeave: _leaveMeeting,
              isHost: widget.isHost,
              onShowParticipants: widget.isHost ? _showParticipantsSheet : null,
              onPresent: _handlePresentTap,
              isLiveStream: widget.isLiveStream,
              onRequestSpeak: widget.isLiveStream && !widget.isHost ? _requestSpeakPermission : null,
            ),
            
            // Permission requests banner (host only, live streams only)
            if (widget.isLiveStream && widget.isHost && _permissionRequests.isNotEmpty)
              _buildPermissionRequestsBanner(),
          ],
        ),
      ),
    );
  }
}
