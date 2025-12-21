import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../models/content_item.dart';
import '../../theme/app_colors.dart';
import '../../widgets/audio/vinyl_disc.dart';
import '../../screens/audio/audio_player_full_screen_new.dart';
import '../../widgets/shared/image_helper.dart';

/// Sliding Audio Player - Slides up from bottom with vinyl disc
class SlidingAudioPlayer extends StatefulWidget {
  const SlidingAudioPlayer({super.key});

  @override
  State<SlidingAudioPlayer> createState() => SlidingAudioPlayerState();
}

/// Public state class for GlobalKey access
class SlidingAudioPlayerState extends State<SlidingAudioPlayer> with SingleTickerProviderStateMixin {
  bool _isExpanded = false; // Start minimized - user taps to expand
  ContentItem? _lastTrackId; // Track the current track to detect changes
  
  // Expose state for external access (used by GlobalKey)
  bool get isExpanded => _isExpanded;
  
  // ValueNotifier to notify parent of state changes
  static final ValueNotifier<bool> expansionStateNotifier = ValueNotifier<bool>(false);
  
  @override
  void initState() {
    super.initState();
    expansionStateNotifier.value = _isExpanded;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioPlayer = Provider.of<AudioPlayerState>(context, listen: false);
    
    // Handle track becoming null (stopped/cleared)
    if (audioPlayer.currentTrack == null && _lastTrackId != null) {
      // Track was cleared - reset expansion state immediately
      _lastTrackId = null;
      if (_isExpanded && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              expansionStateNotifier.value = _isExpanded;
            });
          }
        });
      }
      return;
    }
    
    // Handle new track playing
    if (audioPlayer.currentTrack != null && audioPlayer.currentTrack != _lastTrackId) {
      // New track detected - ensure minimized
      _lastTrackId = audioPlayer.currentTrack;
      if (_isExpanded && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              expansionStateNotifier.value = _isExpanded;
            });
          }
        });
      }
    }
  }
  
  void minimizePlayer() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        expansionStateNotifier.value = _isExpanded;
      });
    }
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      expansionStateNotifier.value = _isExpanded;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = Provider.of<AudioPlayerState>(context);

    // Don't show anything if no track is playing
    if (audioPlayer.currentTrack == null) {
      // Reset expansion state if it was expanded to ensure clean hide
      if (_isExpanded && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              expansionStateNotifier.value = _isExpanded;
              _lastTrackId = null;
            });
          }
        });
      }
      return const SizedBox.shrink();
    }

    final track = audioPlayer.currentTrack!;
    final screenHeight = MediaQuery.of(context).size.height;

    // Update last track reference
    if (_lastTrackId != track) {
      _lastTrackId = track;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      height: _isExpanded ? screenHeight : 80,
      width: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryMain, AppColors.accentMain],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_isExpanded ? 0 : 12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_isExpanded ? 0 : 12),
        ),
        child: _isExpanded 
            ? _buildExpandedPlayer(context, audioPlayer, track) 
            : _buildMinimizedPlayer(context, audioPlayer, track),
      ),
    );
  }

  Widget _buildMinimizedPlayer(BuildContext context, AudioPlayerState audioPlayer, track) {
    return GestureDetector(
      onTap: () {
        // Navigate directly to full-screen player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AudioPlayerFullScreenNew(),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        alignment: Alignment.center,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
          // Album Art - Using ImageHelper for consistency with homepage cards
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: track.coverImage != null
                ? Image(
                    image: ImageHelper.getImageProvider(
                      track.coverImage,
                      fallbackAsset: ImageHelper.getFallbackAsset(
                        int.tryParse(track.id) ?? 0,
                      ),
                    ),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      ImageHelper.getFallbackAsset(
                        int.tryParse(track.id) ?? 0,
                      ),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[300],
                        child: const Icon(Icons.music_note, color: Colors.grey),
                      ),
                    ),
                  )
                : Image.asset(
                    ImageHelper.getFallbackAsset(
                      int.tryParse(track.id) ?? 0,
                    ),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          
          // Track Info
          Expanded(
            child: SizedBox(
              height: 56, // Match album art height to prevent overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      track.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      track.creator,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 4),
          
          // Favorite Button
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              final isFavorite = favoritesProvider.isFavorite(track.id);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await favoritesProvider.toggleFavorite(track);
                },
              );
            },
          ),
          
          // Previous Button
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => audioPlayer.previous(),
          ),
          
          // Play/Pause Button
          IconButton(
            icon: Icon(
              audioPlayer.isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 36,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => audioPlayer.togglePlayPause(),
          ),
          
          // Next Button
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => audioPlayer.next(),
          ),
          
          // Close Button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              await audioPlayer.stop();
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildExpandedPlayer(BuildContext context, AudioPlayerState audioPlayer, track) {
    // This should not be called anymore - navigation happens from minimized player
    // But keep it as fallback just in case
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isExpanded && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AudioPlayerFullScreenNew(),
            fullscreenDialog: true,
          ),
        ).then((_) {
          if (mounted && _isExpanded) {
            setState(() {
              _isExpanded = false;
              expansionStateNotifier.value = _isExpanded;
            });
          }
        });
      }
    });
    
    return Container(
      color: AppColors.backgroundPrimary,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primaryMain),
      ),
    );
  }
}


