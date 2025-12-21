import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';

/// Custom meeting controls widget for LiveKit meetings
class MeetingControls extends StatelessWidget {
  final lk.Room room;
  final VoidCallback onLeave;
  final bool isHost;
  final VoidCallback? onShowParticipants;
  final VoidCallback? onPresent;
  final VoidCallback? onToggleChat;
  final bool isLiveStream;
  final VoidCallback? onRequestSpeak;

  const MeetingControls({
    super.key,
    required this.room,
    required this.onLeave,
    this.isHost = false,
    this.onShowParticipants,
    this.onPresent,
    this.onToggleChat,
    this.isLiveStream = false,
    this.onRequestSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<lk.Room>(
      stream: Stream.value(room),
      builder: (context, snapshot) {
        final isMicEnabled = localParticipant.isMicrophoneEnabled();
        final isCameraEnabled = localParticipant.isCameraEnabled();

        // Using dark warm brown theme for meeting controls
        const meetingControlsBg = Color(0xFF3D2E25);
        
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: meetingControlsBg,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: AppColors.warmBrown.withOpacity(0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // For live streams: show "Request to Speak" for participants when mic is off
                      // Otherwise show normal mic toggle
                      if (isLiveStream && !isHost && !isMicEnabled && onRequestSpeak != null)
                        _buildRoundButton(
                          icon: Icons.mic_external_on,
                          tooltip: 'Request to speak',
                          background: Colors.orange.withOpacity(0.2),
                          iconColor: Colors.orange,
                          onPressed: onRequestSpeak!,
                        )
                      else
                        _buildRoundButton(
                          icon: isMicEnabled ? Icons.mic : Icons.mic_off,
                          tooltip: isMicEnabled ? 'Mute microphone' : 'Unmute microphone',
                          background: isMicEnabled ? Colors.white12 : Colors.red.withOpacity(0.2),
                          iconColor: isMicEnabled ? Colors.white : Colors.red,
                          onPressed: () async {
                            try {
                              await localParticipant.setMicrophoneEnabled(!isMicEnabled);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to toggle microphone: $e')),
                                );
                              }
                            }
                          },
                        ),
                      const SizedBox(width: 12),
                      _buildRoundButton(
                        icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                        tooltip: isCameraEnabled ? 'Turn camera off' : 'Turn camera on',
                        background: isCameraEnabled ? Colors.white12 : Colors.red.withOpacity(0.2),
                        iconColor: isCameraEnabled ? Colors.white : Colors.red,
                        onPressed: () async {
                          try {
                            await localParticipant.setCameraEnabled(!isCameraEnabled);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to toggle camera: $e')),
                              );
                            }
                          }
                        },
                      ),
                      if (onPresent != null) ...[
                        const SizedBox(width: 12),
                        _buildRoundButton(
                          icon: Icons.screen_share,
                          tooltip: 'Present screen',
                          background: Colors.white12,
                          iconColor: Colors.white,
                          onPressed: onPresent!,
                        ),
                      ],
                      const SizedBox(width: 12),
                      _buildRoundButton(
                        icon: Icons.call_end,
                        tooltip: 'Leave call',
                        background: Colors.red.shade600,
                        iconColor: Colors.white,
                        onPressed: onLeave,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onShowParticipants != null)
                      _buildUtilityChip(
                        icon: Icons.people_outline,
                        label: isHost ? 'People (host)' : 'People',
                        onTap: onShowParticipants!,
                      ),
                    if (onToggleChat != null) ...[
                      const SizedBox(width: 8),
                      _buildUtilityChip(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        onTap: onToggleChat!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: iconColor),
          iconSize: 28,
          onPressed: onPressed,
          padding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildUtilityChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.warmBrown.withOpacity(0.25),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.warmBrown.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

