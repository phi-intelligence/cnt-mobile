import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_content_card.dart';
import '../../widgets/admin/admin_filter_chips.dart';
import '../../widgets/admin/admin_page_scaffold.dart';
import '../../widgets/shared/pill_text_field.dart';
import '../../widgets/shared/empty_state.dart';

/// Unified admin content moderation (pending / approved / all).
class AdminContentPage extends StatefulWidget {
  final String? initialFilter;
  final int? initialTabIndex;
  final VoidCallback? onFilterApplied;

  const AdminContentPage({
    super.key,
    this.initialFilter,
    this.initialTabIndex,
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

  List<dynamic> _pending = [];
  List<dynamic> _approved = [];
  bool _isLoading = true;
  String? _error;
  String _selectedTypeFilter = 'All';
  String _podcastSubFilter = 'All';

  static const _typeFilters = [
    'All',
    'Podcasts',
    'Movies',
    'Posts',
    'Music',
    'Events',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex?.clamp(0, 2) ?? 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    if (widget.initialFilter != null &&
        _typeFilters.contains(widget.initialFilter)) {
      _selectedTypeFilter = widget.initialFilter!;
    }
    _searchController.addListener(() => setState(() {}));
    _fetchContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFilterApplied?.call();
    });
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
      final results = await Future.wait([
        _api.getAllContent(contentType: 'podcast', status: 'pending', limit: 500),
        _api.getAllContent(contentType: 'movie', status: 'pending', limit: 500),
        _api.getAllContent(contentType: 'community_post', status: 'pending', limit: 500),
        _api.getAllContent(contentType: 'music', status: 'pending', limit: 500),
        _api.getAllContent(contentType: 'event', status: 'pending', limit: 500),
        _api.getAllContent(contentType: 'podcast', status: 'approved', limit: 500),
        _api.getAllContent(contentType: 'movie', status: 'approved', limit: 500),
        _api.getAllContent(contentType: 'community_post', status: 'approved', limit: 500),
        _api.getAllContent(contentType: 'music', status: 'approved', limit: 500),
        _api.getAllContent(contentType: 'event', status: 'approved', limit: 500),
      ]);

      if (!mounted) return;
      setState(() {
        _pending = [
          ...results[0],
          ...results[1],
          ...results[2],
          ...results[3],
          ...results[4],
        ];
        _approved = [
          ...results[5],
          ...results[6],
          ...results[7],
          ...results[8],
          ...results[9],
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> _currentList() {
    final tab = _tabController.index;
    if (tab == 0) return _pending;
    if (tab == 1) return _approved;
    return [..._pending, ..._approved];
  }

  List<dynamic> _filteredList() {
    final query = _searchController.text.trim().toLowerCase();
    var items = _currentList();

    items = items.where((item) {
      final type = (item['type'] as String? ?? '').toLowerCase();
      switch (_selectedTypeFilter) {
        case 'Podcasts':
          if (type != 'podcast') return false;
          if (_podcastSubFilter == 'Audio') {
            final videoUrl = item['video_url'] as String?;
            return videoUrl == null || videoUrl.isEmpty;
          }
          if (_podcastSubFilter == 'Video') {
            final videoUrl = item['video_url'] as String?;
            return videoUrl != null && videoUrl.isNotEmpty;
          }
          return true;
        case 'Movies':
          return type == 'movie';
        case 'Posts':
          return type == 'community_post';
        case 'Music':
          return type == 'music';
        case 'Events':
          return type == 'event';
        default:
          return true;
      }
    }).toList();

    if (query.isNotEmpty) {
      items = items.where((item) {
        final title = (item['title'] as String? ?? '').toLowerCase();
        final desc = (item['description'] as String? ?? '').toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    }

    return items;
  }

  String _contentType(dynamic item) => item['type'] as String? ?? 'podcast';

  int _contentId(dynamic item) => item['id'] as int;

  Future<void> _approve(dynamic item) async {
    try {
      final ok = await _api.approveContent(_contentType(item), _contentId(item));
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content approved')),
        );
        await _fetchContent();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorMain),
      );
    }
  }

  Future<void> _reject(dynamic item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject content'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    try {
      final ok = await _api.rejectContent(
        _contentType(item),
        _contentId(item),
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content rejected')),
        );
        await _fetchContent();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorMain),
      );
    }
  }

  Future<void> _delete(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete content'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.errorMain)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await _api.deleteAdminContent(_contentType(item), _contentId(item));
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content deleted')),
        );
        await _fetchContent();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorMain),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AdminPageScaffold(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.warmBrown),
        ),
      );
    }

    if (_error != null) {
      return AdminErrorState(
        title: 'Error loading content',
        message: _error!,
        onRetry: _fetchContent,
      );
    }

    final items = _filteredList();
    final isPendingTab = _tabController.index == 0;
    final isApprovedTab = _tabController.index == 1;

    return AdminPageScaffold(
      onRefresh: _fetchContent,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.tabSelected,
            unselectedLabelColor: AppColors.tabUnselected,
            indicatorColor: AppColors.warmBrown,
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: 'Pending (${_pending.length})'),
              Tab(text: 'Approved (${_approved.length})'),
              const Tab(text: 'All'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: PillSearchField(
              controller: _searchController,
              hintText: 'Search content...',
              onChanged: (_) => setState(() {}),
            ),
          ),
          AdminFilterChips(
            options: _typeFilters,
            selected: _selectedTypeFilter,
            onSelected: (value) => setState(() => _selectedTypeFilter = value),
          ),
          if (_selectedTypeFilter == 'Podcasts') ...[
            const SizedBox(height: 8),
            AdminFilterChips(
              options: const ['All', 'Audio', 'Video'],
              selected: _podcastSubFilter,
              onSelected: (value) => setState(() => _podcastSubFilter = value),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No content',
                    message: 'Nothing matches your filters.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final status =
                          (item['status'] as String? ?? 'pending').toLowerCase();
                      final showApprove = isPendingTab || status == 'pending';
                      final showDelete = isApprovedTab || status == 'approved';

                      return AdminContentCard(
                        item: item,
                        onApprove: showApprove ? () => _approve(item) : null,
                        onReject: showApprove ? () => _reject(item) : null,
                        onDelete: showDelete ? () => _delete(item) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
