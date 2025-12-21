import 'package:flutter/material.dart';
import '../../models/content_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../mobile/content_card_mobile.dart';
import '../mobile/horizontal_content_card_mobile.dart';
import '../mobile/disc_card_mobile.dart';

/// Content Section widget for displaying lists of content items
/// Mobile-only implementation
class ContentSection extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final VoidCallback? onViewAll;
  final bool isHorizontal;
  final bool useDiscDesign;
  final Function(ContentItem)? onItemTap;
  final Function(ContentItem)? onItemPlay;

  const ContentSection({
    super.key,
    required this.title,
    required this.items,
    this.onViewAll,
    this.isHorizontal = false,
    this.useDiscDesign = false,
    this.onItemTap,
    this.onItemPlay,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (useDiscDesign) {
      return _buildDiscDesignMobile(context);
    } else if (isHorizontal) {
      return _buildHorizontalMobile(context);
    } else {
      return _buildVerticalMobile(context);
    }
  }

  Widget _buildHorizontalMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 185, // Matches card height (180px) + small padding
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Stop horizontal scroll notifications from propagating to parent
              // This prevents them from affecting the hero carousel
              if (notification is ScrollUpdateNotification || 
                  notification is ScrollStartNotification ||
                  notification is ScrollEndNotification) {
                // Only stop if it's a horizontal scroll
                if (notification.metrics.axis == Axis.horizontal) {
                  return true; // Stop propagation
                }
              }
              return false;
            },
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              cacheExtent: 500.0, // Pre-render items 500px outside viewport
              addAutomaticKeepAlives: false, // Don't keep off-screen items alive
              addRepaintBoundaries: true, // Isolate repaints per item
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SizedBox(
                    width: 160,
                    height: 180, // Matches HorizontalContentCardMobile cardHeight
                    child: HorizontalContentCardMobile(
                      item: items[index],
                      onTap: onItemTap != null ? () => onItemTap!(items[index]) : null,
                      onPlay: onItemPlay != null ? () => onItemPlay!(items[index]) : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Use ListView.builder instead of items.map() for lazy loading
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          cacheExtent: 500.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ContentCardMobile(
                item: items[index],
                onTap: onItemTap != null ? () => onItemTap!(items[index]) : null,
                onPlay: onItemPlay != null ? () => onItemPlay!(items[index]) : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDiscDesignMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170, // Height to accommodate disc + label
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Stop horizontal scroll notifications from propagating to parent
              // This prevents them from affecting the hero carousel
              if (notification is ScrollUpdateNotification || 
                  notification is ScrollStartNotification ||
                  notification is ScrollEndNotification) {
                // Only stop if it's a horizontal scroll
                if (notification.metrics.axis == Axis.horizontal) {
                  return true; // Stop propagation
                }
              }
              return false;
            },
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              cacheExtent: 500.0, // Pre-render items 500px outside viewport
              addAutomaticKeepAlives: false, // Don't keep off-screen items alive
              addRepaintBoundaries: true, // Isolate repaints per item
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: DiscCardMobile(
                    item: items[index],
                    onTap: onItemTap != null ? () => onItemTap!(items[index]) : null,
                    onPlay: onItemPlay != null ? () => onItemPlay!(items[index]) : null,
                    size: 120.0,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
