import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../models/content_item.dart';
import '../../providers/download_provider.dart';
import '../../providers/favorites_provider.dart';
import '../donation_modal.dart';

/// Video Player Full Screen - Exact replica of React Native implementation
/// Features auto-hiding controls, fullscreen toggle, and gradient background
class VideoPlayerFullScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String author;
  final int? authorId; // Creator's user ID for donations
  final int duration;
  final List<Color> gradientColors;
  final bool isFavorite;
  final String videoUrl;
  final VoidCallback? onBack;
  final VoidCallback? onFavorite;
  final void Function(int)? onSeek;
  // Optional playlist support
  final List<ContentItem>? playlist;
  final int? initialIndex;

  const VideoPlayerFullScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.author,
    this.authorId,
    required this.duration,
    required this.gradientColors,
    required this.videoUrl,
    this.isFavorite = false,
    this.onBack,
    this.onFavorite,
    this.onSeek,
    this.playlist,
    this.initialIndex,
  });

  @override
  State<VideoPlayerFullScreen> createState() => _VideoPlayerFullScreenState();
}

class _VideoPlayerFullScreenState extends State<VideoPlayerFullScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  int _currentTime = 0;
  late List<ContentItem> _playlist;
  late int _currentIndex;
  
  // Seek/Scrubbing
  bool _isScrubbing = false;
  double _scrubValue = 0.0;
  bool _wasPlayingBeforeScrub = false;
  
  // Mouse movement detection
  Timer? _hideControlsTimer;
  bool _isMouseOverVideo = false;
  
  // Store original orientation preferences
  List<DeviceOrientation>? _originalOrientations;
  
  // Volume control (Netflix-like)
  double _volume = 1.0;
  bool _isMuted = false;
  bool _showVolumeSlider = false;
  
  // Playback speed (Netflix-like)
  double _playbackSpeed = 1.0;
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  ContentItem get _currentItem => _playlist[_currentIndex];
  bool get _hasNext => _currentIndex < _playlist.length - 1;
  bool get _hasPrevious => _currentIndex > 0;

  @override
  void initState() {
    super.initState();
    // Build playlist: if none provided, create a single-item list from the widget props
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      _playlist = List<ContentItem>.from(widget.playlist!);
      final providedIndex = widget.initialIndex ?? 0;
      _currentIndex = providedIndex.clamp(0, _playlist.length - 1);
    } else {
      _playlist = [
        ContentItem(
          id: widget.videoId,
          title: widget.title,
          creator: widget.author,
          creatorId: widget.authorId,
          description: null,
          coverImage: null,
          audioUrl: null,
          videoUrl: widget.videoUrl,
          duration: Duration(seconds: widget.duration),
          category: 'Video Podcast',
          createdAt: DateTime.now(),
        ),
      ];
      _currentIndex = 0;
    }

    _initializePlayer();
    _startControlsTimer();
    
    // Ensure system UI is visible initially
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  
  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });
    
    // Hide system UI bars for immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    
    // Allow landscape orientations for fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _showControlsWithAutoHide();
  }
  
  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
    
    // Restore system UI bars
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    
    // Restore original orientation preferences or default to portrait
    if (_originalOrientations != null) {
      SystemChrome.setPreferredOrientations(_originalOrientations!);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    
    _showControlsWithAutoHide();
  }

  Future<void> _initializePlayer() async {
    try {
      final videoUrl = _currentItem.videoUrl ?? widget.videoUrl;
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();
      await _controller!.play();
      
      _controller!.addListener(_videoListener);
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    
    // Don't update position during scrubbing
    if (_isScrubbing) return;
    
    setState(() {
      // Update current time for seek callback
      final position = _controller!.value.position;
      _currentTime = position.inSeconds;
      widget.onSeek?.call(_currentTime);
    });
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_controller?.value.isPlaying ?? false) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && (_controller?.value.isPlaying ?? false) && !_isScrubbing) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }
  
  void _showControlsWithAutoHide() {
    _hideControlsTimer?.cancel();
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }
  
  void _hideControls() {
    _hideControlsTimer?.cancel();
    if (mounted && (_controller?.value.isPlaying ?? false)) {
      setState(() {
        _showControls = false;
      });
    }
  }
  
  void _onMouseEnter() {
    setState(() {
      _isMouseOverVideo = true;
    });
    _showControlsWithAutoHide();
  }

  void _onMouseExit() {
    setState(() {
      _isMouseOverVideo = false;
    });
    if (_controller?.value.isPlaying ?? false) {
      _hideControls();
    }
  }

  void _onMouseMove() {
    if (_isMouseOverVideo) {
      _showControlsWithAutoHide();
    }
  }

  void _toggleControls() {
    _showControlsWithAutoHide();
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) return;
    
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }

  Future<void> _seekTo(int seconds) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final duration = _controller!.value.duration.inSeconds;
    final clamped = seconds.clamp(0, duration);
    await _controller!.seekTo(Duration(seconds: clamped));
  }

  Future<void> _loadEpisode(int newIndex) async {
    if (newIndex < 0 || newIndex >= _playlist.length) return;

    _controller?.removeListener(_videoListener);
    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _currentIndex = newIndex;
      _currentTime = 0;
    });

    await _initializePlayer();
  }

  Future<void> _playNext() async {
    if (_hasNext) {
      await _loadEpisode(_currentIndex + 1);
    }
  }

  Future<void> _playPrevious() async {
    if (_hasPrevious) {
      await _loadEpisode(_currentIndex - 1);
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _controller?.setVolume(_isMuted ? 0 : _volume);
  }
  
  void _setVolume(double value) {
    setState(() {
      _volume = value;
      _isMuted = value == 0;
    });
    _controller?.setVolume(value);
  }
  
  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _controller?.setPlaybackSpeed(speed);
  }
  
  Widget _buildControlsContent({bool isCompact = false}) {
    // Use compact sizes for embedded mode, larger for fullscreen
    final playButtonSize = isCompact ? 52.0 : 64.0;
    final playIconSize = isCompact ? 32.0 : 40.0;
    final skipIconSize = isCompact ? 24.0 : 28.0;
    final seekIconSize = isCompact ? 28.0 : 32.0;
    final spacing = isCompact ? AppSpacing.small : AppSpacing.large;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar row
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: isCompact ? 3 : 4,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isCompact ? 6 : 8,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: isCompact ? 12 : 16,
                  ),
                ),
                child: Slider(
                  value: _isScrubbing
                      ? _scrubValue
                      : _currentTime.toDouble(),
                  min: 0.0,
                  max: (_controller?.value.duration.inSeconds.toDouble() ??
                          widget.duration.toDouble())
                      .clamp(0.0, double.infinity),
                  activeColor: AppColors.primaryMain,
                  inactiveColor: Colors.white.withOpacity(0.3),
                  thumbColor: AppColors.primaryMain,
                  onChangeStart: (value) {
                    setState(() {
                      _isScrubbing = true;
                      _scrubValue = value;
                      _wasPlayingBeforeScrub = _controller?.value.isPlaying ?? false;
                    });
                    _controller?.pause();
                  },
                  onChanged: (value) {
                    setState(() {
                      _scrubValue = value;
                      _currentTime = value.toInt();
                    });
                    widget.onSeek?.call(_currentTime);
                  },
                  onChangeEnd: (value) async {
                    await _seekTo(value.toInt());
                    setState(() {
                      _isScrubbing = false;
                    });
                    if (_wasPlayingBeforeScrub) {
                      _controller?.play();
                      _startControlsTimer();
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              width: 44, // Minimum touch target
              height: 44,
              child: IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  size: isCompact ? 22 : 24,
                ),
                color: Colors.white,
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (_isFullscreen) {
                    _exitFullscreen();
                  } else {
                    _enterFullscreen();
                  }
                },
                tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
              ),
            ),
          ],
        ),
        // Time labels
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(_currentTime),
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                  fontSize: isCompact ? 11 : 12,
              ),
            ),
            Text(
              _formatTime(_controller?.value.duration.inSeconds ?? widget.duration),
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                  fontSize: isCompact ? 11 : 12,
              ),
            ),
          ],
        ),
        ),
        SizedBox(height: spacing),
        // Playback controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous Track Button
            SizedBox(
              width: 44, // Minimum touch target
              height: 44,
              child: IconButton(
                icon: Icon(Icons.skip_previous, size: skipIconSize),
                color: _hasPrevious ? Colors.white : Colors.white24,
                padding: EdgeInsets.zero,
                onPressed: _hasPrevious ? _playPrevious : null,
                tooltip: 'Previous Track',
              ),
            ),
            // Rewind 10 seconds Button
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: Icon(Icons.replay_10, size: seekIconSize),
                color: Colors.white,
                padding: EdgeInsets.zero,
                onPressed: () => _seekTo(_currentTime - 10),
                tooltip: 'Rewind 10s',
              ),
            ),
            // Play/Pause Button
            GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                width: playButtonSize,
                height: playButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryMain.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _controller != null && _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  size: playIconSize,
                ),
              ),
            ),
            // Forward 10 seconds Button
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: Icon(Icons.forward_10, size: seekIconSize),
                color: Colors.white,
                padding: EdgeInsets.zero,
                onPressed: () => _seekTo(_currentTime + 10),
                tooltip: 'Forward 10s',
              ),
            ),
            // Next Track Button
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: Icon(Icons.skip_next, size: skipIconSize),
                color: _hasNext ? Colors.white : Colors.white24,
                padding: EdgeInsets.zero,
                onPressed: _hasNext ? _playNext : null,
                tooltip: 'Next Track',
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? AppSpacing.small : AppSpacing.medium),
        // Volume and speed controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Volume control
            GestureDetector(
              onTap: () {
                setState(() {
                  _showVolumeSlider = !_showVolumeSlider;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                    icon: Icon(
                      _isMuted || _volume == 0
                          ? Icons.volume_off_rounded
                          : _volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                      color: Colors.white,
                        size: isCompact ? 20 : 24,
                    ),
                      padding: EdgeInsets.zero,
                    onPressed: _toggleMute,
                    tooltip: _isMuted ? 'Unmute' : 'Mute',
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _showVolumeSlider ? (isCompact ? 80 : 100) : 0,
                    child: _showVolumeSlider
                        ? SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: _isMuted ? 0 : _volume,
                              onChanged: _setVolume,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
            // Playback speed control
            PopupMenuButton<double>(
              initialValue: _playbackSpeed,
              onSelected: _setPlaybackSpeed,
              tooltip: 'Playback speed',
              color: Colors.black87,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? 12 : 14,
                  ),
                ),
              ),
              itemBuilder: (context) => _availableSpeeds.map((speed) {
                return PopupMenuItem<double>(
                  value: speed,
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: _playbackSpeed == speed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    
    // Restore system UI and orientation on dispose
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
    
    // Restore original orientation preferences
    if (_originalOrientations != null) {
      SystemChrome.setPreferredOrientations(_originalOrientations!);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvoked: (didPop) {
        if (!didPop && _isFullscreen) {
          // Exit fullscreen first when back button is pressed
          _exitFullscreen();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: _isFullscreen
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.black, Colors.black],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
          ),
          child: Column(
            children: [
              // Top Bar (hidden in fullscreen)
              if (!_isFullscreen)
                SafeArea(
                  child: Container(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                        onPressed: widget.onBack,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Video Podcast',
                            style: AppTypography.heading4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Donate button - compact icon with tooltip
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.warmBrown,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.volunteer_activism, size: 20),
                              color: Colors.white,
                              onPressed: () {
                                // Open donation modal with current item's creator info
                                showDialog(
                                  context: context,
                                  builder: (_) => DonationModal(
                                    recipientName: _currentItem.creator,
                                    recipientUserId: _currentItem.creatorId ?? 1,
                                  ),
                                );
                              },
                              tooltip: 'Donate',
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.download),
                            color: Colors.white,
                            onPressed: () {
                              final downloadProvider =
                                  context.read<DownloadProvider>();
                              downloadProvider.downloadItem(_currentItem);
                            },
                            tooltip: 'Download',
                          ),
                          // Favorite button with FavoritesProvider integration
                          Consumer<FavoritesProvider>(
                            builder: (context, favoritesProvider, child) {
                              final isFavorite = favoritesProvider.isFavorite(_currentItem.id);
                              return IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                ),
                                color: isFavorite ? Colors.red : Colors.white,
                                onPressed: () async {
                                  final success = await favoritesProvider.toggleFavorite(_currentItem);
                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isFavorite 
                                              ? 'Removed from favorites' 
                                              : 'Added to favorites',
                                        ),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: AppColors.warmBrown,
                                      ),
                                    );
                                  }
                                },
                                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Video area - fills entire screen in fullscreen mode
              Expanded(
                child: _isFullscreen
                    ? Stack(
                        children: [
                          // Video Player - fills entire screen in fullscreen
                          GestureDetector(
                          onTap: _toggleControls,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.black,
                            child: _isInitializing
                                ? const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                : _hasError
                                    ? Center(
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
                                          ],
                                        ),
                                      )
                                    : _controller != null && _controller!.value.isInitialized
                                        ? FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: _controller!.value.size.width,
                                              height: _controller!.value.size.height,
                                              child: VideoPlayer(_controller!),
                                            ),
                                          )
                                        : const Center(
                                            child: CircularProgressIndicator(color: Colors.white),
                                          ),
                          ),
                          ),
                          
                          // Play/Pause Overlay (center, large button) - Only show when paused and controls are hidden
                          if (!_isInitializing && !_hasError && _controller != null && !_controller!.value.isPlaying && !_showControls)
                            Positioned.fill(
                            child: Center(
                              child: GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryMain.withOpacity(0.9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Top overlay with back button, title, and favorite (Netflix-like)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top + AppSpacing.small,
                                  left: AppSpacing.medium,
                                  right: AppSpacing.medium,
                                  bottom: AppSpacing.large,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                                      onPressed: _exitFullscreen,
                                      tooltip: 'Exit fullscreen',
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _currentItem.title,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _currentItem.creator,
                                            style: AppTypography.caption.copyWith(
                                              color: Colors.white70,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Favorite button in fullscreen
                                    Consumer<FavoritesProvider>(
                                      builder: (context, favoritesProvider, child) {
                                        final isFavorite = favoritesProvider.isFavorite(_currentItem.id);
                                        return IconButton(
                                          icon: Icon(
                                            isFavorite ? Icons.favorite : Icons.favorite_border,
                                            color: isFavorite ? Colors.red : Colors.white,
                                            size: 28,
                                          ),
                                          onPressed: () async {
                                            await favoritesProvider.toggleFavorite(_currentItem);
                                          },
                                          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom controls overlay in fullscreen
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.medium,
                                  left: AppSpacing.large,
                                  right: AppSpacing.large,
                                  top: AppSpacing.large,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                                child: _buildControlsContent(isCompact: false),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: MouseRegion(
                        onEnter: (_) => _onMouseEnter(),
                        onExit: (_) => _onMouseExit(),
                        onHover: (_) => _onMouseMove(),
                        child: GestureDetector(
                          onTap: _toggleControls,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black,
                            child: Stack(
                              children: [
                                // Video Player
                                if (_isInitializing)
                                  const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
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
                                      ],
                                    ),
                                  )
                                else if (_controller != null && _controller!.value.isInitialized)
                                  Positioned.fill(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: _controller!.value.aspectRatio,
                                        child: VideoPlayer(_controller!),
                                      ),
                                    ),
                                  ),

                                // Play/Pause Overlay (center, large button)
                                if (!_isInitializing && !_hasError && _controller != null && (!_controller!.value.isPlaying || _isMouseOverVideo))
                                  Positioned.fill(
                                    child: Center(
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: _togglePlayPause,
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primaryMain.withOpacity(0.9),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _controller!.value.isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                          ),
                                        ),
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

              // Bottom controls bar (always at bottom of screen)
              // In fullscreen, show controls overlay on top of video using Stack
              if (_isFullscreen)
                const SizedBox.shrink() // Controls are shown in the Stack above
              else
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.large),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: _buildControlsContent(isCompact: true),
                  ),
                ),
          ],
        ),
      ),
      ),
    );
  }
}

