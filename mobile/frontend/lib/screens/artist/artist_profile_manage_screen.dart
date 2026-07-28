import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/artist_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../models/content_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../video/video_player_full_screen.dart';
import '../audio/audio_player_full_screen_new.dart';

/// Artist Profile Manage Screen - For content creators to manage their own profile
/// 
/// Features:
/// - Edit artist name and bio
/// - Upload cover image
/// - Manage social links
/// - View own content
class ArtistProfileManageScreen extends StatefulWidget {
  const ArtistProfileManageScreen({super.key});

  @override
  State<ArtistProfileManageScreen> createState() => _ArtistProfileManageScreenState();
}

class _ArtistProfileManageScreenState extends State<ArtistProfileManageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _facebookController = TextEditingController();
  final _websiteController = TextEditingController();
  
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingCover = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyArtist();
  }

  Future<void> _loadMyArtist() async {
    final provider = context.read<ArtistProvider>();
    await provider.fetchMyArtist();
    _populateFields();
    
    // Also load podcasts for the current user's artist using artist ID
    if (provider.myArtist != null) {
      await provider.fetchArtistPodcasts(provider.myArtist!.id);
    }
  }

  void _populateFields() {
    final artist = context.read<ArtistProvider>().myArtist;
    if (artist != null) {
      _nameController.text = artist.artistName;
      _bioController.text = artist.bio ?? '';
      if (artist.socialLinks != null) {
        _instagramController.text = artist.socialLinks!['instagram'] ?? '';
        _twitterController.text = artist.socialLinks!['twitter'] ?? '';
        _youtubeController.text = artist.socialLinks!['youtube'] ?? '';
        _facebookController.text = artist.socialLinks!['facebook'] ?? '';
        _websiteController.text = artist.socialLinks!['website'] ?? '';
      }
    }
  }

  Future<void> _handleUploadCover() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image == null) return;

      setState(() {
        _isUploadingCover = true;
      });

      final provider = context.read<ArtistProvider>();
      List<int>? bytes;
      String? filePath;

      if (kIsWeb) {
        bytes = await image.readAsBytes();
      } else {
        filePath = image.path;
      }

      final success = await provider.uploadCoverImage(
        fileName: image.name,
        bytes: bytes,
        filePath: filePath,
      );

      if (mounted) {
        setState(() {
          _isUploadingCover = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover image updated!'),
              backgroundColor: AppColors.successMain,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload cover image'),
              backgroundColor: AppColors.errorMain,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final provider = context.read<ArtistProvider>();
    final socialLinks = <String, String>{};
    
    if (_instagramController.text.isNotEmpty) {
      socialLinks['instagram'] = _instagramController.text.trim();
    }
    if (_twitterController.text.isNotEmpty) {
      socialLinks['twitter'] = _twitterController.text.trim();
    }
    if (_youtubeController.text.isNotEmpty) {
      socialLinks['youtube'] = _youtubeController.text.trim();
    }
    if (_facebookController.text.isNotEmpty) {
      socialLinks['facebook'] = _facebookController.text.trim();
    }
    if (_websiteController.text.isNotEmpty) {
      socialLinks['website'] = _websiteController.text.trim();
    }

    final success = await provider.updateArtist(
      artistName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      socialLinks: socialLinks.isNotEmpty ? socialLinks : null,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated!' : 'Failed to update profile'),
          backgroundColor: success ? AppColors.successMain : AppColors.errorMain,
        ),
      );
    }
  }

  void _handlePlayAudio(ContentItem item) {
    if (item.audioUrl == null) return;
    context.read<AudioPlayerState>().playContent(item);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AudioPlayerFullScreenNew(),
      ),
    );
  }

  void _handlePlayVideo(ContentItem item) {
    if (item.videoUrl == null) return;
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
    _nameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'My Artist Profile',
          style: AppTypography.heading3,
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else ...[
            TextButton(
              onPressed: _isSaving ? null : () {
                setState(() => _isEditing = false);
                _populateFields(); // Reset to original values
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ],
      ),
      body: Consumer<ArtistProvider>(
        builder: (context, provider, _) {
          final artist = provider.myArtist;
          final isLoading = provider.myArtistLoading;
          final error = provider.myArtistError;

          if (isLoading && artist == null) {
            return _buildLoadingState();
          }

          if (error != null && artist == null) {
            return _buildErrorState(error);
          }

          if (artist == null) {
            return _buildNoProfileState();
          }

          final podcasts = provider.getArtistPodcasts(artist.id) ?? [];
          final videoPodcasts = podcasts.where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty).toList();
          final audioPodcasts = podcasts.where((p) => 
            (p.videoUrl == null || p.videoUrl!.isEmpty) && 
            p.audioUrl != null && p.audioUrl!.isNotEmpty
          ).toList();

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // Cover image section
              SliverToBoxAdapter(
                child: _buildCoverSection(artist),
              ),
              // Profile info / Edit form
              SliverToBoxAdapter(
                child: _isEditing
                    ? _buildEditForm()
                    : _buildProfileInfo(artist),
              ),
              // Tab bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Videos (${videoPodcasts.length})'),
                      Tab(text: 'Audio (${audioPodcasts.length})'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildContentList(videoPodcasts, isVideo: true),
                _buildContentList(audioPodcasts, isVideo: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverSection(artist) {
    return Stack(
      children: [
        // Cover image
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.warmBrown.withOpacity(0.3),
          ),
          child: artist.coverImage != null && artist.coverImage!.isNotEmpty
              ? Image.network(
                  artist.coverImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultCover(),
                )
              : _buildDefaultCover(),
        ),
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),
        // Edit cover button
        Positioned(
          bottom: 12,
          right: 12,
          child: ElevatedButton.icon(
            onPressed: _isUploadingCover ? null : _handleUploadCover,
            icon: _isUploadingCover
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt, size: 18),
            label: Text(_isUploadingCover ? 'Uploading...' : 'Change Cover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        // Artist name and verified badge
        Positioned(
          bottom: 12,
          left: 16,
          child: Row(
            children: [
              Text(
                artist.artistName,
                style: AppTypography.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (artist.isVerified)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.verified, color: AppColors.accentMain, size: 24),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.3),
      child: Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: AppColors.warmBrown,
        ),
      ),
    );
  }

  Widget _buildProfileInfo(artist) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Followers', artist.followersCount.toString()),
              _buildStat('Total Plays', artist.totalPlays.toString()),
            ],
          ),
          
          // Bio
          if (artist.bio != null && artist.bio!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.large),
            Text('About', style: AppTypography.heading4),
            SizedBox(height: AppSpacing.small),
            Text(
              artist.bio!,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          
          // Social links
          if (artist.socialLinks != null && artist.socialLinks!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.large),
            Text('Social Links', style: AppTypography.heading4),
            SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildSocialChips(artist.socialLinks!),
            ),
          ],
          
          SizedBox(height: AppSpacing.medium),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.large),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artist Name
            Text('Artist Name', style: AppTypography.heading4),
            SizedBox(height: AppSpacing.small),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your artist name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Artist name is required';
                }
                return null;
              },
            ),
            
            SizedBox(height: AppSpacing.large),
            
            // Bio
            Text('Bio', style: AppTypography.heading4),
            SizedBox(height: AppSpacing.small),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell your audience about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            SizedBox(height: AppSpacing.large),
            
            // Social Links
            Text('Social Links', style: AppTypography.heading4),
            SizedBox(height: AppSpacing.small),
            
            _buildSocialInput(
              controller: _instagramController,
              icon: Icons.camera_alt,
              label: 'Instagram URL',
            ),
            SizedBox(height: AppSpacing.small),
            _buildSocialInput(
              controller: _twitterController,
              icon: Icons.chat,
              label: 'Twitter URL',
            ),
            SizedBox(height: AppSpacing.small),
            _buildSocialInput(
              controller: _youtubeController,
              icon: Icons.play_circle_outline,
              label: 'YouTube URL',
            ),
            SizedBox(height: AppSpacing.small),
            _buildSocialInput(
              controller: _facebookController,
              icon: Icons.facebook,
              label: 'Facebook URL',
            ),
            SizedBox(height: AppSpacing.small),
            _buildSocialInput(
              controller: _websiteController,
              icon: Icons.language,
              label: 'Website URL',
            ),
            
            SizedBox(height: AppSpacing.medium),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialInput({
    required TextEditingController controller,
    required IconData icon,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.primaryMain),
        hintText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.heading2.copyWith(
            color: AppColors.interactive,
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

  List<Widget> _buildSocialChips(Map<String, String> socialLinks) {
    final List<Widget> chips = [];
    
    final icons = {
      'instagram': Icons.camera_alt,
      'twitter': Icons.chat,
      'youtube': Icons.play_circle_outline,
      'facebook': Icons.facebook,
      'website': Icons.language,
    };
    
    socialLinks.forEach((key, value) {
      if (value.isNotEmpty && icons.containsKey(key)) {
        chips.add(
          Chip(
            avatar: Icon(icons[key], size: 16, color: AppColors.primaryMain),
            label: Text(key.substring(0, 1).toUpperCase() + key.substring(1)),
            backgroundColor: AppColors.backgroundSecondary,
          ),
        );
      }
    });
    
    return chips;
  }

  Widget _buildContentList(List<ContentItem> podcasts, {required bool isVideo}) {
    if (podcasts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_off : Icons.music_off,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isVideo ? 'video' : 'audio'} podcasts yet',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Start creating content to build your audience!',
              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
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
        return _buildContentCard(podcast, isVideo: isVideo);
      },
    );
  }

  Widget _buildContentCard(ContentItem podcast, {required bool isVideo}) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: podcast.coverImage != null
                ? Image.network(
                    podcast.coverImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(isVideo),
                  )
                : _buildThumbnailPlaceholder(isVideo),
          ),
        ),
        title: Text(
          podcast.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${podcast.plays} plays • ${podcast.category}',
          style: AppTypography.caption,
        ),
        trailing: IconButton(
          icon: Icon(
            isVideo ? Icons.play_circle : Icons.play_arrow,
            color: AppColors.interactive,
          ),
          onPressed: () => isVideo ? _handlePlayVideo(podcast) : _handlePlayAudio(podcast),
        ),
        onTap: () => isVideo ? _handlePlayVideo(podcast) : _handlePlayAudio(podcast),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(bool isVideo) {
    return Container(
      color: AppColors.warmBrown.withOpacity(0.2),
      child: Icon(
        isVideo ? Icons.videocam : Icons.music_note,
        color: AppColors.warmBrown,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.large),
      child: Column(
        children: [
          LoadingShimmer(width: double.infinity, height: 180),
          SizedBox(height: AppSpacing.large),
          LoadingShimmer(width: double.infinity, height: 100),
          SizedBox(height: AppSpacing.medium),
          LoadingShimmer(width: double.infinity, height: 200),
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
            Text('Error loading profile', style: AppTypography.heading3),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMyArtist,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No Artist Profile Yet',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              'Create content to automatically set up your artist profile!',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
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

