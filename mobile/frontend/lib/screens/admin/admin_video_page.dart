import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin/admin_content_card.dart';
import '../../widgets/admin/admin_button.dart';
import '../../widgets/shared/empty_state.dart';

/// Video management page for approving/rejecting video podcasts and movies
class AdminVideoPage extends StatefulWidget {
  const AdminVideoPage({super.key});

  @override
  State<AdminVideoPage> createState() => _AdminVideoPageState();
}

class _AdminVideoPageState extends State<AdminVideoPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  List<dynamic> _videoPodcasts = [];
  List<dynamic> _movies = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'All';
  final Set<int> _selectedPodcastIndices = {};
  final Set<int> _selectedMovieIndices = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedPodcastIndices.clear();
      _selectedMovieIndices.clear();
    });

    try {
      final status = _selectedStatus == 'All' ? null : _selectedStatus.toLowerCase();
      
      // Load video podcasts (podcasts with video)
      final podcasts = await _api.getAllContent(
        contentType: 'podcast',
        status: status,
      );
      final videoPodcasts = podcasts.where((p) {
        // Filter for video podcasts (you may need to adjust this based on your data model)
        return true; // For now, show all podcasts
      }).toList();

      // Load movies
      final movies = await _api.getAllContent(
        contentType: 'movie',
        status: status,
      );

      if (mounted) {
        setState(() {
          _videoPodcasts = videoPodcasts;
          _movies = movies;
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

  Future<void> _handleApprove(String type, int index) async {
    final content = type == 'podcast' ? _videoPodcasts : _movies;
    final item = content[index];
    final contentType = item['type'] as String;
    final contentId = item['id'] as int;

    try {
      final success = await _api.approveContent(contentType, contentId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Content approved successfully'),
            backgroundColor: AppColors.successMain,
          ),
        );
        _loadContent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(String type, int index) async {
    final content = type == 'podcast' ? _videoPodcasts : _movies;
    final item = content[index];
    final contentType = item['type'] as String;
    final contentId = item['id'] as int;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReasonDialog(),
    );

    if (reason == null) return;

    try {
      final success = await _api.rejectContent(contentType, contentId, reason: reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Content rejected'),
            backgroundColor: AppColors.warningMain,
          ),
        );
        _loadContent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredContent(List<dynamic> content) {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) return content;
    return content.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final creator = (item['creator_name'] as String? ?? '').toLowerCase();
      return title.contains(searchQuery) || creator.contains(searchQuery);
    }).toList();
  }

  Widget _buildContentList(String type, List<dynamic> content, Set<int> selectedIndices) {
    final filtered = _getFilteredContent(content);
    final isPodcast = type == 'podcast';

    if (filtered.isEmpty) {
      return EmptyState(
        icon: isPodcast ? Icons.video_library_outlined : Icons.movie_outlined,
        title: 'No ${isPodcast ? 'video podcasts' : 'movies'}',
        message: 'No ${isPodcast ? 'video podcasts' : 'movies'} found',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: AppColors.primaryMain,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          final originalIndex = content.indexOf(item);
          return AdminContentCard(
            item: item,
            isSelected: selectedIndices.contains(originalIndex),
            onSelectionChanged: (selected) {
              setState(() {
                if (selected) {
                  selectedIndices.add(originalIndex);
                } else {
                  selectedIndices.remove(originalIndex);
                }
              });
            },
            onApprove: () => _handleApprove(type, originalIndex),
            onReject: () => _handleReject(type, originalIndex),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter and Search Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(
              bottom: BorderSide(
                color: AppColors.borderPrimary,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by title or creator...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    borderSide: BorderSide(color: AppColors.borderPrimary),
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundPrimary,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.medium),
              // Status Filter
              Row(
                children: [
                  Text(
                    'Status:',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'All', label: Text('All')),
                        ButtonSegment(value: 'Pending', label: Text('Pending')),
                        ButtonSegment(value: 'Approved', label: Text('Approved')),
                        ButtonSegment(value: 'Rejected', label: Text('Rejected')),
                      ],
                      selected: {_selectedStatus},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedStatus = newSelection.first;
                        });
                        _loadContent();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadContent,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: AppColors.cardBackground,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryMain,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryMain,
            tabs: const [
              Tab(text: 'Video Podcasts', icon: Icon(Icons.video_library)),
              Tab(text: 'Movies', icon: Icon(Icons.movie)),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryMain,
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.errorMain,
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          Text(
                            'Error loading content',
                            style: AppTypography.heading3,
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Text(
                            _error!,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          AdminPrimaryButton(
                            label: 'Retry',
                            icon: Icons.refresh,
                            onPressed: _loadContent,
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildContentList('podcast', _videoPodcasts, _selectedPodcastIndices),
                        _buildContentList('movie', _movies, _selectedMovieIndices),
                      ],
                    ),
        ),
      ],
    );
  }
}

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
      title: Text(
        'Reject Content',
        style: AppTypography.heading3,
      ),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Reason (optional)',
          hintText: 'Enter reason for rejection...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
        ),
        maxLines: 3,
      ),
      actions: [
        AdminOutlinedButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        AdminErrorButton(
          label: 'Reject',
          icon: Icons.close,
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    );
  }
}

