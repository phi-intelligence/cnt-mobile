import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/admin/admin_content_card.dart';
import '../../widgets/admin/admin_button.dart';
import '../../widgets/shared/empty_state.dart';

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

/// Audio management page for approving/rejecting audio podcasts
class AdminAudioPage extends StatefulWidget {
  const AdminAudioPage({super.key});

  @override
  State<AdminAudioPage> createState() => _AdminAudioPageState();
}

class _AdminAudioPageState extends State<AdminAudioPage> {
  final ApiService _api = ApiService();
  List<dynamic> _content = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'All';
  final Set<int> _selectedIndices = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedIndices.clear();
    });

    try {
      final status = _selectedStatus == 'All' ? null : _selectedStatus.toLowerCase();
      final content = await _api.getAllContent(
        contentType: 'podcast',
        status: status,
      );
      if (mounted) {
        setState(() {
          _content = content;
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

  Future<void> _handleApprove(int index) async {
    final item = _content[index];
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

  Future<void> _handleReject(int index) async {
    final item = _content[index];
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

  List<dynamic> get _filteredContent {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) return _content;
    return _content.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final creator = (item['creator_name'] as String? ?? '').toLowerCase();
      return title.contains(searchQuery) || creator.contains(searchQuery);
    }).toList();
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
              // Bulk Actions
              if (_selectedIndices.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.medium),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.small),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedIndices.length} selected',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      AdminOutlinedButton(
                        label: 'Approve Selected',
                        icon: Icons.check,
                        borderColor: AppColors.successMain,
                        textColor: AppColors.successMain,
                        onPressed: () async {
                          for (final index in _selectedIndices.toList()) {
                            await _handleApprove(index);
                          }
                          setState(() {
                            _selectedIndices.clear();
                          });
                        },
                      ),
                      const SizedBox(width: AppSpacing.small),
                      AdminOutlinedButton(
                        label: 'Reject Selected',
                        icon: Icons.close,
                        borderColor: AppColors.errorMain,
                        textColor: AppColors.errorMain,
                        onPressed: () async {
                          for (final index in _selectedIndices.toList()) {
                            await _handleReject(index);
                          }
                          setState(() {
                            _selectedIndices.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Content List
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
                  : _filteredContent.isEmpty
                      ? const EmptyState(
                          icon: Icons.podcasts_outlined,
                          title: 'No audio content',
                          message: 'No audio podcasts found',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadContent,
                          color: AppColors.primaryMain,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.medium),
                            itemCount: _filteredContent.length,
                            itemBuilder: (context, index) {
                              final item = _filteredContent[index];
                              final originalIndex = _content.indexOf(item);
                              return AdminContentCard(
                                item: item,
                                isSelected: _selectedIndices.contains(originalIndex),
                                onSelectionChanged: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIndices.add(originalIndex);
                                    } else {
                                      _selectedIndices.remove(originalIndex);
                                    }
                                  });
                                },
                                onApprove: () => _handleApprove(originalIndex),
                                onReject: () => _handleReject(originalIndex),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

