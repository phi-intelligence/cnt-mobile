import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../theme/app_typography.dart';
import '../utils/app_logger.dart';

/// Hero Carousel Widget - Image carousel with latest community posts
/// Auto-scrolling carousel displaying images from community posts
class HeroCarouselWidget extends StatefulWidget {
  final Function(int postId)? onItemTap; // Callback when item is tapped (receives postId)
  final double? height; // Optional custom height
  /// Whether to show the title/text overlay on top of the images.
  /// Mobile home hides titles; web-style layouts can enable them.
  final bool showTitleOverlay;
  /// Whether the carousel should auto-scroll between items.
  /// Home screen can disable this while the user scrolls content.
  final bool autoScrollEnabled;

  const HeroCarouselWidget({
    super.key,
    this.onItemTap,
    this.height,
    this.showTitleOverlay = true,
    this.autoScrollEnabled = true,
  });

  @override
  State<HeroCarouselWidget> createState() => _HeroCarouselWidgetState();
}

/// Simple carousel item model for community posts
class _CarouselItem {
  final String id;
  final String imageUrl;
  final String? title;
  final int postId; // For navigation

  _CarouselItem({
    required this.id,
    required this.imageUrl,
    this.title,
    required this.postId,
  });
}

class _HeroCarouselWidgetState extends State<HeroCarouselWidget>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<_CarouselItem> _items = [];
  bool _isLoading = true;
  Timer? _autoScrollTimer;
  bool _isUserInteracting = false;

  // Keep this widget alive to prevent state loss when parent scrolls
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant HeroCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoScrollEnabled != widget.autoScrollEnabled) {
      if (widget.autoScrollEnabled) {
        if (_items.isNotEmpty) {
          _startAutoScroll();
        }
      } else {
        _stopAutoScroll();
      }
    }
  }

  Future<void> _loadItems() async {
    try {
      AppLogger.debug('🖼️ Hero Carousel: Fetching approved community posts with images...');
      final apiService = ApiService();
      
      // Fetch latest approved community posts (backend filters by approved_only=true and image_url)
      final posts = await apiService.getCommunityPosts(
        limit: 20,
        approvedOnly: true,  // Only show approved posts
      );
      AppLogger.debug('🖼️ Hero Carousel: Fetched ${posts.length} approved community posts');
      
      // Convert posts to carousel items (backend already filters by image_url)
      final items = <_CarouselItem>[];
      for (final post in posts) {
        final imageUrl = post['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Get full media URL (handles both regular images and generated quote images)
          final fullImageUrl = apiService.getMediaUrl(imageUrl);
          AppLogger.debug('🖼️ Hero Carousel: Post ${post['id']} - Original: $imageUrl, Full URL: $fullImageUrl');
          
          items.add(_CarouselItem(
            id: post['id'].toString(),
            imageUrl: fullImageUrl,
            title: post['title'] as String?,
            postId: post['id'] as int,
          ));
          
          // Limit to 10-12 items for carousel
          if (items.length >= 12) break;
        }
      }
      
      AppLogger.debug('🖼️ Hero Carousel: Found ${items.length} approved posts with images');
      
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _currentIndex = 0;
        });
        
        // Start auto-scroll if we have items
        if (_items.isNotEmpty && widget.autoScrollEnabled) {
          _startAutoScroll();
        }
      }
    } catch (e, stackTrace) {
      AppLogger.debug('❌ Hero Carousel: Error loading items: $e');
      AppLogger.debug('❌ Hero Carousel: Stack trace: $stackTrace');
      if (e.toString().contains('TimeoutException')) {
        AppLogger.debug('⚠️  Connection timeout! Make sure:');
        AppLogger.debug('   1. Backend is running on port 8002');
        AppLogger.debug('   2. For physical devices, use: --dart-define=API_BASE=http://192.168.0.14:8002/api/v1');
        AppLogger.debug('   3. Device and computer are on the same network');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoScroll() {
    if (!widget.autoScrollEnabled) return;
    _stopAutoScroll();
    
    // Auto-scroll timer - advance to next image every 5 seconds
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isUserInteracting && mounted && _items.isNotEmpty) {
        _goToNext();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _goToNext() {
    if (_items.isEmpty) return;
    
    final nextIndex = (_currentIndex + 1) % _items.length;
    _changePage(nextIndex);
  }

  void _goToPrevious() {
    if (_items.isEmpty) return;
    
    final prevIndex = (_currentIndex - 1 + _items.length) % _items.length;
    _changePage(prevIndex);
  }

  void _changePage(int index) {
    if (index < 0 || index >= _items.length) return;
    
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    
    // Restart auto-scroll if not user interacting
    if (!_isUserInteracting) {
      _startAutoScroll();
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    _changePage(index);
  }

  void _onTap() {
    if (_currentIndex < _items.length && widget.onItemTap != null) {
      widget.onItemTap!(_items[_currentIndex].postId);
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Required for AutomaticKeepAliveClientMixin
    super.build(context);
    
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = PlatformHelper.isWebPlatform();
    
    // Calculate height (mobile: 20% of screen, web: 30%)
    final carouselHeight = widget.height ?? 
        (isWeb ? screenHeight * 0.3 : screenHeight * 0.2);
    
    if (_isLoading) {
      return Container(
        height: carouselHeight,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    
    if (_items.isEmpty) {
      return Container(
        height: carouselHeight,
        color: Colors.black,
        child: const Center(
          child: Text(
            'No posts with images available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: carouselHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Image Carousel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: carouselHeight,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _isUserInteracting = true;
                  _stopAutoScroll();
                } else if (notification is ScrollEndNotification) {
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      _isUserInteracting = false;
                      _startAutoScroll();
                    }
                  });
                }
                return false;
              },
              child: GestureDetector(
                onPanDown: (_) {
                  _isUserInteracting = true;
                  _stopAutoScroll();
                },
                onPanEnd: (_) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _isUserInteracting = false;
                      _startAutoScroll();
                    }
                  });
                },
                child: SizedBox(
                  height: carouselHeight,
                  // Wrap PageView in NotificationListener to stop ALL scroll events
                  // This prevents external scrolling (e.g., audio podcasts section) from affecting carousel
                  // Since PageView has NeverScrollableScrollPhysics(), it won't generate scroll notifications
                  // So we can safely stop ALL scroll notifications to ensure complete isolation
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Stop ALL scroll notifications regardless of depth or source
                      // The PageView only changes via _pageController.animateToPage() from the timer
                      return true; // Stop all scroll notifications
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const NeverScrollableScrollPhysics(), // Disable all manual scrolling - only auto-scroll via timer
                      scrollDirection: Axis.horizontal,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        // Wrap each item with GestureDetector for tap handling
                        return GestureDetector(
                          onTap: () {
                            if (widget.onItemTap != null && index < _items.length) {
                              widget.onItemTap!(_items[index].postId);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _buildCarouselItem(index, carouselHeight),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Gradient Overlay (bottom)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: carouselHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: carouselHeight * 0.3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Title overlay (optional)
          if (widget.showTitleOverlay &&
              _currentIndex < _items.length &&
              _items[_currentIndex].title != null &&
              _items[_currentIndex].title!.isNotEmpty)
            Positioned(
              top: carouselHeight - 100,
              left: 16,
              right: 16,
              child: _buildContentOverlay(_items[_currentIndex]),
            ),
          
          // Carousel Indicators
          Positioned(
            top: carouselHeight - 16,
            left: 0,
            right: 0,
            child: _buildIndicators(),
          ),
          
          // Navigation Arrows (optional, for web)
          if (isWeb && _items.length > 1)
            ..._buildNavigationArrows(carouselHeight),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(int index, double height) {
    if (index >= _items.length) return const SizedBox();
    
    final item = _items[index];
    final isWeb = PlatformHelper.isWebPlatform();
    
    // Build cached image widget with error handling
    // Use CachedNetworkImage to prevent reloading on PageView rebuilds
    Widget content = Builder(
      builder: (context) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final screenWidth = MediaQuery.of(context).size.width;
        
        return CachedNetworkImage(
          imageUrl: item.imageUrl,
          fit: BoxFit.cover,
          height: height,
          width: double.infinity,
          memCacheWidth: (screenWidth * devicePixelRatio).round(),
          memCacheHeight: (height * devicePixelRatio).round(),
          placeholder: (context, url) => Container(
            height: height,
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            AppLogger.debug('❌ Hero Carousel: Error loading image ${item.imageUrl}: $error');
            return Container(
              height: height,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_not_supported, color: Colors.white70, size: 64),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      item.imageUrl,
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    
    // For web, wrap content in InkWell for better tap detection
    if (isWeb && widget.onItemTap != null) {
      return InkWell(
        onTap: () {
          if (index == _currentIndex && widget.onItemTap != null) {
            widget.onItemTap!(_items[index].postId);
          }
        },
        child: content,
      );
    }
    
    return content;
  }

  /// Build text/content overlay for the current carousel item
  Widget _buildContentOverlay(_CarouselItem item) {
    if (item.title == null || item.title!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title!,
          style: AppTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: const [
              Shadow(
                blurRadius: 6,
                color: Colors.black87,
                offset: Offset(0, 2),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildIndicators() {
    if (_items.length <= 1) return const SizedBox();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_items.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentIndex == index 
                ? Colors.white 
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  List<Widget> _buildNavigationArrows(double height) {
    return [
      // Left Arrow
      Positioned(
        left: 16,
        top: height / 2 - 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _goToPrevious,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
      // Right Arrow
      Positioned(
        right: 16,
        top: height / 2 - 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _goToNext,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    ];
  }
}
