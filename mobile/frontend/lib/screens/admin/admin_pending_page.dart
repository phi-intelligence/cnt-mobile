import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin/admin_content_card.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../utils/app_logger.dart';

/// Reject reason dialog
class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundPrimary,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.errorMain.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.block, color: AppColors.errorMain, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Reject Content',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Please provide a reason for rejection (optional):',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Enter reason for rejection...',
              hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
              filled: true,
              fillColor: Colors.white,
          border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderPrimary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderPrimary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
          ),
        ),
        maxLines: 3,
      ),
        ],
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.borderPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
        ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorMain,
            foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
            ),
                  elevation: 0,
          ),
          child: const Text('Reject'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Admin Pending Page - Shows all pending content with tabs
/// Tabs: All, Podcasts, Movies, Posts
class AdminPendingPage extends StatefulWidget {
  final int initialTabIndex;

  const AdminPendingPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminPendingPage> createState() => _AdminPendingPageState();
}

class _AdminPendingPageState extends State<AdminPendingPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Content lists
  List<dynamic> _allContent = [];
  List<dynamic> _podcasts = [];
  List<dynamic> _movies = [];
  List<dynamic> _posts = [];

  // Loading states
  bool _isLoading = true;
  String? _error;

  // Podcast filter (All, Audio, Video)
  String _podcastFilter = 'All';

  // Search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _fetchContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all podcasts and filter by pending status
      final podcasts = await _api.getPodcasts(status: 'pending');
      
      // Fetch pending movies
      final moviesData = await _api.getAllContent(
        contentType: 'movie',
        status: 'pending',
      );
      
      // Fetch pending posts
      final postsData = await _api.getAllContent(
        contentType: 'community_post',
        status: 'pending',
      );

      // Transform podcasts
      final podcastList = podcasts.map((p) => {
          'id': p.id,
          'title': p.title,
          'creator_name': 'Creator #${p.creatorId ?? 0}',
          'cover_image': p.coverImage,
          'created_at': p.createdAt.toIso8601String(),
          'video_url': p.videoUrl,
          '_type': 'podcast',
      }).toList();

      // Transform movies
      final movieList = moviesData.map((m) => {
        'id': m['id'],
        'title': m['title'] ?? 'Untitled Movie',
        'creator_name': m['director'] ?? 'Unknown',
        'cover_image': m['cover_image'],
        'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        '_type': 'movie',
      }).toList();

      // Transform posts
      final postList = postsData.map((p) => {
        'id': p['id'],
        'title': p['title'] ?? 'Untitled Post',
        'creator_name': p['creator_name'] ?? p['user_name'] ?? 'Unknown',
        'cover_image': p['image_url'],
        'created_at': p['created_at'] ?? DateTime.now().toIso8601String(),
        'content': p['content'],
        '_type': 'post',
      }).toList();

      // Combine all content
      final allContent = [...podcastList, ...movieList, ...postList];

      // Sort by created_at (newest first)
      allContent.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _allContent = allContent;
        _podcasts = podcastList;
        _movies = movieList;
        _posts = postList;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.debug('❌ Error fetching pending content: $e');
      setState(() {
        _error = 'Failed to load pending content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveContent(dynamic item) async {
    final type = item['_type'] as String?;
    final id = item['id'];

    try {
      bool success = false;
      String contentType = '';
      
      if (type == 'podcast') {
        contentType = 'podcast';
        success = await _api.approveContent(contentType, id);
      } else if (type == 'movie') {
        contentType = 'movie';
        success = await _api.approveContent(contentType, id);
      } else if (type == 'post') {
        contentType = 'community_post';
        success = await _api.approveContent(contentType, id);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content approved successfully'),
            backgroundColor: AppColors.successMain,
          ),
        );
        _fetchContent();
      } else {
        throw Exception('Approval failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    }
  }

  Future<void> _rejectContent(dynamic item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReasonDialog(),
    );

    if (reason == null) return; // User cancelled

    final type = item['_type'] as String?;
    final id = item['id'];

    try {
      bool success = false;
      String contentType = '';
      
      if (type == 'podcast') {
        contentType = 'podcast';
        success = await _api.rejectContent(contentType, id, reason: reason);
      } else if (type == 'movie') {
        contentType = 'movie';
        success = await _api.rejectContent(contentType, id, reason: reason);
      } else if (type == 'post') {
        contentType = 'community_post';
        success = await _api.rejectContent(contentType, id, reason: reason);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content rejected'),
            backgroundColor: AppColors.warningMain,
          ),
        );
        _fetchContent();
      } else {
        throw Exception('Rejection failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    }
  }

  List<dynamic> _getFilteredPodcasts() {
    if (_podcastFilter == 'All') return _podcasts;
    if (_podcastFilter == 'Audio') {
      return _podcasts
          .where((p) => p['video_url'] == null || p['video_url'].isEmpty)
          .toList();
    }
    return _podcasts
        .where((p) => p['video_url'] != null && p['video_url'].isNotEmpty)
        .toList();
  }

  List<dynamic> _filterBySearch(List<dynamic> items) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      final title = (item['title'] as String?)?.toLowerCase() ?? '';
      final creator = (item['creator_name'] as String?)?.toLowerCase() ?? '';
      return title.contains(query) || creator.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.warmBrown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pending Content',
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.warmBrown,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.warmBrown),
            onPressed: _fetchContent,
            tooltip: 'Refresh',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.warmBrown,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.warmBrown,
          indicatorWeight: 3,
          labelStyle: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'All (${_allContent.length})'),
            Tab(text: 'Podcasts (${_podcasts.length})'),
            Tab(text: 'Movies (${_movies.length})'),
            Tab(text: 'Posts (${_posts.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              border: Border(
                bottom: BorderSide(color: AppColors.borderPrimary.withOpacity(0.3)),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search pending content...',
                hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search, color: AppColors.warmBrown),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderPrimary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderPrimary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildContentList(_filterBySearch(_allContent)),
                          _buildPodcastsTab(),
                          _buildContentList(_filterBySearch(_movies)),
                          _buildContentList(_filterBySearch(_posts)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.small),
          child: LoadingShimmer(width: double.infinity, height: 120),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.errorMain),
          const SizedBox(height: AppSpacing.medium),
          Text(_error!, style: AppTypography.body),
          const SizedBox(height: AppSpacing.medium),
          ElevatedButton(
            onPressed: _fetchContent,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPodcastsTab() {
    return Column(
      children: [
        // Filter chips for podcasts
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium, vertical: AppSpacing.small),
          child: Row(
            children: ['All', 'Audio', 'Video'].map((filter) {
              final isSelected = _podcastFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.small),
                child: GestureDetector(
                  onTap: () => setState(() => _podcastFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.warmBrown : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.warmBrown : AppColors.borderPrimary,
                        width: 1.5,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppColors.warmBrown.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filter == 'Audio' ? Icons.audiotrack : filter == 'Video' ? Icons.videocam : Icons.all_inclusive,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.warmBrown,
                        ),
                        const SizedBox(width: 6),
                        Text(
                    filter,
                    style: AppTypography.bodySmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.warmBrown,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
        Expanded(
          child: _buildContentList(_filterBySearch(_getFilteredPodcasts())),
        ),
      ],
    );
  }

  Widget _buildContentList(List<dynamic> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Pending Content',
        message: 'All content has been reviewed',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchContent,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildContentCard(item);
        },
      ),
    );
  }

  Widget _buildContentCard(dynamic item) {
    final type = item['_type'] as String? ?? 'unknown';
    final title = item['title'] as String? ?? 'Untitled';
    // Try multiple fields for creator name
    final creatorName = item['creator_name'] as String? ?? 
                        item['user_name'] as String? ?? 
                        item['artist_name'] as String? ??
                        item['author'] as String? ??
                        'Unknown Creator';
    final coverImage = item['cover_image'] as String?;
    final createdAt = item['created_at'] as String?;
    final isVideo = (item['video_url'] as String?)?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmBrown.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: coverImage != null
                        ? Image.network(
                            _api.getMediaUrl(coverImage),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                              _getTypeIcon(type),
                                color: AppColors.warmBrown.withOpacity(0.5),
                                size: 36,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                            _getTypeIcon(type),
                              color: AppColors.warmBrown.withOpacity(0.5),
                              size: 36,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(type).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTypeIcon(type),
                                  size: 12,
                                  color: _getTypeColor(type),
                                ),
                                const SizedBox(width: 4),
                                Text(
                              type == 'podcast'
                                  ? (isVideo ? 'Video' : 'Audio')
                                  : type.toUpperCase(),
                              style: AppTypography.caption.copyWith(
                                color: _getTypeColor(type),
                                fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                              ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningMain.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.warningMain,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                              'PENDING',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.warningMain,
                                fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                              ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.warmBrown,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              creatorName,
                        style: AppTypography.bodySmall.copyWith(
                                color: AppColors.warmBrown,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                        Text(
                              _formatDate(createdAt),
                          style: AppTypography.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                          ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                  onPressed: () => _rejectContent(item),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorMain,
                      side: BorderSide(color: AppColors.errorMain.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: ElevatedButton.icon(
                  onPressed: () => _approveContent(item),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successMain,
                    foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'podcast':
        return Icons.podcasts;
      case 'movie':
        return Icons.movie;
      case 'post':
        return Icons.article;
      default:
        return Icons.content_copy;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'podcast':
        return AppColors.warmBrown;
      case 'movie':
        return AppColors.primaryDark;
      case 'post':
        return AppColors.accentDark;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

