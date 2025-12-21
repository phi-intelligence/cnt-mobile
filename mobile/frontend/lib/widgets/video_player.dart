import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../theme/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final int? startTime; // Start time in seconds (for preview segments)
  final int? endTime; // End time in seconds (for preview segments)
  final VoidCallback? onSegmentEnd; // Callback when segment ends

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.title,
    this.startTime,
    this.endTime,
    this.onSegmentEnd,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isScrubbing = false;
  double _scrubValue = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      _controller = VideoPlayerController.networkUrl(uri);

      // Protect against hanging initialization by enforcing a timeout
      await _controller!
          .initialize()
          .timeout(const Duration(seconds: 15));
      _controller!.addListener(_videoListener);
      
      // If start time is specified, seek to it
      if (widget.startTime != null && widget.startTime! > 0) {
        await _controller!.seekTo(Duration(seconds: widget.startTime!));
      }
      
      // Start playing
      await _controller!.play();
      
      setState(() {
        _isInitializing = false;
      });
      _autoHideControls();
    } on TimeoutException catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video took too long to load. Please try again.\n$e';
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  void _videoListener() {
    if (!mounted) return;

    // Check if we've reached the end time (for preview segments)
    if (widget.endTime != null && _controller != null && _controller!.value.isInitialized) {
      final currentPosition = _controller!.value.position.inSeconds;
      if (currentPosition >= widget.endTime!) {
        _controller!.pause();
        widget.onSegmentEnd?.call();
      }
    }

    if (_isScrubbing) return;

    setState(() {});
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _autoHideControls();
      }
    });
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _seekBy(Duration offset) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    final duration = _controller!.value.duration;
    var target = _controller!.value.position + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (target > duration) {
      target = duration;
    }
    _controller!.seekTo(target);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: 28,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
            if (_isInitializing)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.warmBrown,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            else if (_hasError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading video',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              )
            else if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top Controls with Gradient Overlay
            if (!_isInitializing && !_hasError)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            if (widget.title != null)
                              Expanded(
                                child: Text(
                                  widget.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(width: 48), // Balance for back button
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Play/Pause Button (Centered)
            if (!_isInitializing && !_hasError && _controller != null)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warmBrown.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 40,
                      icon: Icon(
                        _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  ),
                ),
              ),

            // Bottom Controls with Gradient Overlay
            if (!_isInitializing && !_hasError && _controller != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress Bar
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_controller!.value.position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.0,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                      activeTrackColor: AppColors.warmBrown,
                                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                                      thumbColor: AppColors.warmBrown,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        double maxPosition = 1;
                                        double currentPosition = 0;
                                        if (_controller != null && _controller!.value.isInitialized) {
                                          maxPosition = _controller!.value.duration.inMilliseconds.toDouble();
                                          if (maxPosition <= 0) {
                                            maxPosition = 1;
                                          }
                                          currentPosition = _controller!.value.position.inMilliseconds.toDouble();
                                        }
                                        final sliderValue = (_isScrubbing
                                                ? _scrubValue.clamp(0, maxPosition)
                                                : currentPosition.clamp(0, maxPosition))
                                            .toDouble();
                                        return Slider(
                                          value: sliderValue,
                                          min: 0,
                                          max: maxPosition,
                                          onChangeStart: (value) {
                                            if (!mounted) return;
                                            setState(() {
                                              _isScrubbing = true;
                                              _scrubValue = value;
                                            });
                                          },
                                          onChanged: (value) {
                                            if (!mounted) return;
                                            setState(() {
                                              _scrubValue = value;
                                            });
                                          },
                                          onChangeEnd: (value) {
                                            if (_controller != null && _controller!.value.isInitialized) {
                                              _controller!.seekTo(Duration(milliseconds: value.toInt()));
                                            }
                                            if (mounted) {
                                              setState(() {
                                                _isScrubbing = false;
                                              });
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDuration(_controller!.value.duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Control Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildControlButton(
                                  icon: Icons.replay_10,
                                  onPressed: () => _seekBy(const Duration(seconds: -10)),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.warmBrown,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.warmBrown.withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    iconSize: 40,
                                    icon: Icon(
                                      _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                ),
                                _buildControlButton(
                                  icon: Icons.forward_10,
                                  onPressed: () => _seekBy(const Duration(seconds: 10)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

