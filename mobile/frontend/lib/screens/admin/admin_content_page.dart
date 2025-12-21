import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared/pill_text_field.dart';
import '../../widgets/shared/empty_state.dart';

/// Combined Admin Content Page with sub-tabs and filters
/// Manages Pending, Approved, and All content in one place
class AdminContentPage extends StatefulWidget {
  final String? initialFilter;
  final VoidCallback? onFilterApplied;

  const AdminContentPage({
    super.key,
    this.initialFilter,
    this.onFilterApplied,
  });

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // Content lists by status
  List<dynamic> _pendingContent = [];
  List<dynamic> _approvedContent = [];
  List<dynamic> _allContent = [];

  bool _isLoading = true;
  String? _error;
  String _selectedTypeFilter = 'All';

  final List<String> _typeFilters = ['All', 'Audio', 'Video', 'Movies', 'Posts'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Apply initial filter if provided
    if (widget.initialFilter != null && _typeFilters.contains(widget.initialFilter)) {
      _selectedTypeFilter = widget.initialFilter!;
      widget.onFilterApplied?.call();
    }
    _fetchContent();
  }

  @override
  void didUpdateWidget(covariant AdminContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Apply new filter if it changed
    if (widget.initialFilter != null && 
        widget.initialFilter != oldWidget.initialFilter &&
        _typeFilters.contains(widget.initialFilter)) {
      setState(() {
        _selectedTypeFilter = widget.initialFilter!;
      });
      widget.onFilterApplied?.call();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch podcasts with different statuses
      final pendingPodcasts = await _api.getPodcasts(status: 'pending');
      final approvedPodcasts = await _api.getPodcasts(status: 'approved');

      // Fetch movies with different statuses
      final pendingMovies = await _api.getMovies(status: 'pending');
      final approvedMovies = await _api.getMovies(status: 'approved');

      // Fetch community posts (pending = approvedOnly: false, approved = approvedOnly: true)
      final allPosts = await _api.getCommunityPosts(approvedOnly: false, limit: 100);
      final pendingPosts = allPosts.where((p) => p['is_approved'] == 0 || p['is_approved'] == false).toList();
      final approvedPosts = allPosts.where((p) => p['is_approved'] == 1 || p['is_approved'] == true).toList();

      // Transform all content types to common format
      _pendingContent = [
        ...pendingPodcasts.map((p) => _podcastToContent(p, 'pending')),
        ...pendingMovies.map((m) => _movieToContent(m, 'pending')),
        ...pendingPosts.map((p) => _postToContent(p, 'pending')),
      ];
      _approvedContent = [
        ...approvedPodcasts.map((p) => _podcastToContent(p, 'approved')),
        ...approvedMovies.map((m) => _movieToContent(m, 'approved')),
        ...approvedPosts.map((p) => _postToContent(p, 'approved')),
      ];
      _allContent = [..._pendingContent, ..._approvedContent];

      // Sort by date
      _allContent.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      _pendingContent.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      _approvedContent.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _podcastToContent(dynamic podcast, String status) {
    return {
      'id': podcast.id,
      'title': podcast.title ?? 'Untitled',
      'description': podcast.description ?? '',
      'creator_id': podcast.creatorId,
      'cover_image': podcast.coverImage,
      'created_at': podcast.createdAt?.toIso8601String() ?? '',
      'status': status,
      'type': podcast.videoUrl != null ? 'video' : 'audio',
      'content_type': 'podcast',
      '_raw': podcast,
    };
  }

  Map<String, dynamic> _movieToContent(dynamic movie, String status) {
    return {
      'id': movie.id,
      'title': movie.title ?? 'Untitled',
      'description': movie.description ?? '',
      'creator_id': movie.creatorId,
      'cover_image': movie.coverImage ?? movie.thumbnail,
      'created_at': movie.createdAt?.toIso8601String() ?? '',
      'status': status,
      'type': 'movie',
      'content_type': 'movie',
      '_raw': movie,
    };
  }

  Map<String, dynamic> _postToContent(dynamic post, String status) {
    return {
      'id': post['id'],
      'title': post['title'] ?? 'Untitled Post',
      'description': post['content'] ?? '',
      'creator_id': post['user_id'],
      'cover_image': post['image_url'],
      'created_at': post['created_at'] ?? '',
      'status': status,
      'type': 'post',
      'content_type': 'community_post',
      '_raw': post,
    };
  }

  List<dynamic> _getFilteredContent(List<dynamic> content) {
    var filtered = content;

    // Apply type filter
    if (_selectedTypeFilter != 'All') {
      filtered = filtered.where((item) {
        final type = item['type']?.toString().toLowerCase() ?? '';
        switch (_selectedTypeFilter.toLowerCase()) {
          case 'audio':
            return type == 'audio';
          case 'video':
            return type == 'video';
          case 'movies':
            return type == 'movie';
          case 'posts':
            return type == 'post';
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final description = item['description']?.toString().toLowerCase() ?? '';
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0E8),
      child: Column(
        children: [
          _buildTabBar(),
          _buildFilters(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.warmBrown,
          borderRadius: BorderRadius.circular(25),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.bodySmall,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending'),
                if (_pendingContent.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tabController.index == 0
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.warningMain.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_pendingContent.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _tabController.index == 0
                            ? Colors.white
                            : AppColors.warningMain,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Approved'),
          const Tab(text: 'All'),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Field
          PillSearchField(
            controller: _searchController,
            hintText: 'Search content...',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Type Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _typeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _typeFilters[index];
                final isSelected = _selectedTypeFilter == filter;
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedTypeFilter = filter;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.warmBrown.withOpacity(0.15),
                  labelStyle: AppTypography.caption.copyWith(
                    color: isSelected ? AppColors.warmBrown : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.warmBrown
                        : AppColors.borderPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.warmBrown),
            const SizedBox(height: 16),
            Text(
              'Loading content...',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.errorMain),
            const SizedBox(height: 16),
            Text('Error: $_error', style: AppTypography.body),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildContentList(_getFilteredContent(_pendingContent), 'pending'),
        _buildContentList(_getFilteredContent(_approvedContent), 'approved'),
        _buildContentList(_getFilteredContent(_allContent), 'all'),
      ],
    );
  }

  Widget _buildContentList(List<dynamic> content, String listType) {
    if (content.isEmpty) {
      return EmptyState(
        icon: listType == 'pending' ? Icons.pending_actions : Icons.folder_open,
        title: listType == 'pending' ? 'No pending content' : 'No content found',
        message: listType == 'pending'
            ? 'All content has been reviewed!'
            : 'Try adjusting your filters or search',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchContent,
      color: AppColors.warmBrown,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: content.length,
        itemBuilder: (context, index) {
          return _buildContentCard(content[index]);
        },
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> item) {
    final isPending = item['status'] == 'pending';
    final type = item['type'] ?? 'audio';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: item['cover_image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item['cover_image'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _getTypeIcon(type),
                              color: AppColors.warmBrown,
                            ),
                          ),
                        )
                      : Icon(
                          _getTypeIcon(type),
                          color: AppColors.warmBrown,
                        ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? 'Untitled',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTypeBadge(type),
                          const SizedBox(width: 8),
                          _buildStatusBadge(item['status']),
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 20),
                          SizedBox(width: 12),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (isPending) ...[
                      PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.successMain, size: 20),
                            const SizedBox(width: 12),
                            const Text('Approve'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reject',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: AppColors.errorMain, size: 20),
                            const SizedBox(width: 12),
                            const Text('Reject'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleAction(value, item),
                ),
              ],
            ),
          ),
          // Quick Actions for Pending
          if (isPending)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleAction('reject', item),
                      icon: Icon(Icons.close, size: 18, color: AppColors.errorMain),
                      label: Text('Reject', style: TextStyle(color: AppColors.errorMain)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.errorMain.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAction('approve', item),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successMain,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    IconData icon;
    
    switch (type.toLowerCase()) {
      case 'video':
        color = const Color(0xFF8B5CF6);
        icon = Icons.videocam;
        break;
      case 'movie':
        color = const Color(0xFF6366F1);
        icon = Icons.movie;
        break;
      case 'post':
        color = const Color(0xFFF59E0B);
        icon = Icons.article;
        break;
      default:
        color = const Color(0xFF10B981);
        icon = Icons.mic;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.capitalize(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    final isApproved = status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isApproved
            ? AppColors.successMain.withOpacity(0.1)
            : AppColors.warningMain.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        (status ?? 'pending').capitalize(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isApproved ? AppColors.successMain : AppColors.warningMain,
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.videocam;
      case 'movie':
        return Icons.movie;
      case 'post':
        return Icons.article;
      default:
        return Icons.mic;
    }
  }

  Future<void> _handleAction(String action, Map<String, dynamic> item) async {
    switch (action) {
      case 'approve':
        await _approveContent(item);
        break;
      case 'reject':
        await _rejectContent(item);
        break;
      case 'delete':
        await _deleteContent(item);
        break;
      case 'view':
        _showContentDetails(item);
        break;
    }
  }

  void _showContentDetails(Map<String, dynamic> item) {
    final type = item['type'] ?? 'audio';
    final isPending = item['status'] == 'pending';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F0E8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Content Details',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image
                    if (item['cover_image'] != null)
                      Container(
                        width: double.infinity,
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.warmBrown.withOpacity(0.1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _api.getMediaUrl(item['cover_image']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                _getTypeIcon(type),
                                size: 64,
                                color: AppColors.warmBrown.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 150,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.warmBrown.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Icon(
                            _getTypeIcon(type),
                            size: 64,
                            color: AppColors.warmBrown.withOpacity(0.5),
                          ),
                        ),
                      ),
                    // Title
                    _buildDetailRow('Title', item['title'] ?? 'Untitled'),
                    _buildDetailRow('Type', type.toString().capitalize()),
                    _buildDetailRow('Status', (item['status'] ?? 'pending').toString().capitalize()),
                    if (item['description'] != null && item['description'].toString().isNotEmpty)
                      _buildDetailRow('Description', item['description']),
                    if (item['creator_id'] != null)
                      _buildDetailRow('Creator ID', item['creator_id'].toString()),
                    if (item['created_at'] != null)
                      _buildDetailRow('Created', _formatDate(item['created_at'])),
                    const SizedBox(height: 24),
                    // Action Buttons
                    if (isPending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _handleAction('reject', item);
                              },
                              icon: Icon(Icons.close, color: AppColors.errorMain),
                              label: Text('Reject', style: TextStyle(color: AppColors.errorMain)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.errorMain),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _handleAction('approve', item);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successMain,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Delete button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleAction('delete', item);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete Content', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warmBrown.withOpacity(0.1)),
            ),
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _approveContent(Map<String, dynamic> item) async {
    try {
      await _api.approvePodcast(item['id']);
      _showSnackBar('Content approved successfully', isSuccess: true);
      _fetchContent();
    } catch (e) {
      _showSnackBar('Failed to approve: $e');
    }
  }

  Future<void> _rejectContent(Map<String, dynamic> item) async {
    final reason = await _showRejectDialog();
    if (reason != null) {
      try {
        await _api.rejectPodcast(item['id'], reason: reason);
        _showSnackBar('Content rejected', isSuccess: true);
        _fetchContent();
      } catch (e) {
        _showSnackBar('Failed to reject: $e');
      }
    }
  }

  Future<void> _deleteContent(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Content', style: AppTypography.heading3),
        content: const Text('Are you sure you want to delete this content? This action cannot be undone.'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deletePodcast(item['id']);
        _showSnackBar('Content deleted', isSuccess: true);
        _fetchContent();
      } catch (e) {
        _showSnackBar('Failed to delete: $e');
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Content', style: AppTypography.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection (optional):'),
            const SizedBox(height: 16),
            PillTextFieldOutlined(
              controller: controller,
              hintText: 'Reason for rejection...',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.successMain : AppColors.errorMain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

