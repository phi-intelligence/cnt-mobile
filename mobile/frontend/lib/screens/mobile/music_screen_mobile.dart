import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/music_provider.dart';
import '../../widgets/shared/loading_shimmer.dart';

class MusicScreenMobile extends StatefulWidget {
  const MusicScreenMobile({super.key});

  @override
  State<MusicScreenMobile> createState() => _MusicScreenMobileState();
}

class _MusicScreenMobileState extends State<MusicScreenMobile> {
  String _selectedGenre = 'All';
  String _selectedSort = 'Latest';
  final List<String> _genres = ['All', 'Worship', 'Gospel', 'Contemporary', 'Hymns', 'Choir', 'Instrumental'];
  final List<String> _sortOptions = ['Latest', 'Popular', 'A-Z'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text('Music'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedSort = value;
              });
            },
            itemBuilder: (context) {
              return _sortOptions.map((option) {
                return PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      if (_selectedSort == option)
                        const Icon(Icons.check, color: AppColors.primaryMain, size: 20)
                      else
                        const SizedBox(width: 20),
                      Text(option),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(AppSpacing.medium),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search music...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
              ),
            ),
          ),

          // Genre Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Row(
              children: _genres.map((genre) {
                final isSelected = genre == _selectedGenre;
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.small),
                  child: FilterChip(
                    label: Text(genre),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedGenre = genre;
                      });
                    },
                    selectedColor: AppColors.primaryMain,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.medium),

          // Music Grid
          Expanded(
            child: Consumer<MusicProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return GridView.builder(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: AppSpacing.medium,
                      mainAxisSpacing: AppSpacing.medium,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const LoadingShimmer(width: double.infinity, height: 250);
                    },
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: AppSpacing.medium,
                    mainAxisSpacing: AppSpacing.medium,
                  ),
                  itemCount: provider.tracks.length,
                  itemBuilder: (context, index) {
                    final track = provider.tracks[index];
                    return Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.music_note,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(AppSpacing.small),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track.creator,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
