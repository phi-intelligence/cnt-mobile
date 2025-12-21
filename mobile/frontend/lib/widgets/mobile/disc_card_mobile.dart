import 'package:flutter/material.dart';
import '../../models/content_item.dart';
import '../shared/image_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Disc-style card widget for podcast/music items
/// Shows circular image with label below
class DiscCardMobile extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final double size;

  const DiscCardMobile({
    super.key,
    required this.item,
    this.onTap,
    this.onPlay,
    this.size = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? onPlay,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Disc Image
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  item.coverImage != null
                      ? Image(
                          image: ImageHelper.getImageProvider(
                            item.coverImage,
                            fallbackAsset: ImageHelper.getFallbackAsset(
                              int.tryParse(item.id) ?? 0,
                            ),
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              ImageHelper.getFallbackAsset(
                                int.tryParse(item.id) ?? 0,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : Image.asset(
                          ImageHelper.getFallbackAsset(
                            int.tryParse(item.id) ?? 0,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white70,
                                size: 32,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Label below disc
          SizedBox(
            width: size + 20, // Slightly wider than disc for text overflow
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Optional: Creator name (smaller text)
          if (item.creator.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: size + 20,
              child: Text(
                item.creator,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

