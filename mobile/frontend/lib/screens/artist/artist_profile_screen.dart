import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/content_item.dart';
import '../../providers/artist_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../video/video_player_full_screen.dart';
import '../audio/audio_player_full_screen_new.dart';
import 'package:url_launcher/url_launcher.dart';

/// Artist Profile Screen - View any artist's public profile
/// 
/// Displays:
/// - Cover image and artist name
/// - Follower count and verification status
/// - Follow/unfollow button
/// - Bio and social links
/// - Tabbed content (Video and Audio podcasts)
class ArtistProfileScreen extends StatefulWidget {
  final int artistId;

  const ArtistProfileScreen({super.key, required this.artistId});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final provider = context.read<ArtistProvider>();
    await provider.fetchArtist(widget.artistId);
    await provider.fetchArtistPodcasts(widget.artistId);
    
    final artist = provider.getArtist(widget.artistId);
    if (artist != null && mounted) {
      setState(() {
        // Check if current user is following this artist
        // Note: This would need to be fetched from the API if we had an isFollowing field
        _isFollowing = false; // Default to false, will update if API provides this info
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final provider = context.read<ArtistProvider>();
    final success = _isFollowing
        ? await provider.unfollowArtist(widget.artistId)
        : await provider.followArtist(widget.artistId);

    if (success && mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
      });
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open URL')),
        );
      }
    }
  }

  void _handlePlayAudio(ContentItem item) {
    if (item.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio available for ${item.title}')),
      );
      return;
    }
    context.read<AudioPlayerState>().playContent(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AudioPlayerFullScreenNew(),
      ),
    );
  }

  void _handlePlayVideo(ContentItem item) {
    if (item.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No video available for ${item.title}')),
      );
      return;
    }
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Consumer<ArtistProvider>(
        builder: (context, provider, _) {
          final artist = provider.getArtist(widget.artistId);
          final isLoading = provider.isArtistLoading(widget.artistId);
          final error = provider.getArtistError(widget.artistId);

          if (isLoading && artist == null) {
            return _buildLoadingState();
          }

          if (error != null && artist == null) {
            return _buildErrorState(error);
          }

          if (artist == null) {
            return _buildNotFoundState();
          }

          final podcasts = provider.getArtistPodcasts(widget.artistId) ?? [];
          final videoPodcasts = podcasts.where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty).toList();
          final audioPodcasts = podcasts.where((p) => 
            (p.videoUrl == null || p.videoUrl!.isEmpty) && 
            p.audioUrl != null && p.audioUrl!.isNotEmpty
          ).toList();

          return CustomScrollView(
            slivers: [
              // Header with cover image and artist info
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image
                      if (artist.coverImage != null && artist.coverImage!.isNotEmpty)
                        Image.network(
                          artist.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultCover(),
                        )
                      else
                        _buildDefaultCover(),
                      // Gradient overlay
                      Container(
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
                      // Artist info at bottom
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    artist.artistName,
                                    style: AppTypography.heading1.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (artist.isVerified)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.verified,
                                      color: AppColors.accentMain,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${artist.followersCount} followers',
                              style: AppTypography.body.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats, bio, social links, follow button
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Podcasts', podcasts.length.toString()),
                          _buildStat('Total Plays', _formatPlays(artist.totalPlays)),
                          _buildStat('Followers', _formatPlays(artist.followersCount)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large),
                      
                      // Follow button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _toggleFollow,
                          icon: Icon(_isFollowing ? Icons.check : Icons.person_add),
                          label: Text(_isFollowing ? 'Following' : 'Follow'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? AppColors.warmBrown : AppColors.accentMain,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                      
                      // Bio
                      if (artist.bio != null && artist.bio!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.large),
                        Text('About', style: AppTypography.heading3),
                        SizedBox(height: AppSpacing.small),
                        Text(
                          artist.bio!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      
                      // Social links
                      if (artist.socialLinks != null && artist.socialLinks!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.large),
                        Text('Connect', style: AppTypography.heading3),
                        SizedBox(height: AppSpacing.small),
                        Wrap(
                          spacing: 12,
                          children: _buildSocialLinks(artist.socialLinks!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Tabs for content
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.accentMain,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.accentMain,
                    tabs: [
                      Tab(text: 'Video Podcasts (${videoPodcasts.length})'),
                      Tab(text: 'Audio Podcasts (${audioPodcasts.length})'),
                    ],
                  ),
                ),
              ),

              // Tab content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Video podcasts
                    _buildPodcastList(videoPodcasts, isVideo: true),
                    // Audio podcasts
                    _buildPodcastList(audioPodcasts, isVideo: false),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.3),
      child: Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: AppColors.warmBrown,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SafeArea(
      child: Column(
        children: [
          const LoadingShimmer(width: double.infinity, height: 280),
          Padding(
            padding: EdgeInsets.all(AppSpacing.large),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(3, (_) => 
                    LoadingShimmer(width: 80, height: 60)
                  ),
                ),
                SizedBox(height: AppSpacing.large),
                LoadingShimmer(width: 120, height: 40),
                SizedBox(height: AppSpacing.large),
                LoadingShimmer(width: double.infinity, height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading artist',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadArtistData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Artist not found',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.heading2.copyWith(
            color: AppColors.accentMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatPlays(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  List<Widget> _buildSocialLinks(Map<String, String> socialLinks) {
    final List<Widget> links = [];
    
    if (socialLinks.containsKey('instagram') && socialLinks['instagram']!.isNotEmpty) {
      links.add(IconButton(
        icon: const Icon(Icons.camera_alt),
        color: AppColors.accentMain,
        onPressed: () => _launchUrl(socialLinks['instagram']!),
        tooltip: 'Instagram',
      ));
    }
    if (socialLinks.containsKey('twitter') && socialLinks['twitter']!.isNotEmpty) {
      links.add(IconButton(
        icon: const Icon(Icons.chat),
        color: AppColors.accentMain,
        onPressed: () => _launchUrl(socialLinks['twitter']!),
        tooltip: 'Twitter',
      ));
    }
    if (socialLinks.containsKey('youtube') && socialLinks['youtube']!.isNotEmpty) {
      links.add(IconButton(
        icon: const Icon(Icons.play_circle_outline),
        color: AppColors.accentMain,
        onPressed: () => _launchUrl(socialLinks['youtube']!),
        tooltip: 'YouTube',
      ));
    }
    if (socialLinks.containsKey('website') && socialLinks['website']!.isNotEmpty) {
      links.add(IconButton(
        icon: const Icon(Icons.language),
        color: AppColors.accentMain,
        onPressed: () => _launchUrl(socialLinks['website']!),
        tooltip: 'Website',
      ));
    }
    if (socialLinks.containsKey('facebook') && socialLinks['facebook']!.isNotEmpty) {
      links.add(IconButton(
        icon: const Icon(Icons.facebook),
        color: AppColors.accentMain,
        onPressed: () => _launchUrl(socialLinks['facebook']!),
        tooltip: 'Facebook',
      ));
    }

    return links;
  }

  Widget _buildPodcastList(List<ContentItem> podcasts, {required bool isVideo}) {
    if (podcasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_off : Icons.music_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isVideo ? 'video' : 'audio'} podcasts yet',
              style: AppTypography.body.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.medium),
      itemCount: podcasts.length,
      itemBuilder: (context, index) {
        final podcast = podcasts[index];
        return _buildPodcastCard(podcast, isVideo: isVideo);
      },
    );
  }

  Widget _buildPodcastCard(ContentItem podcast, {required bool isVideo}) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.medium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => isVideo ? _handlePlayVideo(podcast) : _handlePlayAudio(podcast),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.medium),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: podcast.coverImage != null && podcast.coverImage!.isNotEmpty
                      ? Image.network(
                          podcast.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultThumbnail(isVideo),
                        )
                      : _buildDefaultThumbnail(isVideo),
                ),
              ),
              SizedBox(width: AppSpacing.medium),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      podcast.category,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${podcast.plays} plays',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (podcast.duration != null) ...[
                          SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatDuration(podcast.duration!),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Play button
              IconButton(
                icon: Icon(
                  isVideo ? Icons.play_circle_filled : Icons.play_arrow,
                  color: AppColors.accentMain,
                  size: 40,
                ),
                onPressed: () => isVideo ? _handlePlayVideo(podcast) : _handlePlayAudio(podcast),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail(bool isVideo) {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.2),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam : Icons.music_note,
          color: AppColors.warmBrown,
          size: 32,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Delegate for the pinned tab bar header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(
          bottom: BorderSide(color: AppColors.borderPrimary),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}

