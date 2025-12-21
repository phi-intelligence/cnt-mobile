import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../models/content_item.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/mobile/content_card_mobile.dart';

/// Mobile Favorites Screen - Shows user's favorited content
class FavoritesScreenMobile extends StatefulWidget {
  const FavoritesScreenMobile({super.key});

  @override
  State<FavoritesScreenMobile> createState() => _FavoritesScreenMobileState();
}

class _FavoritesScreenMobileState extends State<FavoritesScreenMobile> {
  final TextEditingController _searchController = TextEditingController();
  List<ContentItem> _filteredFavorites = [];
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Audio', 'Video'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritesProvider>().fetchFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFavorites(List<ContentItem> favorites) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFavorites = favorites.where((item) {
        final matchesQuery = query.isEmpty ||
            item.title.toLowerCase().contains(query) ||
            item.creator.toLowerCase().contains(query);
        
        final matchesFilter = _selectedFilter == 'All' ||
            (_selectedFilter == 'Audio' && item.audioUrl != null && item.videoUrl == null) ||
            (_selectedFilter == 'Video' && item.videoUrl != null);
        
        return matchesQuery && matchesFilter;
      }).toList();
    });
  }

  void _handlePlay(ContentItem item) {
    context.read<AudioPlayerState>().playContent(item);
  }

  void _handleRemoveFavorite(ContentItem item) async {
    final provider = context.read<FavoritesProvider>();
    final success = await provider.toggleFavorite(item);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${item.title}" from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'My Favorites',
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search favorites...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                  ),
                  onChanged: (_) {
                    final provider = context.read<FavoritesProvider>();
                    _filterFavorites(provider.favorites);
                  },
                ),
                const SizedBox(height: AppSpacing.small),
                
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = filter == _selectedFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.small),
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: AppTypography.bodySmall.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                            final provider = context.read<FavoritesProvider>();
                            _filterFavorites(provider.favorites);
                          },
                          selectedColor: AppColors.primaryMain,
                          backgroundColor: AppColors.backgroundSecondary,
                          checkmarkColor: Colors.white,
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Favorites List
          Expanded(
            child: Consumer<FavoritesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.small),
                        child: LoadingShimmer(width: double.infinity, height: 80),
                      );
                    },
                  );
                }

                if (provider.favorites.isEmpty) {
                  return const EmptyState(
                    icon: Icons.favorite_border,
                    title: 'No Favorites Yet',
                    message: 'Tap the heart icon on any content to add it to your favorites',
                  );
                }

                final favoritesToShow = _searchController.text.isEmpty && _selectedFilter == 'All'
                    ? provider.favorites
                    : _filteredFavorites.isEmpty && _searchController.text.isEmpty
                        ? provider.favorites.where((item) {
                            return _selectedFilter == 'All' ||
                                (_selectedFilter == 'Audio' && item.audioUrl != null && item.videoUrl == null) ||
                                (_selectedFilter == 'Video' && item.videoUrl != null);
                          }).toList()
                        : _filteredFavorites;

                if (favoritesToShow.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No Results',
                    message: 'No favorites match your search',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                  itemCount: favoritesToShow.length,
                  itemBuilder: (context, index) {
                    final item = favoritesToShow[index];
                    return _buildFavoriteItem(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(ContentItem item) {
    final isVideo = item.videoUrl != null && item.videoUrl!.isNotEmpty;
    
    return Dismissible(
      key: Key(item.id),
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
      onDismissed: (_) => _handleRemoveFavorite(item),
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
              child: item.coverImage != null
                  ? Image.network(
                      item.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        isVideo ? Icons.videocam : Icons.music_note,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Icon(
                      isVideo ? Icons.videocam : Icons.music_note,
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          title: Text(
            item.title,
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
                item.creator,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVideo 
                          ? AppColors.accentMain.withOpacity(0.2)
                          : AppColors.primaryMain.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVideo ? 'Video' : 'Audio',
                      style: AppTypography.caption.copyWith(
                        color: isVideo ? AppColors.accentMain : AppColors.primaryMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.duration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(item.duration!),
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
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _handleRemoveFavorite(item),
              ),
              IconButton(
                icon: Icon(
                  isVideo ? Icons.play_circle_filled : Icons.play_arrow,
                  color: AppColors.primaryMain,
                ),
                onPressed: () => _handlePlay(item),
              ),
            ],
          ),
          onTap: () => _handlePlay(item),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
