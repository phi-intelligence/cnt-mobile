import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/content_item.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../widgets/shared/content_section.dart';
import 'video/video_player_full_screen.dart';
import '../utils/app_logger.dart';

/// Movie Detail Screen - Full movie information with play option
class MovieDetailScreen extends StatefulWidget {
  final ContentItem? item; // Pre-loaded content item
  final int? movieId; // Movie ID to fetch

  const MovieDetailScreen({
    super.key,
    this.item,
    this.movieId,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final ApiService _apiService = ApiService();
  ContentItem? _item;
  List<ContentItem> _similarItems = [];
  bool _isLoading = true;
  bool _isLoadingSimilar = false;
  
  // Video preview
  VideoPlayerController? _previewController;
  bool _isPreviewLoading = false;
  bool _hasPreviewError = false;
  Timer? _previewLoopTimer;

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _previewLoopTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePreview(String videoUrl) async {
    try {
      setState(() {
        _isPreviewLoading = true;
        _hasPreviewError = false;
      });

      _previewController?.dispose();
      
      _previewController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await _previewController!.initialize();
      await _previewController!.setVolume(0.0);
      await _previewController!.setLooping(true);
      await _previewController!.seekTo(Duration.zero);
      await _previewController!.play();

      // Reset preview every 60 seconds to show beginning
      _previewLoopTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        if (_previewController != null && _previewController!.value.isInitialized) {
          _previewController!.seekTo(Duration.zero);
        }
      });

      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('Error initializing preview: $e');
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
          _hasPreviewError = true;
        });
      }
    }
  }

  Future<void> _loadMovie() async {
    try {
      setState(() {
        _isLoading = true;
      });

      ContentItem? item;

      if (widget.item != null) {
        item = widget.item;
      } else if (widget.movieId != null) {
        // Fetch movie from API
        final movie = await _apiService.getMovie(widget.movieId!);
        item = _apiService.movieToContentItem(movie);
      }

      if (item != null) {
        setState(() {
          _item = item;
          _isLoading = false;
        });

        // Load similar movies
        if (widget.movieId != null) {
          _loadSimilarMovies(widget.movieId!);
        }
        
        // Initialize video preview
        if (item.videoUrl != null && item.videoUrl!.isNotEmpty) {
          _initializePreview(item.videoUrl!);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('Error loading movie: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSimilarMovies(int movieId) async {
    try {
      setState(() {
        _isLoadingSimilar = true;
      });

      final similarMovies = await _apiService.getSimilarMovies(movieId, limit: 10);
      final similarItems = similarMovies.map((movie) {
        return _apiService.movieToContentItem(movie);
      }).toList().cast<ContentItem>();

      setState(() {
        _similarItems = similarItems;
        _isLoadingSimilar = false;
      });
    } catch (e) {
      AppLogger.debug('Error loading similar movies: $e');
      setState(() {
        _isLoadingSimilar = false;
      });
    }
  }

  void _handlePlay() {
    // Pause preview when going to full player
    _previewController?.pause();
    
    if (_item?.videoUrl != null && _item!.videoUrl!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerFullScreen(
            videoId: _item!.id,
            title: _item!.title,
            author: _item!.creator,
            authorId: _item!.creatorId,
            duration: _item!.duration?.inSeconds ?? 0,
            gradientColors: const [AppColors.backgroundPrimary, AppColors.backgroundSecondary],
            videoUrl: _item!.videoUrl!,
            playlist: _similarItems.isNotEmpty ? [_item!, ..._similarItems] : [_item!],
            initialIndex: 0,
            onBack: () {
              Navigator.of(context).pop();
              // Resume preview when returning
              _previewController?.play();
            },
            onFavorite: _handleFavorite,
            onSeek: null,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not available')),
      );
    }
  }

  Future<void> _handleFavorite() async {
    if (_item == null) return;

    try {
      final favoritesProvider = context.read<FavoritesProvider>();
      final success = await favoritesProvider.toggleFavorite(_item!);

      if (mounted && success) {
        setState(() {
          _item = _item!.copyWith(
            isFavorite: !_item!.isFavorite,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _item!.isFavorite
                  ? '${_item!.title} added to favorites'
                  : '${_item!.title} removed from favorites',
            ),
            backgroundColor: AppColors.successMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorites'),
            backgroundColor: AppColors.errorMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  Widget _buildHeroBackground(ContentItem item) {
    if (_previewController != null && 
        _previewController!.value.isInitialized && 
        !_hasPreviewError) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _previewController!.value.size.width,
            height: _previewController!.value.size.height,
            child: VideoPlayer(_previewController!),
          ),
        ),
      );
    } else if (item.coverImage != null && item.coverImage!.isNotEmpty) {
      return Image.network(
        _apiService.getMediaUrl(item.coverImage!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderBackground();
        },
      );
    }
    return _buildPlaceholderBackground();
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.3),
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white24, size: 100),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Movie not found'),
        ),
      );
    }

    final item = _item!;
    final screenWidth = MediaQuery.of(context).size.width;
    final coverImageHeight = screenWidth * 0.75; // 75% of screen width

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: coverImageHeight,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                onPressed: _handleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Video Preview or Cover Image
                  _buildHeroBackground(item),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Play indicator overlay
                  if (_previewController != null && 
                      _previewController!.value.isInitialized && 
                      !_hasPreviewError)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_off, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Preview',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.foregroundPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),

                  // Metadata Row
                  Wrap(
                    spacing: AppSpacing.medium,
                    runSpacing: AppSpacing.small,
                    children: [
                      // Rating
                      if (item.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.interactive,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: AppTypography.body.copyWith(
                                color: AppColors.foregroundPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                      // Release Date
                      if (item.releaseDate != null)
                        Text(
                          '${item.releaseDate!.year}',
                          style: AppTypography.body.copyWith(
                            color: AppColors.foregroundSecondary,
                          ),
                        ),

                      // Duration
                      if (item.duration != null)
                        Text(
                          _formatDuration(item.duration!),
                          style: AppTypography.body.copyWith(
                            color: AppColors.foregroundSecondary,
                          ),
                        ),

                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryMain.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          item.category,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.large),

                  // Director and Cast
                  if (item.director != null || item.cast != null) ...[
                    if (item.director != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Director: ',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.foregroundSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.director!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.foregroundPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),
                    ],
                    if (item.cast != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cast: ',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.foregroundSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.cast!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.foregroundPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large),
                    ],
                  ],

                  // Description
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    Text(
                      'Description',
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.foregroundPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      item.description!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.foregroundSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.large),
                  ],

                  // Play Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handlePlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_arrow, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Play Movie',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.add,
                        label: 'Add to List',
                        onTap: () {
                          // TODO: Implement add to list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Playlist feature coming soon'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _buildActionButton(
                        icon: item.isFavorite ? Icons.favorite : Icons.favorite_border,
                        label: 'Favorite',
                        onTap: _handleFavorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.extraLarge),

                  // Similar Content Section
                  if (_similarItems.isNotEmpty) ...[
                    Text(
                      'Similar Content',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.foregroundPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    ContentSection(
                      title: '',
                      items: _similarItems,
                      isHorizontal: true,
                      onItemTap: (similarItem) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailScreen(
                              item: similarItem,
                              movieId: int.tryParse(similarItem.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ] else if (_isLoadingSimilar) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.large),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.primaryMain,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.foregroundSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

