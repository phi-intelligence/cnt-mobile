import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../theme/app_spacing.dart';
import 'video_preview_screen.dart';
import '../../utils/app_logger.dart';

/// Video Recording Screen - Record video podcasts
class VideoRecordingScreen extends StatefulWidget {
  const VideoRecordingScreen({super.key});

  @override
  State<VideoRecordingScreen> createState() => _VideoRecordingScreenState();
}

class _VideoRecordingScreenState extends State<VideoRecordingScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  int _recordingDuration = 0;
  bool _isFlashOn = false;
  CameraDescription? _camera;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<bool> _onWillPop() async {
    // If recording is in progress, show warning
    if (_isRecording) {
      if (!mounted) return true;
      
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop Recording?'),
          content: const Text(
            'Recording is in progress. If you go back, your video recording will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      
      if (shouldDiscard == true) {
        // Stop recording if in progress
        await _controller?.stopVideoRecording();
        setState(() {
          _isRecording = false;
        });
      }
      
      return shouldDiscard ?? false;
    }
    return true;
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _camera = cameras.first;
      _isFrontCamera = _camera!.lensDirection == CameraLensDirection.front;
      _controller = CameraController(
        _camera!,
        ResolutionPreset.high,
      );
      await _controller!.initialize();
      setState(() {});
    }
  }

  Future<void> _startRecording() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      _updateDuration();
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not initialized')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isRecording = false;
      });

      final video = await _controller!.stopVideoRecording();
      
      // Verify the video file exists
      final file = File(video.path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video file not found')),
          );
        }
        return;
      }

      // Get actual file size
      final fileSize = await file.length();
      
      // Navigate to video preview screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPreviewScreen(
              videoUri: video.path,
              source: 'camera',
              duration: _recordingDuration,
              fileSize: fileSize,
              isFrontCamera: _isFrontCamera,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('Error stopping video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
        // Reset recording state
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    // TODO: Toggle flash
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    final currentIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == _camera!.lensDirection,
    );
    final newCamera = cameras[(currentIndex + 1) % cameras.length];

    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
    );
    await _controller!.initialize();
    _camera = newCamera;
    _isFrontCamera = newCamera.lensDirection == CameraLensDirection.front;
    setState(() {});
  }

  void _updateDuration() {
    if (_isRecording) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isRecording) {
          setState(() {
            _recordingDuration++;
          });
          _updateDuration();
        }
      });
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return WillPopScope(
        onWillPop: _onWillPop,
        child: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_controller!),
          ),

          // Top controls
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.medium),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                        color: Colors.white,
                        onPressed: _toggleFlash,
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios),
                        color: Colors.white,
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.large),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isRecording)
                    GestureDetector(
                      onTap: _startRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 6),
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _stopRecording,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 6),
                        ),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

