import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/admin/admin_page_scaffold.dart';
import '../../widgets/admin/admin_stat_grid.dart';
import '../../widgets/admin/admin_section_header.dart';
import 'admin_support_page.dart';
import 'admin_documents_page.dart';
import 'admin_commission_settings_page.dart';
import 'admin_donations_page.dart';

/// Dashboard page showing overview statistics and quick actions
/// Redesigned with cream/brown theme and cleaner layout
class AdminDashboardPage extends StatefulWidget {
  final void Function(int index, {String? contentFilter, int? contentTabIndex})?
      onNavigateToTab;

  const AdminDashboardPage({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _api.getAdminDashboard();
      if (mounted) {
        setState(() {
          _stats = stats;
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

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      onRefresh: _loadStats,
      child: _buildContentInner(),
    );
  }

  Widget _buildContentInner() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.warmBrown,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard...',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return AdminErrorState(
        title: 'Error loading dashboard',
        message: _error!,
        onRetry: _loadStats,
      );
    }

    if (_stats == null) {
      return const EmptyState(
        icon: Icons.dashboard_outlined,
        title: 'No data available',
        message: 'Unable to load dashboard statistics',
      );
    }

    return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickStatsSection(),
            const SizedBox(height: 24),
            _buildPendingSection(),
            const SizedBox(height: 24),
            _buildContentOverview(),
            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warmBrown,
            AppColors.warmBrown.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmBrown.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.waving_hand,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, Admin!',
                      style: AppTypography.heading3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here\'s what\'s happening today',
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _calculateTotalPending() > 0
                      ? () => widget.onNavigateToTab?.call(
                            1,
                            contentTabIndex: 0,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildWelcomeStat(
                    label: 'Pending',
                    value: _calculateTotalPending().toString(),
                    icon: Icons.pending_actions,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: (_stats?['open_support_tickets'] ?? 0) > 0
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminSupportPage(),
                            ),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildWelcomeStat(
                    label: 'Support',
                    value: (_stats?['open_support_tickets'] ?? 0).toString(),
                    icon: Icons.support_agent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionHeader(title: 'Quick Stats'),
        const SizedBox(height: 12),
        AdminStatGrid(
          children: [
            _buildStatCard(
              icon: Icons.podcasts,
              label: 'Podcasts',
              value: (_stats?['total_podcasts'] ?? 0).toString(),
              color: const Color(0xFF6366F1),
              onTap: () => widget.onNavigateToTab?.call(1, contentFilter: 'Podcasts'),
            ),
            _buildStatCard(
              icon: Icons.movie,
              label: 'Movies',
              value: (_stats?['total_movies'] ?? 0).toString(),
              color: const Color(0xFF8B5CF6),
              onTap: () => widget.onNavigateToTab?.call(1, contentFilter: 'Movies'),
            ),
            _buildStatCard(
              icon: Icons.library_music,
              label: 'Music',
              value: (_stats?['total_music'] ?? 0).toString(),
              color: const Color(0xFF10B981),
              onTap: () => widget.onNavigateToTab?.call(1, contentFilter: 'Music'),
            ),
            _buildStatCard(
              icon: Icons.article,
              label: 'Posts',
              value: (_stats?['total_posts'] ?? 0).toString(),
              color: const Color(0xFFF59E0B),
              onTap: () => widget.onNavigateToTab?.call(1, contentFilter: 'Posts'),
            ),
            _buildStatCard(
              icon: Icons.people,
              label: 'Total Users',
              value: (_stats?['total_users'] ?? 0).toString(),
              color: AppColors.warmBrown,
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            _buildStatCard(
              icon: Icons.videocam,
              label: 'Video',
              value: (_stats?['video_podcasts'] ?? _stats?['total_videos'] ?? 0).toString(),
              color: const Color(0xFFEC4899),
              onTap: () => widget.onNavigateToTab?.call(1, contentFilter: 'Podcasts'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTypography.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSection() {
    final pendingPodcasts = _stats?['pending_podcasts'] ?? 0;
    final pendingMovies = _stats?['pending_movies'] ?? 0;
    final pendingMusic = _stats?['pending_music'] ?? 0;
    final pendingPosts = _stats?['pending_posts'] ?? 0;
    final pendingEvents = _stats?['pending_events'] ?? 0;
    final totalPending = pendingPodcasts +
        pendingMovies +
        pendingMusic +
        pendingPosts +
        pendingEvents;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warningMain.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      color: AppColors.warningMain,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pending Approvals',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: totalPending > 0
                      ? AppColors.warningMain.withOpacity(0.1)
                      : AppColors.successMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalPending items',
                  style: AppTypography.caption.copyWith(
                    color: totalPending > 0 ? AppColors.warningMain : AppColors.successMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPendingItem('Podcasts', pendingPodcasts, Icons.podcasts, 'Podcasts'),
          _buildPendingItem('Movies', pendingMovies, Icons.movie, 'Movies'),
          _buildPendingItem('Music', pendingMusic, Icons.library_music, 'Music'),
          _buildPendingItem('Posts', pendingPosts, Icons.article, 'Posts'),
          _buildPendingItem('Events', pendingEvents, Icons.event, 'Events'),
        ],
      ),
    );
  }

  Widget _buildPendingItem(
    String label,
    int count,
    IconData icon,
    String contentFilter,
  ) {
    return InkWell(
      onTap: count > 0
          ? () => widget.onNavigateToTab?.call(
                1,
                contentFilter: contentFilter,
                contentTabIndex: 0,
              )
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0
                  ? AppColors.warmBrown.withOpacity(0.1)
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: count > 0 ? AppColors.warmBrown : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.warmBrown,
              ),
            ],
        ],
        ),
      ),
    );
  }

  Widget _buildContentOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Overview',
          style: AppTypography.heading3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildOverviewRow(
                'Bible Documents',
                (_stats?['total_documents'] ?? 0).toString(),
                Icons.menu_book,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDocumentsPage()),
                  );
                },
              ),
              const Divider(height: 24),
              _buildOverviewRow(
                'Support Tickets',
                (_stats?['open_support_tickets'] ?? 0).toString(),
                Icons.support_agent,
                subtitle: 'New: ${_stats?['unread_support_messages'] ?? 0}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminSupportPage()),
                  );
                },
              ),
              const Divider(height: 24),
              _buildOverviewRow(
                'Commission Settings',
                'Configure',
                Icons.percent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminCommissionSettingsPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 24),
              _buildOverviewRow(
                'All Donations',
                'View',
                Icons.volunteer_activism,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDonationsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewRow(String label, String value, IconData icon,
      {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.warmBrown, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: AppTypography.heading3.copyWith(
                color: AppColors.warmBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _calculateTotalPending() {
    if (_stats == null) return 0;
    return (_stats!['pending_podcasts'] ?? 0) +
        (_stats!['pending_movies'] ?? 0) +
        (_stats!['pending_music'] ?? 0) +
        (_stats!['pending_posts'] ?? 0);
  }
}
