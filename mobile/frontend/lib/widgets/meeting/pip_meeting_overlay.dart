import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'video_track_view.dart';

/// PiP (Picture-in-Picture) Overlay for ongoing meetings
/// Shows a compact floating view when user navigates away from the meeting
class PipMeetingOverlay extends StatefulWidget {
  /// Local video track to display
  final lk.LocalVideoTrack? localVideoTrack;
  
  /// Remote video track to display (for participants' feed)
  final lk.RemoteVideoTrack? remoteVideoTrack;
  
  /// Callback to return to full meeting screen
  final VoidCallback onExpand;
  
  /// Callback to end/leave the meeting
  final VoidCallback onEnd;
  
  /// Whether user is host (affects end meeting options)
  final bool isHost;
  
  /// Meeting title
  final String? meetingTitle;
  
  /// Duration of the meeting (displayed as timer)
  final Duration? duration;
  
  /// Whether to show local video (default) or remote video
  final bool showLocalVideo;
  
  /// Whether camera is enabled
  final bool isCameraEnabled;
  
  /// Whether microphone is enabled
  final bool isMicEnabled;
  
  /// Callback to toggle camera
  final VoidCallback? onToggleCamera;
  
  /// Callback to toggle microphone
  final VoidCallback? onToggleMic;

  const PipMeetingOverlay({
    super.key,
    this.localVideoTrack,
    this.remoteVideoTrack,
    required this.onExpand,
    required this.onEnd,
    this.isHost = false,
    this.meetingTitle,
    this.duration,
    this.showLocalVideo = true,
    this.isCameraEnabled = true,
    this.isMicEnabled = true,
    this.onToggleCamera,
    this.onToggleMic,
  });

  @override
  State<PipMeetingOverlay> createState() => _PipMeetingOverlayState();
}

class _PipMeetingOverlayState extends State<PipMeetingOverlay> 
    with SingleTickerProviderStateMixin {
  // Position of the overlay (can be dragged)
  double _positionX = 16;
  double _positionY = 100;
  
  // Size of the overlay
  static const double _overlayWidth = 140;
  static const double _overlayHeight = 200;
  
  // Animation controller for entry animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  // Controls visibility
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
    
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Positioned(
      left: _positionX,
      top: _positionY,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _positionX = (_positionX + details.delta.dx)
                  .clamp(0, screenSize.width - _overlayWidth);
              _positionY = (_positionY + details.delta.dy)
                  .clamp(0, screenSize.height - _overlayHeight - 80);
            });
          },
          onTap: _showControlsTemporarily,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _overlayWidth,
              height: _overlayHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: AppColors.warmBrown.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video feed
                    _buildVideoContent(),
                    
                    // Gradient overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                              stops: const [0.0, 0.2, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Live/Recording indicator
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Duration indicator
                    if (widget.duration != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(widget.duration!),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    
                    // Controls overlay (expand & end buttons)
                    if (_showControls)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Mic toggle
                              if (widget.onToggleMic != null)
                                _buildMiniControl(
                                  icon: widget.isMicEnabled 
                                      ? Icons.mic 
                                      : Icons.mic_off,
                                  onTap: widget.onToggleMic!,
                                  isActive: widget.isMicEnabled,
                                ),
                              
                              // Camera toggle
                              if (widget.onToggleCamera != null)
                                _buildMiniControl(
                                  icon: widget.isCameraEnabled 
                                      ? Icons.videocam 
                                      : Icons.videocam_off,
                                  onTap: widget.onToggleCamera!,
                                  isActive: widget.isCameraEnabled,
                                ),
                              
                              // Expand button
                              _buildMiniControl(
                                icon: Icons.fullscreen,
                                onTap: widget.onExpand,
                                isActive: true,
                                bgColor: AppColors.warmBrown,
                              ),
                              
                              // End/Leave button
                              _buildMiniControl(
                                icon: Icons.call_end,
                                onTap: widget.onEnd,
                                isActive: true,
                                bgColor: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildVideoContent() {
    // Determine which video track to show
    final videoTrack = widget.showLocalVideo 
        ? widget.localVideoTrack 
        : widget.remoteVideoTrack;
    
    if (videoTrack == null || !widget.isCameraEnabled) {
      // Show placeholder when no video
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.white.withOpacity(0.5),
            size: 32,
          ),
        ),
      );
    }
    
    // Show video with mirroring for local video
    return widget.showLocalVideo
        ? VideoTrackView(track: videoTrack, isLocal: true, mirror: true)
        : VideoTrackView(track: videoTrack as lk.RemoteVideoTrack?, isLocal: false);
  }
  
  Widget _buildMiniControl({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor ?? (isActive ? Colors.white.withOpacity(0.2) : Colors.red.withOpacity(0.8)),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

/// Provider/Manager for PiP overlay state
class PipMeetingManager extends ChangeNotifier {
  bool _isInPipMode = false;
  lk.LocalVideoTrack? _localVideoTrack;
  lk.RemoteVideoTrack? _remoteVideoTrack;
  String? _meetingId;
  String? _meetingTitle;
  bool _isHost = false;
  bool _isCameraEnabled = true;
  bool _isMicEnabled = true;
  VoidCallback? _onExpand;
  VoidCallback? _onEnd;
  VoidCallback? _onToggleCamera;
  VoidCallback? _onToggleMic;
  DateTime? _startTime;
  
  bool get isInPipMode => _isInPipMode;
  lk.LocalVideoTrack? get localVideoTrack => _localVideoTrack;
  lk.RemoteVideoTrack? get remoteVideoTrack => _remoteVideoTrack;
  String? get meetingId => _meetingId;
  String? get meetingTitle => _meetingTitle;
  bool get isHost => _isHost;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isMicEnabled => _isMicEnabled;
  VoidCallback? get onExpand => _onExpand;
  VoidCallback? get onEnd => _onEnd;
  VoidCallback? get onToggleCamera => _onToggleCamera;
  VoidCallback? get onToggleMic => _onToggleMic;
  Duration? get duration => _startTime != null 
      ? DateTime.now().difference(_startTime!) 
      : null;
  
  /// Enter PiP mode
  void enterPipMode({
    required lk.LocalVideoTrack? localVideoTrack,
    lk.RemoteVideoTrack? remoteVideoTrack,
    required String meetingId,
    String? meetingTitle,
    required bool isHost,
    required bool isCameraEnabled,
    required bool isMicEnabled,
    required VoidCallback onExpand,
    required VoidCallback onEnd,
    VoidCallback? onToggleCamera,
    VoidCallback? onToggleMic,
    DateTime? startTime,
  }) {
    _localVideoTrack = localVideoTrack;
    _remoteVideoTrack = remoteVideoTrack;
    _meetingId = meetingId;
    _meetingTitle = meetingTitle;
    _isHost = isHost;
    _isCameraEnabled = isCameraEnabled;
    _isMicEnabled = isMicEnabled;
    _onExpand = onExpand;
    _onEnd = onEnd;
    _onToggleCamera = onToggleCamera;
    _onToggleMic = onToggleMic;
    _startTime = startTime;
    _isInPipMode = true;
    notifyListeners();
  }
  
  /// Exit PiP mode
  void exitPipMode() {
    _isInPipMode = false;
    _localVideoTrack = null;
    _remoteVideoTrack = null;
    _meetingId = null;
    _meetingTitle = null;
    _onExpand = null;
    _onEnd = null;
    _onToggleCamera = null;
    _onToggleMic = null;
    _startTime = null;
    notifyListeners();
  }
  
  /// Update camera state
  void updateCameraState(bool enabled) {
    _isCameraEnabled = enabled;
    notifyListeners();
  }
  
  /// Update mic state
  void updateMicState(bool enabled) {
    _isMicEnabled = enabled;
    notifyListeners();
  }
  
  /// Update video tracks
  void updateTracks({
    lk.LocalVideoTrack? localVideoTrack,
    lk.RemoteVideoTrack? remoteVideoTrack,
  }) {
    _localVideoTrack = localVideoTrack;
    _remoteVideoTrack = remoteVideoTrack;
    notifyListeners();
  }
}

