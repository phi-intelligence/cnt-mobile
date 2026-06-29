import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../services/api_service.dart';
import '../../services/livekit_meeting_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../meeting/meeting_room_screen.dart';
import '../../utils/app_logger.dart';

/// Live Stream Start Screen - Setup Screen
/// Shows camera preview and stream title input before going live
class LiveStreamStartScreen extends StatefulWidget {
  const LiveStreamStartScreen({super.key});

  @override
  State<LiveStreamStartScreen> createState() => _LiveStreamStartScreenState();
}

class _LiveStreamStartScreenState extends State<LiveStreamStartScreen> {
  final TextEditingController _titleController = TextEditingController();
  bool _isCreating = false;
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  String? _errorMessage;
  
  // Local video track for preview
  LocalVideoTrack? _localVideoTrack;
  bool _isInitializingCamera = true;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Live Stream - ${DateTime.now().toString().substring(0, 16)}';
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() => _isInitializingCamera = true);
      
      // Create local video track for preview
      _localVideoTrack = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
        ),
      );
      
      if (mounted) {
        setState(() => _isInitializingCamera = false);
      }
    } catch (e) {
      AppLogger.debug('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _cameraEnabled = false;
        });
      }
    }
  }

  void _toggleCamera() async {
    setState(() {
      _cameraEnabled = !_cameraEnabled;
    });
    
    if (_localVideoTrack != null) {
      if (_cameraEnabled) {
        await _localVideoTrack!.unmute();
      } else {
        await _localVideoTrack!.mute();
      }
    }
  }

  void _toggleMic() {
    setState(() {
      _micEnabled = !_micEnabled;
    });
  }

  Future<void> _startLiveStream() async {
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your live stream'),
          backgroundColor: AppColors.errorMain,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isCreating = true;
        _errorMessage = null;
      });

      // Get current user info
      final authProvider = context.read<AuthProvider>();
      final userName = authProvider.user?['name'] as String? ?? 'Host';

      // Create stream with user-provided title
      final apiService = ApiService();
      final streamResp = await apiService.createStream(
        title: _titleController.text.trim(),
      );

      final streamId = (streamResp['id'] ?? '').toString();
      final roomName = streamResp['room_name'] as String;

      if (streamId.isEmpty) {
        throw Exception('Failed to create stream: Invalid response');
      }

      // Generate identity for host
      final identity = 'host-${DateTime.now().millisecondsSinceEpoch}';

      // Get LiveKit token for host
      final meetingSvc = LiveKitMeetingService();
      final joinResp = await meetingSvc.fetchTokenForMeeting(
        streamOrMeetingId: int.parse(streamId),
        userIdentity: identity,
        userName: userName,
        isHost: true,
      );

      if (!mounted) return;

      // Stop local video track before navigating
      await _localVideoTrack?.stop();

      // Navigate directly to meeting room (skip prejoin for live streams since user already set preferences)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MeetingRoomScreen(
            meetingId: streamId,
            wsUrl: joinResp.url,
            jwtToken: joinResp.token,
            roomName: joinResp.roomName,
            userName: userName,
            isHost: true,
            initialCameraEnabled: _cameraEnabled,
            initialMicEnabled: _micEnabled,
            isLiveStream: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start live stream: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _localVideoTrack?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.warmBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Go Live',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.warmBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
                  children: [
            // Camera Preview
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera Preview
                      if (_isInitializingCamera)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.warmBrown),
                              const SizedBox(height: 16),
                    Text(
                                'Initializing camera...',
                                style: AppTypography.body.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      else if (_localVideoTrack != null && _cameraEnabled)
                        VideoTrackRenderer(_localVideoTrack!)
                      else
                        Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                                    size: 48,
                                    color: Colors.white54,
                                  ),
                    ),
                                const SizedBox(height: 16),
                    Text(
                                  _cameraEnabled ? 'Camera Preview' : 'Camera Off',
                                  style: AppTypography.body.copyWith(color: Colors.white54),
                    ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Live indicator badge
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                        ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PREVIEW',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Camera/Mic toggle buttons
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildToggleButton(
                              icon: _micEnabled ? Icons.mic : Icons.mic_off,
                              isEnabled: _micEnabled,
                              onTap: _toggleMic,
                              label: 'Mic',
                            ),
                            const SizedBox(width: 24),
                            _buildToggleButton(
                              icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                              isEnabled: _cameraEnabled,
                              onTap: _toggleCamera,
                              label: 'Camera',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Stream Setup Form
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.live_tv, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Stream Details',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    
                    // Title Input
                    TextField(
                      controller: _titleController,
                      style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Stream Title',
                        hintText: 'Enter a title for your stream',
                        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
                        labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.warmBrown),
                        prefixIcon: Icon(Icons.title, color: AppColors.warmBrown),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Go Live Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCreating ? null : _startLiveStream,
                        icon: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.live_tv, size: 22),
                        label: Text(
                          _isCreating ? 'Starting...' : 'Go Live',
                          style: AppTypography.body.copyWith(
                          color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.red.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.small),
                    
                    // Info text
                    Center(
                      child: Text(
                        'Your followers will be notified when you go live',
                        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
            ),
            
            const SizedBox(height: AppSpacing.medium),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isEnabled ? AppColors.warmBrown : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
