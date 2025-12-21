import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';
import '../../services/api_service.dart';
import '../../utils/format_utils.dart';

/// Mobile Notifications Screen - Shows user notifications with full API integration
class NotificationsScreenMobile extends StatefulWidget {
  const NotificationsScreenMobile({super.key});

  @override
  State<NotificationsScreenMobile> createState() => _NotificationsScreenMobileState();
}

class _NotificationsScreenMobileState extends State<NotificationsScreenMobile> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Read'];
  int _totalCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.getNotifications(
        limit: 50,
        unreadOnly: _filter == 'Unread',
      );

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response['notifications'] ?? []);
          _totalCount = response['total'] ?? 0;
          _unreadCount = response['unread_count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications';
      _isLoading = false;
    });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_filter == 'All') return _notifications;
    if (_filter == 'Unread') {
      return _notifications.where((n) => n['read'] != true).toList();
    }
    return _notifications.where((n) => n['read'] == true).toList();
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await _api.markNotificationsAsRead([notificationId]);
      
    setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
          _notifications[index]['read'] = true;
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
    });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.markAllNotificationsAsRead();
      
    setState(() {
      for (var notification in _notifications) {
          notification['read'] = true;
      }
        _unreadCount = 0;
    });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All notifications marked as read'),
            backgroundColor: AppColors.successMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: AppColors.errorMain,
          ),
      );
      }
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await _api.deleteNotification(notificationId);
      
    setState(() {
        final notification = _notifications.firstWhere(
          (n) => n['id'] == notificationId,
          orElse: () => {},
        );
        if (notification.isNotEmpty && notification['read'] != true) {
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
        _notifications.removeWhere((n) => n['id'] == notificationId);
        _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
      });
    } catch (e) {
      print('❌ Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read if unread
    if (notification['read'] != true) {
      _markAsRead(notification['id'] as int);
    }

    // Navigate based on notification type
    final type = notification['type'] as String?;
    final data = notification['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'live_stream':
      case 'live_stream_started':
        // Navigate to live stream
        final streamId = data?['stream_id'];
        if (streamId != null) {
          // TODO: Navigate to live stream
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening live stream...')),
          );
        }
        break;
      case 'new_content':
      case 'podcast':
        // Navigate to content
        final contentId = data?['content_id'] ?? data?['podcast_id'];
        if (contentId != null) {
          // TODO: Navigate to content
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening content...')),
          );
        }
        break;
      case 'comment':
      case 'like':
        // Navigate to community post
        final postId = data?['post_id'];
        if (postId != null) {
          // TODO: Navigate to post
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening post...')),
          );
        }
        break;
      case 'event':
        // Navigate to event
        final eventId = data?['event_id'];
        if (eventId != null) {
          // TODO: Navigate to event
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening event...')),
          );
        }
        break;
      default:
        // Just mark as read
        break;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'new_content':
      case 'podcast':
        return Icons.new_releases;
      case 'live':
      case 'live_stream':
      case 'live_stream_started':
        return Icons.live_tv;
      case 'event':
        return Icons.event;
      case 'donation':
        return Icons.volunteer_activism;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return AppColors.primaryMain;
      case 'new_content':
      case 'podcast':
        return AppColors.accentMain;
      case 'live':
      case 'live_stream':
      case 'live_stream_started':
        return Colors.green;
      case 'event':
        return Colors.purple;
      case 'donation':
        return Colors.amber;
      case 'system':
        return Colors.orange;
      default:
        return AppColors.warmBrown;
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: AppTypography.heading3.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Read all',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warmBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = filter == _filter;
                  int count = 0;
                  if (filter == 'All') count = _totalCount;
                  if (filter == 'Unread') count = _unreadCount;
                  if (filter == 'Read') count = _totalCount - _unreadCount;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.small),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _filter = filter);
                        if (filter == 'Unread') {
                          _loadNotifications();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.warmBrown : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.warmBrown
                                : AppColors.warmBrown.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.warmBrown.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Text(
                          count > 0 ? '$filter ($count)' : filter,
                        style: AppTypography.bodySmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.warmBrown,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Notifications List
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.small),
                        child: LoadingShimmer(width: double.infinity, height: 80),
                      );
                    },
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
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadNotifications,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warmBrown,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ],
                        ),
                  )
                : _filteredNotifications.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none,
                        title: _filter == 'All' 
                            ? 'No Notifications' 
                            : 'No ${_filter} Notifications',
                        message: _filter == 'All'
                                ? "You're all caught up!"
                            : 'No notifications in this category',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                            color: AppColors.warmBrown,
                        child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.medium,
                              ),
                          itemCount: _filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            return _buildNotificationItem(notification);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final id = notification['id'] as int;
    final type = notification['type'] as String? ?? 'system';
    final title = notification['title'] as String? ?? 'Notification';
    final message = notification['message'] as String? ?? '';
    final isRead = notification['read'] == true;
    final createdAtStr = notification['created_at'] as String?;
    DateTime? createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (e) {
        // Ignore parse errors
      }
    }

    return Dismissible(
      key: Key('notification_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.large),
        margin: const EdgeInsets.only(bottom: AppSpacing.small),
        decoration: BoxDecoration(
          color: AppColors.errorMain,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.small),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.warmBrown.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? AppColors.warmBrown.withOpacity(0.15)
                : AppColors.warmBrown.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleNotificationTap(notification),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                      color: _getNotificationColor(type).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getNotificationIcon(type),
              color: _getNotificationColor(type),
              size: 24,
            ),
          ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                  color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isRead)
                Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                                  color: AppColors.warmBrown,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
                        const SizedBox(height: 4),
              Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                    FormatUtils.formatRelativeTime(createdAt),
                    style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                    ),
                          ),
                        ],
                      ],
                  ),
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
