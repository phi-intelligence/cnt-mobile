import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../services/api_service.dart';
import '../../services/livekit_meeting_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/meeting/video_track_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_logger.dart';

/// Live Stream Viewer Screen - Watch live streams using LiveKit
class LiveStreamViewer extends StatefulWidget {
  final String streamId;
  final String? streamTitle;
  final String? hostName;

  const LiveStreamViewer({
    super.key,
    required this.streamId,
    this.streamTitle,
    this.hostName,
  });

  @override
  State<LiveStreamViewer> createState() => _LiveStreamViewerState();
}

class _LiveStreamViewerState extends State<LiveStreamViewer> {
  final LiveKitMeetingService _meetingService = LiveKitMeetingService();
  final ApiService _apiService = ApiService();
  
  bool _isMuted = false;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isFetchingToken = true;
  int _viewerCount = 0;
  lk.RemoteVideoTrack? _remoteVideoTrack;
  String? _broadcasterIdentity;
  String? _errorMessage;
  
  // Stream info (fetched or passed)
  String? _streamTitle;
  String? _hostName;
  String? _roomName;
  String? _token;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _streamTitle = widget.streamTitle;
    _hostName = widget.hostName;
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    try {
      setState(() {
        _isFetchingToken = true;
        _errorMessage = null;
      });

      // Get user info
      final authProvider = context.read<AuthProvider>();
      final userName = authProvider.user?['name'] as String? ?? 'Viewer';
      final identity = 'viewer-${DateTime.now().millisecondsSinceEpoch}';

      // Fetch token for this stream
      final joinResponse = await _meetingService.fetchTokenForMeeting(
        streamOrMeetingId: int.parse(widget.streamId),
        userIdentity: identity,
        userName: userName,
        isHost: false,
      );

      if (!mounted) return;

      setState(() {
        _token = joinResponse.token;
        _serverUrl = joinResponse.url;
        _roomName = joinResponse.roomName;
        _isFetchingToken = false;
      });

      // Now connect to the stream
      await _connectToStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingToken = false;
          _errorMessage = 'Failed to join stream: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _connectToStream() async {
    if (_token == null || _serverUrl == null || _roomName == null) {
      setState(() {
        _errorMessage = 'Missing stream connection details';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Join LiveKit room (viewer only, no camera/mic)
      await _meetingService.joinMeeting(
        roomName: _roomName!,
        jwtToken: _token!,
        displayName: 'Viewer',
        audioMuted: true,  // Viewer muted by default
        videoMuted: true,  // Viewer has no camera
        wsUrl: _serverUrl!,
      );

      // Listen for remote video tracks
      final room = _meetingService.currentRoom;
      if (room != null) {
        _setupTrackListener(room);
        
        // Check for existing tracks
        _updateVideoTrack(room);
        
        // Update viewer count
        _updateViewerCount();
      }

      setState(() {
        _isLoading = false;
        _isConnected = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
          _errorMessage = 'Failed to connect: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  void _setupTrackListener(lk.Room room) {
    room.createListener().on<lk.TrackSubscribedEvent>((event) {
      // TrackSubscribedEvent is for remote tracks (local tracks don't get "subscribed")
      if (event.track.kind == lk.TrackType.VIDEO) {
        _updateVideoTrack(room);
      }
    });

    room.createListener().on<lk.TrackUnsubscribedEvent>((event) {
      if (event.track.kind == lk.TrackType.VIDEO) {
        _updateVideoTrack(room);
      }
    });

    room.createListener().on<lk.ParticipantConnectedEvent>((event) {
      // ParticipantConnectedEvent is only for remote participants
      _updateVideoTrack(room);
      _updateViewerCount();
    });

    room.createListener().on<lk.ParticipantDisconnectedEvent>((event) {
      _updateVideoTrack(room);
      _updateViewerCount();
    });
    
    // Handle room disconnect (e.g., host ended stream)
    room.createListener().on<lk.RoomDisconnectedEvent>((event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The live stream has ended'),
            backgroundColor: AppColors.warmBrown,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  void _updateVideoTrack(lk.Room room) {
    // Find broadcaster's video track (first remote participant with video)
    for (final participant in room.remoteParticipants.values) {
      final videoTracks = participant.trackPublications.values
          .where((pub) => pub.kind == lk.TrackType.VIDEO && pub.track != null && pub.subscribed && !pub.isScreenShare)
          .map((pub) => pub.track as lk.RemoteVideoTrack);
      
      if (videoTracks.isNotEmpty) {
        setState(() {
          _remoteVideoTrack = videoTracks.first;
          _broadcasterIdentity = participant.identity;
        });
        return;
      }
    }

    // No video track found
    setState(() {
      _remoteVideoTrack = null;
      _broadcasterIdentity = null;
    });
  }

  void _updateViewerCount() {
    if (_isConnected) {
      final count = _meetingService.getParticipantCount();
      setState(() {
        _viewerCount = count > 0 ? count : 0;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isConnected) {
          _updateViewerCount();
    }
    });
    }
  }

  Future<void> _leaveStream() async {
    try {
      await _meetingService.leaveMeeting();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.debug('Error leaving stream: $e');
    }
  }

  @override
  void dispose() {
    _meetingService.leaveMeeting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isFetchingToken || _isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.warmBrown),
              const SizedBox(height: 16),
              Text(
                _isFetchingToken ? 'Joining stream...' : 'Connecting...',
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
                const Icon(Icons.error_outline, size: 64, color: AppColors.errorMain),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: AppTypography.body.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeViewer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and viewer count
            Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black.withOpacity(0)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button and live indicator
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _leaveStream,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                    child: Row(
                          mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                              width: 6,
                              height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                                color: Colors.white,
                          ),
                        ),
                            const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                  // Viewer count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                    children: [
                        const Icon(Icons.remove_red_eye, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$_viewerCount',
                          style: AppTypography.bodySmall.copyWith(color: Colors.white),
                      ),
                      ],
                      ),
                  ),
                ],
              ),
            ),

            // Video player area
            Expanded(
              child: _remoteVideoTrack != null
                  ? VideoTrackView(track: _remoteVideoTrack!, isLocal: false)
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off, size: 80, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              'Waiting for host to start video...',
                              style: AppTypography.body.copyWith(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Stream info footer
            Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.black.withOpacity(0)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _streamTitle ?? 'Live Stream',
                    style: AppTypography.heading4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_hostName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hosted by $_hostName',
                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
