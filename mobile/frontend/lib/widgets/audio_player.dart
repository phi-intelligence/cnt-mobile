import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioPlayer extends StatefulWidget {
  final String? coverImage;
  final String trackTitle;
  final String artist;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Function(double)? onSeek;

  const AudioPlayer({
    super.key,
    this.coverImage,
    required this.trackTitle,
    required this.artist,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onSeek,
  });

  @override
  State<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album Art
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: widget.coverImage != null
                  ? DecorationImage(
                      image: NetworkImage(widget.coverImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: widget.coverImage == null ? Colors.grey[300] : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.coverImage == null
                ? const Icon(Icons.music_note, size: 30, color: Colors.grey)
                : null,
          ),

          // Track Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trackTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.artist,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Progress Bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: widget.currentPosition.inMilliseconds.toDouble(),
                    min: 0,
                    max: widget.totalDuration.inMilliseconds.toDouble(),
                    onChanged: widget.onSeek != null
                        ? (value) => widget.onSeek!(value)
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: widget.onPrevious,
              ),
              IconButton(
                icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 32,
                onPressed: widget.onPlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: widget.onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

