import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../services/livekit_meeting_service.dart';
import 'meeting_room_screen.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/media_utils.dart';
import '../../utils/app_logger.dart';

/// Prejoin Screen - Device check before joining meeting
/// Allows user to toggle camera/mic before joining
class PrejoinScreen extends StatefulWidget {
  final String meetingId;
  final String jitsiUrl; // Keep name for compatibility, but will contain LiveKit URL
  final String jwtToken;
  final String roomName;
  final String userName;
  final bool isHost;
  final bool initialCameraEnabled;
  final bool initialMicEnabled;
  final bool isLiveStream;

  const PrejoinScreen({
    super.key,
    required this.meetingId,
    required this.jitsiUrl,
    required this.jwtToken,
    required this.roomName,
    required this.userName,
    this.isHost = false,
    this.initialCameraEnabled = true,
    this.initialMicEnabled = true,
    this.isLiveStream = false,
  });

  @override
  State<PrejoinScreen> createState() => _PrejoinScreenState();
}

class _PrejoinScreenState extends State<PrejoinScreen> {
  late bool cameraEnabled;
  late bool micEnabled;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;

  @override
  void initState() {
    super.initState();
    cameraEnabled = widget.initialCameraEnabled;
    micEnabled = widget.initialMicEnabled;
    if (cameraEnabled) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;
    
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
        });
        return;
      }
      
      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraInitializing = false;
        });
      }
    } catch (e) {
      AppLogger.debug('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onJoin() {
    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();
    final profileUser = userProvider.user ?? authProvider.user;
    final avatarUrl = resolveMediaUrl(profileUser?['avatar'] as String?);

    // Navigate to LiveKit meeting room screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MeetingRoomScreen(
            meetingId: widget.meetingId,
            roomName: widget.roomName,
            jwtToken: widget.jwtToken,
            userName: widget.userName,
            isHost: widget.isHost,
            wsUrl: widget.jitsiUrl, // Use jitsiUrl as wsUrl (it will be LiveKit URL from backend)
            initialCameraEnabled: cameraEnabled,
            initialMicEnabled: micEnabled,
            avatarUrl: avatarUrl,
            isLiveStream: widget.isLiveStream,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Check Your Setup',
          style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                children: [
            const SizedBox(height: AppSpacing.extraLarge),
            // Camera preview with mirroring
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              clipBehavior: Clip.antiAlias,
              child: cameraEnabled && _isCameraInitialized && _cameraController != null
                  ? CameraPreview(_cameraController!)
                  : cameraEnabled && _isCameraInitializing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryMain,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.videocam_off,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                        ),
            ),
            const SizedBox(height: AppSpacing.extraLarge),
            Text(
              'Room: ${widget.roomName}',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
            const SizedBox(height: AppSpacing.medium),
            // Camera toggle
            ListTile(
              leading: Icon(
                cameraEnabled ? Icons.videocam : Icons.videocam_off,
                color: cameraEnabled ? AppColors.primaryMain : AppColors.textSecondary,
              ),
              title: Text(
                cameraEnabled ? 'Camera On' : 'Camera Off',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
              trailing: Switch(
                value: cameraEnabled,
                onChanged: (value) async {
                  setState(() {
                    cameraEnabled = value;
                  });
                  if (value) {
                    await _initializeCamera();
                  } else {
                    await _disposeCamera();
                  }
                },
              ),
            ),
            // Microphone toggle
            ListTile(
              leading: Icon(
                micEnabled ? Icons.mic : Icons.mic_off,
                color: micEnabled ? AppColors.primaryMain : AppColors.textSecondary,
              ),
              title: Text(
                micEnabled ? 'Microphone On' : 'Microphone Off',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
              trailing: Switch(
                value: micEnabled,
                onChanged: (value) {
                  setState(() {
                    micEnabled = value;
                  });
                        },
                      ),
                  ),
            const Spacer(),
            // Join button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                icon: const Icon(Icons.meeting_room, color: Colors.white),
                label: const Text(
                  'Join Meeting',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
                      onPressed: _onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  ),
                ),
                    ),
            ),
            const SizedBox(height: AppSpacing.medium),
                ],
              ),
            ),
    );
  }
}
