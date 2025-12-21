import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/content_item.dart';
import '../providers/audio_player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({super.key});

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerState>(
      builder: (context, audioProvider, _) {
        final queue = audioProvider.queue;
        final currentTrack = audioProvider.currentTrack;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: AppSpacing.small),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.large,
                  vertical: AppSpacing.small,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now Playing',
                          style: AppTypography.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '${queue.length} tracks in queue',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (queue.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          audioProvider.clearQueue();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Clear All',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.errorMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Queue list
              if (queue.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_outlined,
                          size: 64,
                          color: AppColors.warmBrown.withOpacity(0.3),
                        ),
                        SizedBox(height: AppSpacing.medium),
                        Text(
                          'Queue is empty',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final isCurrentTrack = currentTrack?.id == track.id;

                      return Dismissible(
                        key: Key(track.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.errorMain,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: AppSpacing.large),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          // TODO: Implement remove from queue
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed ${track.title} from queue'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: track.coverImage != null
                                  ? DecorationImage(
                                      image: NetworkImage(track.coverImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: AppColors.warmBrown.withOpacity(0.2),
                            ),
                            child: track.coverImage == null
                                ? Icon(
                                    Icons.music_note,
                                    color: AppColors.warmBrown,
                                  )
                                : isCurrentTrack
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                          ),
                          title: Text(
                            track.title,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentTrack ? AppColors.primaryMain : AppColors.primaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.creator,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatDuration(track.duration),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: AppSpacing.small),
                              Icon(
                                Icons.drag_handle,
                                color: AppColors.warmBrown.withOpacity(0.5),
                                size: 20,
                              ),
                            ],
                          ),
                          onTap: isCurrentTrack
                              ? null
                              : () {
                                  // Skip to this track
                                  // TODO: Implement skip to specific track in queue
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Playing ${track.title}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
