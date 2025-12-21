import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../screens/audio/audio_player_full_screen_new.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class GlobalAudioPlayer extends StatelessWidget {
  const GlobalAudioPlayer({super.key});

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayer = Provider.of<AudioPlayerState>(context);

    // Only show player if there's a current track
    if (audioPlayer.currentTrack == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        // Open full-screen player when clicking anywhere on the compact player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AudioPlayerFullScreenNew(),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          border: const Border(
            top: BorderSide(
              color: AppColors.borderPrimary,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Album Art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (audioPlayer.currentTrack!.coverImage != null)
                ? Image.network(
                    audioPlayer.currentTrack!.coverImage!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 56,
                        height: 56,
                        color: AppColors.backgroundTertiary,
                        child: Icon(Icons.music_note, color: AppColors.textTertiary),
                      );
                    },
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.backgroundTertiary,
                    child: Icon(Icons.music_note, color: AppColors.textTertiary),
                  ),
            ),
            const SizedBox(width: 16),
            
            // Track Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    audioPlayer.currentTrack!.title,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    audioPlayer.currentTrack!.creator,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar (stop propagation to prevent opening full screen)
                  GestureDetector(
                    onTap: () {}, // Consume tap to prevent parent GestureDetector from firing
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(audioPlayer.position),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: audioPlayer.duration.inSeconds > 0
                                ? audioPlayer.position.inSeconds / audioPlayer.duration.inSeconds
                                : 0.0,
                            onChanged: audioPlayer.isLoading
                                ? null
                                : (value) {
                                    final newPosition = Duration(
                                      seconds: (value * audioPlayer.duration.inSeconds).toInt(),
                                    );
                                    audioPlayer.seek(newPosition);
                                  },
                            activeColor: AppColors.primaryMain,
                            inactiveColor: AppColors.borderPrimary,
                          ),
                        ),
                        Text(
                          _formatDuration(audioPlayer.duration),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
            // Controls (stop propagation to prevent opening full screen)
            GestureDetector(
              onTap: () {}, // Consume tap to prevent parent GestureDetector from firing
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: AppColors.textPrimary,
                    onPressed: audioPlayer.queue.isNotEmpty && audioPlayer.currentTrack != null
                        ? () => audioPlayer.previous()
                        : null,
                  ),
                  IconButton(
                    icon: audioPlayer.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryMain,
                            ),
                          )
                        : Icon(
                            audioPlayer.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 48,
                            color: AppColors.primaryMain,
                          ),
                    onPressed: () => audioPlayer.togglePlayPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: AppColors.textPrimary,
                    onPressed: audioPlayer.queue.isNotEmpty && audioPlayer.currentTrack != null
                        ? () => audioPlayer.next()
                        : null,
                  ),
                ],
              ),
            ),
            
            // Volume (stop propagation to prevent opening full screen)
            GestureDetector(
              onTap: () {}, // Consume tap to prevent parent GestureDetector from firing
              child: SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Icon(Icons.volume_up, size: 20, color: AppColors.textSecondary),
                    Expanded(
                      child: Slider(
                        value: audioPlayer.volume,
                        onChanged: (value) => audioPlayer.setVolume(value),
                        activeColor: AppColors.primaryMain,
                        inactiveColor: AppColors.borderPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Close button
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {}, // Consume tap to prevent parent GestureDetector from firing
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Close player',
                onPressed: () {
                  audioPlayer.stop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

