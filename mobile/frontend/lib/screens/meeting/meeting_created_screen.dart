import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'meeting_room_screen.dart';
import '../../services/livekit_meeting_service.dart';
import 'prejoin_screen.dart';

/// Meeting Created Screen
/// Shows meeting details with share options and join button
class MeetingCreatedScreen extends StatefulWidget {
  final String meetingId;
  final String meetingLink;
  final bool isInstant;

  const MeetingCreatedScreen({
    super.key,
    required this.meetingId,
    required this.meetingLink,
    this.isInstant = true,
  });

  @override
  State<MeetingCreatedScreen> createState() => _MeetingCreatedScreenState();
}

class _MeetingCreatedScreenState extends State<MeetingCreatedScreen> {
  bool _isCopied = false;
  bool _joining = false;
  String? _joinError;

  void _handleBack() {
    Navigator.pop(context);
  }

  Future<void> _handleJoinMeeting() async {
    setState(() { _joining = true; _joinError = null; });
    try {
      // Validate meetingId is a valid numeric ID from backend
      final meetingIdInt = int.tryParse(widget.meetingId);
      if (meetingIdInt == null || meetingIdInt <= 0) {
        throw Exception('Invalid meeting ID: ${widget.meetingId}');
      }
      
      final identity = 'host-user-${DateTime.now().millisecondsSinceEpoch}';
      final userName = 'Host';
      final meetingSvc = LiveKitMeetingService();
      final joinResp = await meetingSvc.fetchTokenForMeeting(
        streamOrMeetingId: meetingIdInt,
        userIdentity: identity,
        userName: userName,
        isHost: true,
      );
      setState(() { _joining = false; });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrejoinScreen(
            meetingId: widget.meetingId,
            jitsiUrl: joinResp.url, // Contains LiveKit URL from backend
            jwtToken: joinResp.token,
            roomName: joinResp.roomName,
            userName: userName,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      setState(() { _joining = false; _joinError = e.toString(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join meeting: $e')),
        );
      }
    }
  }

  void _handleCopyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.meetingLink));
    setState(() {
      _isCopied = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard!')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  Future<void> _handleShare() async {
    try {
      await Share.share(
        'Join my meeting!\n\nMeeting ID: ${widget.meetingId}\nLink: ${widget.meetingLink}',
        subject: 'Join Meeting - CNT Media Platform',
      );
    } catch (e) {
      if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
    );
      }
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
          onPressed: _handleBack,
        ),
        title: Text(
          'Meeting Created',
          style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          const SizedBox(width: 40), // Balance leading icon
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            children: [
              // Meeting Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.video_call,
                  size: 48,
                  color: AppColors.primaryMain,
                ),
              ),
              const SizedBox(height: AppSpacing.large),

              // Meeting Title
              Text(
                widget.isInstant ? 'Instant Meeting' : 'Scheduled Meeting',
                style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.tiny),

              // Meeting ID
              Text(
                'Meeting ID: ${widget.meetingId}',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.large),

              // Meeting Link
              Container(
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Link:',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.tiny),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.meetingLink,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.small),
                        IconButton(
                          icon: Icon(
                            _isCopied ? Icons.check : Icons.copy,
                            color: AppColors.primaryMain,
                          ),
                          onPressed: _handleCopyLink,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.large),

              // Share Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Meeting Link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
                    side: BorderSide(color: AppColors.primaryMain, width: 2),
                    foregroundColor: AppColors.primaryMain,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.large),

              // Join Meeting Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleJoinMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_call, color: Colors.white),
                      const SizedBox(width: AppSpacing.small),
                      Text(
                        'Join Meeting',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

