import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../live/live_stream_start_screen.dart';
import '../live/live_stream_viewer.dart';

/// Live Screen - Exact replica of React Native implementation
/// Features tabs for Live, Upcoming, and Past streams
class LiveScreenMobile extends StatefulWidget {
  const LiveScreenMobile({super.key});

  @override
  State<LiveScreenMobile> createState() => _LiveScreenMobileState();
}

class StreamData {
  final String id;
  final String title;
  final String hostName;
  final int? viewerCount;
  final String status; // 'live', 'scheduling', 'ended', 'archived'

  StreamData({
    required this.id,
    required this.title,
    required this.hostName,
    this.viewerCount,
    required this.status,
  });
}

class _LiveScreenMobileState extends State<LiveScreenMobile> with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0 = live, 1 = upcoming, 2 = past
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  late TabController _tabController;
  
  // Mock data
  final List<StreamData> _liveStreams = [
    StreamData(
      id: '1',
      title: 'Sunday Service - Morning Worship',
      hostName: 'Pastor John',
      viewerCount: 245,
      status: 'live',
    ),
    StreamData(
      id: '2',
      title: 'Bible Study - Book of Genesis',
      hostName: 'Elder Mary',
      viewerCount: 189,
      status: 'live',
    ),
  ];
  
  final List<StreamData> _upcomingStreams = [
    StreamData(
      id: '3',
      title: 'Evening Prayer Meeting',
      hostName: 'Brother James',
      status: 'scheduling',
    ),
    StreamData(
      id: '4',
      title: 'Youth Fellowship',
      hostName: 'Sister Sarah',
      status: 'scheduling',
    ),
  ];
  
  final List<StreamData> _pastStreams = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStreams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchStreams();
    setState(() {
      _isRefreshing = false;
    });
  }

  void _handleGoLive() {
    // Navigate to stream setup screen instead of auto-starting
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiveStreamStartScreen(),
      ),
    );
  }

  void _handleJoinStream(StreamData stream) {
    // Navigate to stream viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamViewer(
          streamId: stream.id,
          streamTitle: stream.title,
          hostName: stream.hostName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header with warmBrown themed Go Live button
            Container(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Streaming',
                          style: AppTypography.heading2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Broadcast to your community',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleGoLive,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmBrown.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Go Live',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Error message
          if (_error != null)
            Container(
              margin: EdgeInsets.all(AppSpacing.medium),
              padding: EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: AppColors.errorMain.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.errorMain.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.errorMain, size: 20),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.errorMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Tab Navigation - Pill-shaped warmBrown themed
          Container(
            margin: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: (index) {
                  setState(() {
                    _activeTab = index;
                  });
                },
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.warmBrown,
                indicator: BoxDecoration(
                  color: AppColors.warmBrown,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors, size: 16),
                        const SizedBox(width: 4),
                        const Text('Live'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 4),
                        const Text('Upcoming'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 16),
                        const SizedBox(width: 4),
                        const Text('Past'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.medium),

          // Tab Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _buildTabContent(),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryMain),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Loading streams...',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Get streams for current tab
    List<StreamData> streams;
    String emptyMessage;
    IconData emptyIcon;

    switch (_activeTab) {
      case 0:
        streams = _liveStreams;
        emptyMessage = 'No live streams right now';
        emptyIcon = Icons.videocam_off;
        break;
      case 1:
        streams = _upcomingStreams;
        emptyMessage = 'No upcoming streams';
        emptyIcon = Icons.schedule;
        break;
      default:
        streams = _pastStreams;
        emptyMessage = 'No past recordings';
        emptyIcon = Icons.archive;
    }

    // Show empty state if no streams
    if (streams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              emptyMessage,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Display stream cards
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: streams.map((stream) {
          return _buildStreamCard(
            stream: stream,
            title: stream.title,
            hostName: stream.hostName,
            isLive: stream.status == 'live',
            isUpcoming: stream.status == 'scheduling',
            viewerCount: stream.viewerCount,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStreamCard({
    required StreamData stream,
    required String title,
    required String hostName,
    bool isLive = false,
    bool isUpcoming = false,
    int? viewerCount,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusMedium),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.videocam,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  hostName,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                
                // Status badge and viewer count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.small,
                        vertical: AppSpacing.tiny,
                      ),
                      decoration: BoxDecoration(
                        color: isLive
                            ? AppColors.errorMain.withOpacity(0.2)
                            : isUpcoming
                                ? AppColors.primaryMain.withOpacity(0.2)
                                : AppColors.textSecondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Row(
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.errorMain,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppColors.errorMain,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          if (isUpcoming) ...[
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: AppColors.primaryMain,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'UPCOMING',
                              style: TextStyle(
                                color: AppColors.primaryMain,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (viewerCount != null && isLive)
                      Text(
                        '$viewerCount viewers',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                
                // Action button
                const SizedBox(height: AppSpacing.medium),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLive ? () => _handleJoinStream(stream) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLive ? AppColors.warmBrown : AppColors.textSecondary.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.small,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      isLive ? 'Join Stream' : 'Set Reminder',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
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
}
