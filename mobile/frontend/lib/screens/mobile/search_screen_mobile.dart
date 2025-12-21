import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/search_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../models/content_item.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/pill_text_field.dart';
import '../video/video_player_full_screen.dart';
import '../audio/audio_player_full_screen_new.dart';

class SearchScreenMobile extends StatefulWidget {
  const SearchScreenMobile({super.key});

  @override
  State<SearchScreenMobile> createState() => _SearchScreenMobileState();
}

class _SearchScreenMobileState extends State<SearchScreenMobile> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.apps},
    {'label': 'Audio', 'icon': Icons.headphones},
    {'label': 'Video', 'icon': Icons.videocam},
    {'label': 'Movies', 'icon': Icons.movie},
    {'label': 'Music', 'icon': Icons.music_note},
    {'label': 'Animated', 'icon': Icons.animation},
  ];

  @override
  void initState() {
    super.initState();
    // Listen to text changes for search
    _searchController.addListener(_onSearchChanged);
    
    // Load initial content when "All" filter is selected by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleFilterChange('All');
    });
  }

  void _onSearchChanged() {
    // Debounce search - only search after user stops typing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performSearch(_searchController.text);
      }
    });
    setState(() {}); // Update clear button visibility
  }

  void _performSearch(String query) {
    final searchProvider = context.read<SearchProvider>();
    final type = _selectedFilter == 'All' ? null : _selectedFilter.toLowerCase();
    searchProvider.search(query, type: type);
  }

  void _handleFilterChange(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    
    final searchProvider = context.read<SearchProvider>();
    
    if (filter == 'All') {
      if (_searchController.text.isEmpty) {
        // Fetch all content when "All" is selected with no query
        searchProvider.fetchAllByType('all');
      } else {
        // Search with current query across all types
        searchProvider.search(_searchController.text, type: null);
      }
    } else {
      // Fetch all content of the selected type
      final type = filter.toLowerCase();
      if (_searchController.text.isEmpty) {
        // No search query - fetch all content of this type
        searchProvider.fetchAllByType(type);
      } else {
        // Search within this type
        searchProvider.search(_searchController.text, type: type);
      }
    }
  }

  void _handlePlayContent(ContentItem item) {
    if (item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerFullScreen(
            videoId: item.id,
            title: item.title,
            author: item.creator,
            authorId: item.creatorId,
            duration: item.duration?.inSeconds ?? 0,
            gradientColors: const [AppColors.backgroundPrimary, AppColors.backgroundSecondary],
            videoUrl: item.videoUrl!,
            playlist: [],
            initialIndex: 0,
            onBack: () => Navigator.of(context).pop(),
            onFavorite: () {},
            onSeek: null,
          ),
        ),
      );
    } else if (item.audioUrl != null) {
      context.read<AudioPlayerState>().playContent(item);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AudioPlayerFullScreenNew(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Search',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Pill-shaped search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.warmBrown.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search podcasts, music, and more...',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 15,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 12),
                          child: Icon(
                            Icons.search,
                            color: AppColors.warmBrown.withOpacity(0.6),
                            size: 22,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 50,
                          minHeight: 48,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: AppColors.warmBrown.withOpacity(0.6),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  if (_selectedFilter == 'All') {
                                    context.read<SearchProvider>().clearResults();
                                  } else {
                                    // Re-fetch all content of current filter type
                                    context.read<SearchProvider>().fetchAllByType(
                                      _selectedFilter.toLowerCase(),
                                    );
                                  }
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (value) {
                        _performSearch(value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips - Pill-shaped themed design
            Container(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                child: Row(
                  children: _filters.map((filter) {
                    final label = filter['label'] as String;
                    final icon = filter['icon'] as IconData;
                    final isSelected = label == _selectedFilter;
                    return Padding(
                      padding: EdgeInsets.only(right: AppSpacing.small),
                      child: GestureDetector(
                        onTap: () => _handleFilterChange(label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.warmBrown 
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected 
                                  ? AppColors.warmBrown 
                                  : AppColors.warmBrown.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.warmBrown.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isSelected 
                                    ? Colors.white 
                                    : AppColors.warmBrown,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: AppTypography.bodySmall.copyWith(
                                  color: isSelected 
                                      ? Colors.white 
                                      : AppColors.warmBrown,
                                  fontWeight: isSelected 
                                      ? FontWeight.w700 
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Content area
            Expanded(
              child: Consumer<SearchProvider>(
                builder: (context, searchProvider, _) {
                  // Show results if we have any (from search or filter)
                  if (searchProvider.results.isNotEmpty || searchProvider.isLoading) {
                    return _buildSearchResults(searchProvider);
                  }
                  
                  // Show filter-specific empty state
                  if (_selectedFilter != 'All' && !searchProvider.isLoading) {
                    return _buildFilterEmptyState();
                  }
                  
                  // Otherwise show discovery UI - just recent searches
                  return ListView(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    children: [
                      // Recent searches
                      if (searchProvider.recentSearches.isNotEmpty) ...[
                        _buildRecentSearches(searchProvider),
                        const SizedBox(height: AppSpacing.large),
                      ],
                      // Empty state when no recent searches
                      if (searchProvider.recentSearches.isEmpty)
                        _buildSearchEmptyState(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(SearchProvider searchProvider) {
    if (searchProvider.isLoading) {
      return ListView.builder(
        padding: EdgeInsets.all(AppSpacing.medium),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.small),
          child: LoadingShimmer(width: double.infinity, height: 80),
        ),
      );
    }

    if (searchProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorMain.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 40, color: AppColors.errorMain),
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                searchProvider.error!,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _performSearch(_searchController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (searchProvider.results.isEmpty && searchProvider.query != null) {
      return _buildNoResultsState();
    }

    // Show results in a grid for better visual appeal
    return GridView.builder(
      padding: EdgeInsets.all(AppSpacing.medium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: searchProvider.results.length,
      itemBuilder: (context, index) {
        final item = searchProvider.results[index];
        return _buildResultGridCard(item);
      },
    );
  }

  Widget _buildResultGridCard(ContentItem item) {
    final hasVideo = item.videoUrl != null && item.videoUrl!.isNotEmpty;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate thumbnail height based on available width with safe constraints
        final thumbnailHeight = (constraints.maxWidth * 0.75).clamp(80.0, 150.0);
        final infoHeight = constraints.maxHeight - thumbnailHeight;
    
    return Card(
      elevation: 2,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handlePlayContent(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
          children: [
                // Thumbnail - use constrained height instead of AspectRatio
                SizedBox(
                  height: thumbnailHeight,
                  width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.coverImage != null && item.coverImage!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverImage!,
                          fit: BoxFit.cover,
                          memCacheWidth: 300, // Optimized for grid card size
                          memCacheHeight: 300,
                          placeholder: (context, url) => Container(
                            color: AppColors.warmBrown.withOpacity(0.1),
                          ),
                          errorWidget: (context, url, error) => _buildDefaultThumbnail(hasVideo),
                        )
                      : _buildDefaultThumbnail(hasVideo),
                      // Play overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                                Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play button
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                          width: 32,
                          height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        hasVideo ? Icons.play_arrow : Icons.headphones,
                        color: Colors.white,
                            size: 18,
                      ),
                    ),
                  ),
                  // Category badge removed - content type is distinguishable via icon
                    ],
                  ),
              ),
                // Info section - use remaining space with proper constraints
            Expanded(
              child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                            height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                        const SizedBox(height: 3),
                    Text(
                      item.creator,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                            fontSize: 11,
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
        );
      },
    );
  }

  Widget _buildDefaultThumbnail(bool isVideo) {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.2),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam : Icons.music_note,
          color: AppColors.warmBrown,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 40,
              color: AppColors.warmBrown.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmptyState() {
    final filterName = _selectedFilter;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFilterIcon(filterName),
              size: 40,
              color: AppColors.warmBrown.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $filterName content yet',
            style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Audio':
        return Icons.headphones;
      case 'Video':
        return Icons.videocam;
      case 'Movies':
        return Icons.movie;
      case 'Music':
        return Icons.music_note;
      default:
        return Icons.apps;
    }
  }

  Widget _buildRecentSearches(SearchProvider searchProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                searchProvider.clearRecentSearches();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warmBrown,
              ),
              child: Text(
                'Clear',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warmBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: searchProvider.recentSearches.map((search) {
            return GestureDetector(
              onTap: () {
                _searchController.text = search;
                _performSearch(search);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.warmBrown.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: AppColors.warmBrown.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      search,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 50,
              color: AppColors.warmBrown.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search for Content',
            style: AppTypography.heading3.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find podcasts, videos, music and more.\nOr select a category above to browse.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
