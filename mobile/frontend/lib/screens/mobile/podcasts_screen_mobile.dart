import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../services/api_service.dart';
import '../../models/api_models.dart';
import '../../models/content_item.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/content_section.dart';

class PodcastsScreenMobile extends StatefulWidget {
  const PodcastsScreenMobile({super.key});

  @override
  State<PodcastsScreenMobile> createState() => _PodcastsScreenMobileState();
}

class _PodcastsScreenMobileState extends State<PodcastsScreenMobile> {
  final ApiService _api = ApiService();
  List<ContentItem> _podcasts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPodcasts();
  }

  Future<void> _fetchPodcasts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final podcastsData = await _api.getPodcasts();
      
      _podcasts = podcastsData.map((podcast) {
        final audioUrl = podcast.audioUrl != null && podcast.audioUrl!.isNotEmpty
            ? _api.getMediaUrl(podcast.audioUrl!)
            : null;
        
        return ContentItem(
          id: podcast.id.toString(),
          title: podcast.title,
          creator: 'Christ Tabernacle',
          description: podcast.description,
          coverImage: podcast.coverImage != null 
            ? _api.getMediaUrl(podcast.coverImage!) 
            : null,
          audioUrl: audioUrl,
          videoUrl: null,
          duration: podcast.duration != null 
            ? Duration(seconds: podcast.duration!)
            : null,
          category: _getCategoryName(podcast.categoryId),
          plays: podcast.playsCount,
          createdAt: podcast.createdAt,
        );
      }).where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty).toList();
    } catch (e) {
      print('Error fetching podcasts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryName(int? categoryId) {
    switch (categoryId) {
      case 1: return 'Sermons';
      case 2: return 'Bible Study';
      case 3: return 'Devotionals';
      case 4: return 'Prayer';
      case 5: return 'Worship';
      case 6: return 'Gospel';
      default: return 'Podcast';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text('Podcasts'),
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return GridView.builder(
              padding: EdgeInsets.all(AppSpacing.medium),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: AppSpacing.medium,
                mainAxisSpacing: AppSpacing.medium,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return const LoadingShimmer(width: double.infinity, height: 200);
              },
            );
          }

          return Column(
            children: [
              // Search and filters
              Padding(
                padding: EdgeInsets.all(AppSpacing.medium),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search podcasts...',
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

              // Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                child: Row(
                  children: ['All', 'Sermons', 'Teaching', 'Prayer', 'Worship', 'Testimony', 'Bible Study']
                      .map((category) {
                    return Padding(
                      padding: EdgeInsets.only(right: AppSpacing.small),
                      child: FilterChip(
                        label: Text(category),
                        onSelected: (selected) {},
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.medium),

              // Podcasts Grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: AppSpacing.medium,
                    mainAxisSpacing: AppSpacing.medium,
                  ),
                  itemCount: _podcasts.length,
                  itemBuilder: (context, index) {
                    final podcast = _podcasts[index];
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
                                  Icons.headphones,
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
                                  podcast.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  podcast.creator ?? 'Christ Tabernacle',
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
