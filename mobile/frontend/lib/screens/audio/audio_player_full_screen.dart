import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/audio/vinyl_disc.dart';
import '../../utils/dimension_utils.dart';

/// Full-Screen Audio Player - Exact replica of React Native implementation
/// Features rotating vinyl disc, gradient background, and full playback controls
class AudioPlayerFullScreen extends StatefulWidget {
  final String trackId;
  final String title;
  final String artist;
  final String album;
  final int duration; // in seconds
  final List<Color> gradientColors;
  final bool isFavorite;
  final VoidCallback? onBack;
  final VoidCallback? onDonate;
  final VoidCallback? onFavorite;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final void Function(int) onSeek;

  const AudioPlayerFullScreen({
    super.key,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.gradientColors,
    this.isFavorite = false,
    this.onBack,
    this.onDonate,
    this.onFavorite,
    this.onShuffle,
    this.onRepeat,
    this.onPrevious,
    this.onNext,
    required this.onSeek,
  });

  @override
  State<AudioPlayerFullScreen> createState() => _AudioPlayerFullScreenState();
}

class _AudioPlayerFullScreenState extends State<AudioPlayerFullScreen> {
  bool _isPlaying = false;
  int _currentTime = 0;
  bool _isShuffled = false;
  bool _isRepeating = false;
  final double _volume = 1.0;

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final vinylSize = DimensionUtils.getVinylDiscSize(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: widget.onBack,
                    ),
                    
                    // Donate button
                    Flexible(
                      child: ElevatedButton.icon(
                      onPressed: widget.onDonate,
                      icon: const Icon(Icons.favorite, size: 20),
                      label: const Text('Donate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.3),
                        foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    
                    // Menu button
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      color: Colors.white,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Vinyl Disc - Center of Screen
              Expanded(
                child: Center(
                  child: VinylDisc(
                    size: vinylSize,
                    artist: widget.artist,
                    isPlaying: _isPlaying,
                  ),
                ),
              ),

              // Track Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Artist
                    Text(
                      widget.artist,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Album
                    Text(
                      widget.album,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: _currentTime.toDouble(),
                      min: 0.0,
                      max: widget.duration.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withOpacity(0.3),
                      onChanged: (value) {
                        setState(() {
                          _currentTime = value.toInt();
                        });
                        widget.onSeek(_currentTime);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_currentTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatTime(widget.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: _isShuffled ? Colors.white : Colors.white.withOpacity(0.7),
                      ),
                      iconSize: 24,
                      onPressed: () {
                        setState(() {
                          _isShuffled = !_isShuffled;
                        });
                        widget.onShuffle?.call();
                      },
                    ),

                    // Previous
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      iconSize: 32,
                      onPressed: widget.onPrevious,
                    ),

                    // Play/Pause
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),

                    // Next
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      iconSize: 32,
                      onPressed: widget.onNext,
                    ),

                    // Repeat
                    IconButton(
                      icon: Icon(
                        Icons.repeat,
                        color: _isRepeating ? Colors.white : Colors.white.withOpacity(0.7),
                      ),
                      iconSize: 24,
                      onPressed: () {
                        setState(() {
                          _isRepeating = !_isRepeating;
                        });
                        widget.onRepeat?.call();
                      },
                    ),
                  ],
                ),
              ),

              // Donate Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: widget.onDonate,
                  icon: const Icon(Icons.favorite),
                  label: const Text('Support Artist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

