import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/support_message.dart';
import '../../providers/support_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../../widgets/shared/pill_text_field.dart';

/// Admin Support Page - Redesigned with cream/brown theme
/// View and respond to user support tickets
class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  String? _statusFilter;
  final Map<int, TextEditingController> _replyControllers = {};
  final Map<int, bool> _isReplying = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SupportProvider>();
      provider.fetchStats();
      provider.fetchAdminMessages();
    });
  }

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final provider = context.read<SupportProvider>();
    await provider.fetchStats();
    await provider.fetchAdminMessages(status: _statusFilter);
  }

  Future<void> _submitReply(SupportMessage message) async {
    final controller =
        _replyControllers.putIfAbsent(message.id, () => TextEditingController());
    final response = controller.text.trim();
    if (response.isEmpty) {
      _showSnackBar('Enter a reply before sending');
      return;
    }

    setState(() {
      _isReplying[message.id] = true;
    });

    try {
      await context.read<SupportProvider>().replyToMessage(
            messageId: message.id,
            response: response,
            status: 'responded',
          );
      controller.clear();
      if (!mounted) return;
      _showSnackBar('Response sent to user', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to reply: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isReplying.remove(message.id);
        });
      }
    }
  }

  Future<void> _markRead(SupportMessage message) async {
    await context
        .read<SupportProvider>()
        .markMessageAsRead(messageId: message.id, forAdmin: true);
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? AppColors.successMain
            : isError
                ? AppColors.errorMain
                : AppColors.warmBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: AppColors.warmBrown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Support Tickets',
          style: AppTypography.heading3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.warmBrown,
        child: Consumer<SupportProvider>(
          builder: (context, provider, _) {
            final messages = provider.adminMessages;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsRow(provider),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                if (provider.isAdminLoading && messages.isEmpty)
                  _buildLoadingState()
                else if (messages.isEmpty)
                  _buildEmptyState()
                else
                  ...messages.map(_buildMessageCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(SupportProvider provider) {
    final stats = provider.stats;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total',
            value: stats?.total.toString() ?? '-',
            color: AppColors.warmBrown,
            icon: Icons.inbox,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Open',
            value: stats?.openCount.toString() ?? '-',
            color: const Color(0xFFF59E0B),
            icon: Icons.mark_email_unread,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'New',
            value: stats?.unreadAdminCount.toString() ?? '-',
            color: const Color(0xFF6366F1),
            icon: Icons.fiber_new,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.heading2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildFilters() {
    final filters = <String?, String>{
      null: 'All',
      'open': 'Open',
      'responded': 'Responded',
      'closed': 'Closed',
    };

    return Wrap(
      spacing: 8,
      children: filters.entries.map((entry) {
        final isSelected = _statusFilter == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() {
              _statusFilter = entry.key;
            });
            context
                .read<SupportProvider>()
                .fetchAdminMessages(status: _statusFilter);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.warmBrown : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected ? AppColors.warmBrown : AppColors.warmBrown.withOpacity(0.2),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.warmBrown.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              entry.value,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.warmBrown,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading tickets...',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.support_agent,
              size: 40,
              color: AppColors.warmBrown.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No tickets found',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No support requests match this filter.',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(SupportMessage message) {
    final controller =
        _replyControllers.putIfAbsent(message.id, () => TextEditingController());
    final isReplying = _isReplying[message.id] ?? false;
    final user = message.user;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: user?.avatar != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            user!.avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(user.name ?? 'U'),
                          ),
                        )
                      : _buildAvatarPlaceholder(user?.name ?? 'U'),
                ),
                const SizedBox(width: 12),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Unknown User',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status Badge
                _buildStatusBadge(message.status),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: AppColors.warmBrown.withOpacity(0.1)),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.subject,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Time & Mark Read
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.formatRelativeTime(message.createdAt.toLocal()),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!message.adminSeen)
                      TextButton.icon(
                        onPressed: () => _markRead(message),
                        icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                        label: const Text('Mark read'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warmBrown,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                // Previous Response
                if ((message.adminResponse ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warmBrown.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.reply,
                              size: 16,
                              color: AppColors.warmBrown,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Your Response',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.warmBrown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message.adminResponse!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Reply Section
          Divider(height: 1, color: AppColors.warmBrown.withOpacity(0.1)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write your reply...',
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isReplying ? null : () => _submitReply(message),
                    icon: isReplying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(isReplying ? 'Sending...' : 'Send Reply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warmBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTypography.heading3.copyWith(
          color: AppColors.warmBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'closed':
        color = AppColors.successMain;
        label = 'Resolved';
        break;
      case 'responded':
        color = const Color(0xFF6366F1);
        label = 'Responded';
        break;
      default:
        color = const Color(0xFFF59E0B);
        label = 'Open';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
