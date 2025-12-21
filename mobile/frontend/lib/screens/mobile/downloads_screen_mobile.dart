import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/download_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../models/content_item.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';

/// Mobile Downloads Screen - Shows downloaded content for offline playback
class DownloadsScreenMobile extends StatefulWidget {
  const DownloadsScreenMobile({super.key});

  @override
  State<DownloadsScreenMobile> createState() => _DownloadsScreenMobileState();
}

class _DownloadsScreenMobileState extends State<DownloadsScreenMobile> {
  /// Helper to trigger a manual reload via DownloadProvider
  Future<void> _loadDownloads() async {
    await context.read<DownloadProvider>().loadDownloads();
  }

  Future<void> _deleteDownload(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Remove "$title" from downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await context.read<DownloadProvider>().deleteDownload(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Deleted "$title"' : 'Failed to delete "$title"',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Downloads'),
        content: const Text('This will remove all downloaded content. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider = context.read<DownloadProvider>();
        final downloads = List<Map<String, dynamic>>.from(
          provider.completedDownloads,
        );
        for (final download in downloads) {
          await provider.deleteDownload(download['id'].toString());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All downloads cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear downloads: $e')),
          );
        }
      }
    }
  }

  void _playDownload(Map<String, dynamic> download) {
    final mediaType = (download['media_type'] as String?) ?? 'audio';
    final downloadedAt = download['downloaded_at'] as int?;

    // Helper to map a download row into a ContentItem for audio playback
    ContentItem mapToContentItem(Map<String, dynamic> d) {
      final id = d['id'].toString();
      final durationSeconds = d['duration'] as int?;
      return ContentItem(
        id: id,
        title: d['title'] as String? ?? 'Unknown',
        creator: d['creator'] as String? ?? 'Unknown',
        coverImage: d['cover_image'] as String?,
        audioUrl: d['local_path'] as String?,
        duration:
            durationSeconds != null ? Duration(seconds: durationSeconds) : null,
        category: d['category'] as String? ?? 'Download',
        createdAt: downloadedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(downloadedAt)
            : DateTime.now(),
      );
    }

    if (mediaType == 'video') {
      // TODO: Implement offline video playback screen for downloaded videos
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video downloads playback not yet implemented'),
        ),
      );
      return;
    }

    // Audio download: build queue from all audio downloads and play with autoplay
    final provider = context.read<DownloadProvider>();
    final allDownloads = provider.completedDownloads
        .where((d) => ((d['media_type'] as String?) ?? 'audio') == 'audio')
        .toList();

    final playlist = allDownloads.map(mapToContentItem).toList();
    final currentItem = mapToContentItem(download);
    final startIndex =
        playlist.indexWhere((item) => item.id == currentItem.id);

    final audioPlayer = context.read<AudioPlayerState>();
    if (startIndex >= 0) {
      audioPlayer.playContentWithQueue(
        currentItem,
        playlist,
        section: 'downloads',
      );
    } else {
      // Fallback: single-item playback with queue containing only this item
      audioPlayer.playContentWithQueue(
        currentItem,
        [currentItem],
        section: 'downloads',
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = context.watch<DownloadProvider>();
    final downloads = downloadProvider.completedDownloads;
    final isLoading = downloadProvider.isLoading;

    // Calculate total size via provider if available, otherwise fallback to sum
    int totalSize = downloadProvider.totalStorageBytes;
    if (totalSize == 0 && downloads.isNotEmpty) {
      for (final d in downloads) {
        totalSize += (d['file_size'] as int?) ?? 0;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Downloads',
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (downloads.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppColors.textSecondary),
              onPressed: _clearAllDownloads,
              tooltip: 'Clear all',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadDownloads,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Storage Info
          if (downloads.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(AppSpacing.medium),
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.small),
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storage,
                      color: AppColors.primaryMain,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${downloads.length} item${downloads.length == 1 ? '' : 's'} downloaded',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Total size: ${_formatSize(totalSize)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Downloads List
          Expanded(
            child: isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.small),
                        child: LoadingShimmer(width: double.infinity, height: 80),
                      );
                    },
                  )
                : downloads.isEmpty
                    ? const EmptyState(
                        icon: Icons.download_done,
                        title: 'No Downloads',
                        message: 'Downloaded content will appear here for offline playback',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                        itemCount: downloads.length,
                        itemBuilder: (context, index) {
                          final download = downloads[index];
                          return _buildDownloadItem(download);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadItem(Map<String, dynamic> download) {
    final id = download['id'] as String;
    final title = download['title'] as String;
    final creator = download['creator'] as String? ?? 'Unknown';
    final coverImage = download['cover_image'] as String?;
    final duration = download['duration'] as int?;
    final fileSize = download['file_size'] as int? ?? 0;
    final downloadedAt = download['downloaded_at'] as int?;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.large),
        decoration: BoxDecoration(
          color: AppColors.errorMain,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteDownload(id, title),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.small),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: AppColors.cardBackground,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.small),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              color: AppColors.backgroundSecondary,
              child: coverImage != null
                  ? Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : const Icon(
                      Icons.music_note,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          title: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                creator,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.download_done,
                    size: 14,
                    color: AppColors.successMain,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatSize(fileSize),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (duration != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(duration),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                onPressed: () => _deleteDownload(id, title),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_filled, color: AppColors.primaryMain),
                onPressed: () => _playDownload(download),
              ),
            ],
          ),
          onTap: () => _playDownload(download),
        ),
      ),
    );
  }
}
