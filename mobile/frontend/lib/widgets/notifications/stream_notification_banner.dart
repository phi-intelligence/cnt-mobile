import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/livekit_meeting_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../screens/meeting/prejoin_screen.dart';

/// Stream Notification Banner
/// Displays when a live stream starts
class StreamNotificationBanner extends StatelessWidget {
  const StreamNotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        if (!notificationProvider.hasNotification) {
          return const SizedBox.shrink();
        }

        final notification = notificationProvider.currentNotification!;

        return Container(
          margin: const EdgeInsets.all(AppSpacing.medium),
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.primaryMain,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Live indicator
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${notification.hostName} started a live stream',
                      style: AppTypography.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.streamTitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // Join button - wrap in Flexible to prevent infinite width
              Flexible(
                child: ElevatedButton(
                  onPressed: () => _handleJoinStream(context, notification),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                  ),
                  child: Text(
                    'Join',
                    style: AppTypography.button.copyWith(
                      color: AppColors.primaryMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              // Dismiss button
              IconButton(
                onPressed: () => notificationProvider.dismissNotification(),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleJoinStream(
    BuildContext context,
    LiveStreamNotification notification,
  ) async {
    try {
      // Generate identity for participant
      final identity = 'participant-${DateTime.now().millisecondsSinceEpoch}';
      final userName = 'Participant';

      // Get LiveKit token for participant
      final meetingSvc = LiveKitMeetingService();
      final joinResp = await meetingSvc.fetchTokenForMeeting(
        streamOrMeetingId: notification.streamId,
        userIdentity: identity,
        userName: userName,
        isHost: false, // Participant, not host
      );

      if (!context.mounted) return;

      // Dismiss notification
      context.read<NotificationProvider>().dismissNotification();

      // Navigate to prejoin screen (mic/cam OFF by default for participants)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrejoinScreen(
            meetingId: notification.streamId.toString(),
            jitsiUrl: joinResp.url,
            jwtToken: joinResp.token,
            roomName: joinResp.roomName,
            userName: userName,
            isHost: false,
            initialCameraEnabled: false, // Camera OFF for participants
            initialMicEnabled: false, // Mic OFF for participants
            isLiveStream: true, // Mark as live stream
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join stream: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

