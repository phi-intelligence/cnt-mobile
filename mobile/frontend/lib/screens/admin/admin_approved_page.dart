import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../utils/app_logger.dart';

/// Admin Approved Page - Shows all approved content with tabs
/// Tabs: All, Podcasts, Movies, Posts
@Deprecated('Use AdminContentPage')
class AdminApprovedPage extends StatefulWidget {
  final int initialTabIndex;

  const AdminApprovedPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminApprovedPage> createState() => _AdminApprovedPageState();
}

class _AdminApprovedPageState extends State<AdminApprovedPage>
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
      // Fetch all podcasts and filter by approved status
      final podcasts = await _api.getPodcasts(status: 'approved');
      
      // TODO: Add movies and posts endpoints when available
      final movies = <dynamic>[];
      final posts = <dynamic>[];

      // Combine all content
      final allContent = [
        ...podcasts.map((p) => {
          'id': p.id,
          'title': p.title,
          'creator_name': 'Creator #${p.creatorId ?? 0}',
          'cover_image': p.coverImage,
          'created_at': p.createdAt.toIso8601String(),
          'video_url': p.videoUrl,
          'plays_count': p.playsCount,
          '_type': 'podcast',
        }),
        ...movies.map((m) => {...m, '_type': 'movie'}),
        ...posts.map((p) => {...p, '_type': 'post'}),
      ];

      // Sort by created_at (newest first)
      allContent.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _allContent = allContent;
        _podcasts = podcasts.map((p) => {
          'id': p.id,
          'title': p.title,
          'creator_name': 'Creator #${p.creatorId ?? 0}',
          'cover_image': p.coverImage,
          'created_at': p.createdAt.toIso8601String(),
          'video_url': p.videoUrl,
          'plays_count': p.playsCount,
        }).toList();
        _movies = movies;
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.debug('❌ Error fetching approved content: $e');
      setState(() {
        _error = 'Failed to load approved content';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteContent(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content'),
        content: Text('Are you sure you want to delete "${item['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final type = item['_type'] as String?;
    final id = item['id'];

    try {
      bool success = false;
      if (type == 'podcast') {
        // TODO: Implement delete API when available
        // For now, set status to 'deleted' or remove from list
        success = true;
      } else if (type == 'movie') {
        // TODO: Add movie delete API
        success = true;
      } else if (type == 'post') {
        // TODO: Add post delete API
        success = true;
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content deleted successfully'),
            backgroundColor: AppColors.successMain,
          ),
        );
        _fetchContent();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
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
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Approved Content',
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _fetchContent,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryMain,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryMain,
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search approved content...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
          child: LoadingShimmer(width: double.infinity, height: 100),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          child: Row(
            children: ['All', 'Audio', 'Video'].map((filter) {
              final isSelected = _podcastFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.small),
                child: FilterChip(
                  label: Text(
                    filter,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _podcastFilter = filter),
                  selectedColor: AppColors.primaryMain,
                  backgroundColor: AppColors.backgroundSecondary,
                  checkmarkColor: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Expanded(
          child: _buildContentList(_filterBySearch(_getFilteredPodcasts())),
        ),
      ],
    );
  }

  Widget _buildContentList(List<dynamic> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'No Content Found',
        message: 'No approved content available',
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
    final creatorName = item['creator_name'] as String? ?? 'Unknown';
    final coverImage = item['cover_image'] as String?;
    final createdAt = item['created_at'] as String?;
    final playsCount = item['plays_count'] as int? ?? 0;
    final isVideo = (item['video_url'] as String?)?.isNotEmpty == true;

    return Card(
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
            child: coverImage != null
                ? Image.network(
                    _api.getMediaUrl(coverImage),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _getTypeIcon(type),
                      color: AppColors.textSecondary,
                    ),
                  )
                : Icon(
                    _getTypeIcon(type),
                    color: AppColors.textSecondary,
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type == 'podcast' ? (isVideo ? 'Video' : 'Audio') : type.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: _getTypeColor(type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'By $creatorName',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.play_circle, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$playsCount plays',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteContent(item);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('View'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: AppColors.errorMain),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.errorMain)),
                ],
              ),
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
        return AppColors.primaryMain;
      case 'movie':
        return Colors.blue;
      case 'post':
        return Colors.green;
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
