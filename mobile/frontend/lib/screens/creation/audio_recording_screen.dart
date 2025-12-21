import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'audio_preview_screen.dart';

/// Audio Recording Screen - Record audio podcasts
/// Redesigned with app theme (warm brown accents, cream background)
class AudioRecordingScreen extends StatefulWidget {
  const AudioRecordingScreen({super.key});

  @override
  State<AudioRecordingScreen> createState() => _AudioRecordingScreenState();
}

class _AudioRecordingScreenState extends State<AudioRecordingScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordingDuration = 0;
  String? _recordingPath;

  // Animation for waveform
  late AnimationController _waveController;
  final List<double> _waveHeights = [];
  final int _waveCount = 30;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateWaveform);

    // Initialize wave heights
    for (int i = 0; i < _waveCount; i++) {
      _waveHeights.add(0.2);
    }
  }

  void _updateWaveform() {
    if (_isRecording && !_isPaused) {
      setState(() {
        // Shift waves to the left and add new wave on right
        for (int i = 0; i < _waveCount - 1; i++) {
          _waveHeights[i] = _waveHeights[i + 1];
        }
        // Generate new random wave height
        _waveHeights[_waveCount - 1] = 0.2 + Random().nextDouble() * 0.6;
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // If recording is in progress, show warning
    if (_isRecording || _recordingPath != null) {
      if (!mounted) return true;
      
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Recording?'),
          content: Text(
            _isRecording
                ? 'Recording is in progress. If you go back, your recording will be lost.'
                : 'You have an unsaved recording. If you go back, it will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorMain,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      
      if (shouldDiscard == true && _isRecording) {
        // Stop recording if in progress
        await _recorder.stop();
      }
      
      return shouldDiscard ?? false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${directory.path}/recording_$timestamp.m4a';
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingPath = path;
          _recordingDuration = 0;
        });

        _waveController.repeat();
        _updateDuration();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission denied'),
              backgroundColor: AppColors.errorMain,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      _waveController.stop();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pausing recording: $e')),
        );
      }
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();
      _waveController.repeat();
      setState(() {
        _isPaused = false;
      });
      _updateDuration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSave() async {
    try {
      _waveController.stop();
      final path = await _recorder.stop();
      if (path != null && mounted) {
        final file = File(path);
        final fileSize = await file.length();
        
        setState(() {
          _isRecording = false;
        });
        
        // Navigate to audio preview screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AudioPreviewScreen(
              audioUri: path,
              source: 'recording',
              duration: _recordingDuration,
              fileSize: fileSize,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recording saved')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  void _discardRecording() async {
    _waveController.stop();
    try {
      await _recorder.stop();
    } catch (e) {
      // Ignore errors when stopping
    }
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
    Navigator.pop(context);
  }

  void _updateDuration() {
    if (_isRecording && !_isPaused) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isRecording && !_isPaused) {
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
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
        ),
        title: Text(
          'Record Audio',
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.large),
          child: Column(
            children: [
              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
        children: [
                    // Recording indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording && !_isPaused
                            ? Colors.red.withOpacity(0.3)
                            : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _isRecording && !_isPaused ? 50 : 40,
                          height: _isRecording && !_isPaused ? 50 : 40,
                          decoration: BoxDecoration(
                            color: _isRecording && !_isPaused
                                ? Colors.red
                                : Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording
                                ? (_isPaused ? Icons.pause : Icons.mic)
                                : Icons.mic_none,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

          // Timer display
          Text(
            _formatDuration(_recordingDuration),
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 56,
                        letterSpacing: 4,
                      ),
          ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? (_isPaused ? 'Paused' : 'Recording...')
                          : 'Ready to record',
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withOpacity(0.85),
              ),
            ),
                  ],
                ),
              ),

          const SizedBox(height: AppSpacing.extraLarge),

              // Waveform visualization
          Container(
            width: double.infinity,
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.warmBrown.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
            ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_waveCount, (index) {
                    final height = _waveHeights[index] * 80;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      width: 4,
                      height: height.clamp(8.0, 80.0),
                      decoration: BoxDecoration(
                        color: _isRecording && !_isPaused
                            ? AppColors.warmBrown
                            : AppColors.warmBrown.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
              ),
                    );
                  }),
            ),
          ),

              const Spacer(),

          // Control buttons
              if (!_isRecording)
                // Start recording button
                _buildPrimaryButton(
                  icon: Icons.mic,
                  label: 'Start Recording',
                  onPressed: _startRecording,
                  )
                else
                // Recording controls
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pause/Resume button
                        _buildControlButton(
                          icon: _isPaused ? Icons.play_arrow : Icons.pause,
                          label: _isPaused ? 'Resume' : 'Pause',
                          onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                          isSecondary: true,
                        ),
                        const SizedBox(width: 20),

                        // Stop and save button
                        _buildControlButton(
                          icon: Icons.check,
                          label: 'Save',
                          onPressed: _stopAndSave,
                          isSecondary: false,
                        ),
                        const SizedBox(width: 20),

                        // Discard button
                        _buildControlButton(
                          icon: Icons.delete_outline,
                          label: 'Discard',
                          onPressed: _discardRecording,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.extraLarge),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.warmBrown,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.warmBrown.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
                    ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSecondary = false,
    bool isDestructive = false,
  }) {
    Color bgColor;
    Color iconColor;
    Color borderColor;

    if (isDestructive) {
      bgColor = AppColors.errorMain.withOpacity(0.1);
      iconColor = AppColors.errorMain;
      borderColor = AppColors.errorMain.withOpacity(0.3);
    } else if (isSecondary) {
      bgColor = Colors.white;
      iconColor = AppColors.warmBrown;
      borderColor = AppColors.warmBrown.withOpacity(0.3);
    } else {
      bgColor = AppColors.warmBrown;
      iconColor = Colors.white;
      borderColor = AppColors.warmBrown;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isDestructive ? AppColors.errorMain : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
