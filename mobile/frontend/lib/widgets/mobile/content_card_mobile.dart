import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_item.dart';
import '../shared/image_helper.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class ContentCardMobile extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const ContentCardMobile({
    super.key,
    required this.item,
    this.onTap,
    this.onPlay,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Thumbnail - Use CachedNetworkImage for better performance
              SizedBox(
                width: 60,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageHelper.buildCachedImage(
                    imageUrl: item.coverImage,
                    fallbackAsset: ImageHelper.getFallbackAsset(
                      int.tryParse(item.id) ?? 0,
                    ),
                    fit: BoxFit.cover,
                    memCacheWidth: 120, // 2x for retina (60px * 2)
                    memCacheHeight: 120,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.grey,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.creator,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (item.duration != null)
                          Text(
                            _formatDuration(item.duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        if (item.plays > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                '${item.plays}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Play Button
              IconButton(
                icon: Icon(
                  Icons.play_circle_filled,
                  color: AppColors.warmBrown,
                  size: 36,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onPlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

