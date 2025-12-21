import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/artist_provider.dart';
import '../../services/download_service.dart';
import '../../models/content_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared/image_helper.dart';
import '../../widgets/queue_bottom_sheet.dart';
import '../donation_modal.dart';
import '../artist/artist_profile_screen.dart';

/// Full-Screen Audio Player Screen
/// Redesigned to match screenshot with "NOW PLAYING" header, album art, 
/// playback controls with shuffle/repeat, and action buttons
class AudioPlayerFullScreenNew extends StatefulWidget {
  const AudioPlayerFullScreenNew({super.key});

  @override
  State<AudioPlayerFullScreenNew> createState() => _AudioPlayerFullScreenNewState();
}

class _AudioPlayerFullScreenNewState extends State<AudioPlayerFullScreenNew> {
  bool _isShuffled = false;
  bool _isRepeating = false;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = Provider.of<AudioPlayerState>(context);
    final track = audioPlayer.currentTrack;

    // If no track is playing, show last played track with replay option or empty state
    if (track == null) {
      final lastTrack = audioPlayer.lastPlayedTrack;
      if (lastTrack != null) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.warmBrown.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.music_note,
                            size: 60,
                            color: AppColors.warmBrown,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Playback finished',
                          style: AppTypography.heading3.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lastTrack.title,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => audioPlayer.replayLastTrack(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warmBrown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(Icons.replay),
                          label: const Text('Replay'),
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
      
      // No track ever played
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No track playing',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
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

    final screenWidth = MediaQuery.of(context).size.width;
    final albumArtSize = screenWidth * 0.75; // 75% of screen width

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Album Art
                      _buildAlbumArtCard(track, albumArtSize),

                      const SizedBox(height: 24),

                      // Track Info
                      _buildTrackInfo(track),

                      const SizedBox(height: 24),

                      // Progress Bar
                      _buildProgressBar(audioPlayer),

                      const SizedBox(height: 24),

                      // Playback Controls
                      _buildPlaybackControls(audioPlayer),

                      const SizedBox(height: 16),

                      // Action Buttons (Playlist, Heart, Download)
                      _buildActionButtons(track, audioPlayer),

                      const SizedBox(height: 24),

                      // Support Button
                      _buildSupportButton(track),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),

          // Title - Centered
          Expanded(
            child: Text(
              'NOW PLAYING',
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Menu Button
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {
              // TODO: Show menu options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArtCard(ContentItem track, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: track.coverImage != null && track.coverImage!.isNotEmpty
            ? Image(
                image: ImageHelper.getImageProvider(
                  track.coverImage,
                  fallbackAsset: ImageHelper.getFallbackAsset(
                    int.tryParse(track.id) ?? 0,
                  ),
                ),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    ImageHelper.getFallbackAsset(
                      int.tryParse(track.id) ?? 0,
                    ),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: size,
                      height: size,
                      color: AppColors.backgroundTertiary,
                      child: const Icon(
                        Icons.music_note,
                        size: 64,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                },
              )
            : Image.asset(
                ImageHelper.getFallbackAsset(
                  int.tryParse(track.id) ?? 0,
                ),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  color: AppColors.backgroundTertiary,
                  child: const Icon(
                    Icons.music_note,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTrackInfo(ContentItem track) {
    return Column(
      children: [
        // Title
        Text(
          track.title,
          style: AppTypography.heading2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Artist
        Text(
          track.creator,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioPlayerState audioPlayer) {
    final progress = audioPlayer.duration.inSeconds > 0
        ? audioPlayer.position.inSeconds / audioPlayer.duration.inSeconds
        : 0.0;

    return Column(
      children: [
        Slider(
          value: progress.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          activeColor: AppColors.warmBrown,
          inactiveColor: AppColors.borderSecondary,
          onChanged: (value) {
            final newPosition = Duration(
              seconds: (value * audioPlayer.duration.inSeconds).toInt(),
            );
            audioPlayer.seek(newPosition);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(audioPlayer.position),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              _formatDuration(audioPlayer.duration),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(AudioPlayerState audioPlayer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Shuffle Button
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: _isShuffled ? AppColors.warmBrown : AppColors.textTertiary,
            size: 24,
          ),
          onPressed: () {
            setState(() {
              _isShuffled = !_isShuffled;
            });
            // TODO: Implement shuffle functionality
          },
        ),

        // Previous Button
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 32),
          color: AppColors.textPrimary,
          onPressed: () => audioPlayer.previous(),
        ),

        // Play/Pause Button
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.warmBrown,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.warmBrown.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              audioPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () => audioPlayer.togglePlayPause(),
          ),
        ),

        // Next Button
        IconButton(
          icon: const Icon(Icons.skip_next, size: 32),
          color: AppColors.textPrimary,
          onPressed: () => audioPlayer.next(),
        ),

        // Repeat Button
        IconButton(
          icon: Icon(
            Icons.repeat,
            color: _isRepeating ? AppColors.warmBrown : AppColors.textTertiary,
            size: 24,
          ),
          onPressed: () {
            setState(() {
              _isRepeating = !_isRepeating;
            });
            // TODO: Implement repeat functionality
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(ContentItem track, AudioPlayerState audioPlayer) {
    final downloadProvider = context.watch<DownloadProvider>();
    final status = downloadProvider.getDownloadStatus(track.id);
    final isDownloading = status == DownloadStatus.downloading;
    final isDownloaded = status == DownloadStatus.completed;
    final progress = downloadProvider.getProgress(track.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Playlist/Queue Button
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.queue_music,
              color: AppColors.textSecondary,
              size: 24,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const QueueBottomSheet(),
              );
            },
          ),
        ),

        const SizedBox(width: 16),

        // Heart (Favorite) Button
        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            final isFavorite = favoritesProvider.isFavorite(track.id);
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : AppColors.textSecondary,
                  size: 24,
                ),
                onPressed: () async {
                  final success = await favoritesProvider.toggleFavorite(track);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite 
                              ? 'Removed from favorites' 
                              : 'Added to favorites',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),

        const SizedBox(width: 16),

        // Download Button
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isDownloading
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress > 0 && progress <= 1 ? progress : null,
                    color: AppColors.warmBrown,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isDownloaded ? Icons.download_done : Icons.download,
                    color: isDownloaded 
                        ? AppColors.successMain 
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                  onPressed: (isDownloading || isDownloaded)
                      ? null
                      : () {
                          downloadProvider.downloadItem(track);
                        },
                ),
        ),
        
        const SizedBox(width: 16),
        
        // Artist Profile Button
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.person,
              color: AppColors.textSecondary,
              size: 24,
            ),
            tooltip: 'View Artist',
            onPressed: () => _navigateToArtistProfile(track),
                ),
        ),
      ],
    );
  }
  
  /// Navigate to the artist profile of the track's creator
  Future<void> _navigateToArtistProfile(ContentItem track) async {
    final creatorId = track.creatorId;
    if (creatorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artist information not available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Fetch artist by user ID to get the artist ID
    final artistProvider = context.read<ArtistProvider>();
    final artist = await artistProvider.fetchArtistByUserId(creatorId);
    
    if (artist != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistProfileScreen(artistId: artist.id),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load artist profile'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildSupportButton(ContentItem track) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => DonationModal(
              recipientName: track.creator,
              recipientUserId: track.creatorId ?? 1,
            ),
          );
        },
        icon: const Icon(Icons.favorite, color: Colors.white, size: 20),
        label: Text(
          'Support this artist',
          style: AppTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warmBrown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
