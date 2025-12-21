import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/content_item.dart';
import '../shared/image_helper.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';

/// Horizontal card for featured content in horizontal lists
/// Designed for 160px width with thumbnail on top
class HorizontalContentCardMobile extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const HorizontalContentCardMobile({
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

  /// Build cached network image with proper fallback handling
  Widget _buildCachedImage() {
    final fallbackAsset = ImageHelper.getFallbackAsset(
      int.tryParse(item.id) ?? 0,
    );
    
    // If no cover image, use asset
    if (item.coverImage == null || item.coverImage!.isEmpty) {
      return Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }

    // Determine image URL using centralised media resolver
    final imageUrl = ApiService().getMediaUrl(item.coverImage);

    // Use CachedNetworkImage for network images
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // Try fallback asset on error
        return Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder();
          },
        );
      },
      memCacheWidth: 320, // Optimize memory: 2x for retina (160px * 2)
      memCacheHeight: 360, // 2x for retina (180px * 2)
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.music_note,
        color: Colors.grey,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed heights: thumbnail takes ~67% (120px), brown section takes ~33% (60px) of 180px card
    const double cardHeight = 180.0;
    const double thumbnailHeight = 120.0;
    const double brownSectionHeight = 60.0;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: Colors.transparent, // Remove default background
      surfaceTintColor: Colors.transparent, // Remove any tint
      shadowColor: AppColors.warmBrown.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: cardHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thumbnail - Fixed height at top
              SizedBox(
                height: thumbnailHeight,
                width: double.infinity,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    // Image with caching
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: _buildCachedImage(),
                    ),
                      // Play button overlay
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Material(
                          color: Colors.brown,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: onPlay,
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content Info - Fixed height brown section that always fills bottom
              Container(
                height: brownSectionHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textInverse,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Text(
                        item.creator,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textInverse.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

