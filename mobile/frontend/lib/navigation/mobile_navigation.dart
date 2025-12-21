import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../screens/mobile/home_screen_mobile.dart';
import '../screens/mobile/search_screen_mobile.dart';
import '../screens/mobile/create_screen_mobile.dart';
import '../screens/mobile/community_screen_mobile.dart';
import '../screens/mobile/profile_screen_mobile.dart';
import '../widgets/media/sliding_audio_player.dart';
import '../widgets/meeting/pip_meeting_overlay.dart';
import '../providers/audio_player_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/support_provider.dart';
import '../widgets/notifications/stream_notification_banner.dart';
import '../utils/platform_utils.dart';
import '../theme/app_colors.dart';

/// Mobile Navigation Layout - 5 tabs matching React Native exactly
/// Tabs: Home, Search, Plus/Create, Community, Profile
class MobileNavigationLayout extends StatefulWidget {
  const MobileNavigationLayout({super.key});

  @override
  State<MobileNavigationLayout> createState() => MobileNavigationLayoutState();
  
  static MobileNavigationLayoutState? of(BuildContext context) {
    return context.findAncestorStateOfType<MobileNavigationLayoutState>();
  }
}

class MobileNavigationLayoutState extends State<MobileNavigationLayout> {
  int _currentIndex = 0;
  final GlobalKey<SlidingAudioPlayerState> _playerKey = GlobalKey<SlidingAudioPlayerState>();
  int? _communityPostId; // Store postId for community screen

  List<Widget> get _screens => [
    const HomeScreenMobile(),
    const SearchScreenMobile(),
    const CreateScreenMobile(),
    CommunityScreenMobile(postId: _communityPostId),
    const ProfileScreenMobile(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final supportProvider = context.read<SupportProvider>();
      supportProvider.fetchStats();
      if (authProvider.isAdmin) {
        supportProvider.fetchAdminMessages();
      } else {
        supportProvider.fetchMyMessages();
      }
    });
  }

  /// Navigate to community tab with optional postId
  void navigateToCommunityWithPost(int? postId) {
    setState(() {
      _communityPostId = postId;
      _currentIndex = 3; // Community tab index
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    // Account for SafeArea padding - reduce by a few pixels to prevent overflow
    final tabBarHeight = PlatformUtils.isIOS
        ? (isSmallScreen ? 98 : 93)
        : 73;

    final safeBottomInset = MediaQuery.of(context).padding.bottom;

    final isAdmin = context.select<AuthProvider, bool>((provider) => provider.isAdmin);
    final adminSupportCount = isAdmin
        ? context.watch<SupportProvider>().unreadAdminCount
        : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          // Check if player is expanded
          final playerState = _playerKey.currentState;
          if (playerState != null && playerState.isExpanded) {
            // Minimize player instead of exiting
            playerState.minimizePlayer();
            return; // Don't navigate or exit, just minimize player
          }
          
          // If not on home page (index 0), navigate to home
          if (_currentIndex != 0) {
            setState(() {
              _currentIndex = 0;
            });
          } else {
            // Already on home page, exit the app
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        extendBody: true, // Allow content to extend behind navbar/player
        body: Stack(
          fit: StackFit.expand, // Ensure full screen bounds for proper positioning
          children: [
            // Screen content
            _screens[_currentIndex],
            // Notification banner at top
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StreamNotificationBanner(),
            ),
            // Sliding audio player overlay at bottom (above navbar)
            // ONLY show on Home page (index 0)
            Consumer<AudioPlayerState>(
              builder: (context, audioPlayer, child) {
                // Only show on homepage AND if there's a current track
                if (_currentIndex != 0 || audioPlayer.currentTrack == null) {
                  return const SizedBox.shrink();
                }
                
                final playerState = _playerKey.currentState;
                final isExpanded = playerState?.isExpanded ?? false;
                
                // Position player at bottom
                // When expanded: fill full screen (bottom: 0)
                // When minimized: position directly above navbar (navbar is at bottom: 0, player sits above it)
                final minimizedBottom = tabBarHeight + safeBottomInset;
                final compactBottom = minimizedBottom > 4 ? minimizedBottom - 4 : 0.0;
                return Positioned(
                  bottom: isExpanded ? 0.0 : compactBottom,
                  left: 0.0,
                  right: 0.0,
                  child: SlidingAudioPlayer(key: _playerKey),
                );
              },
            ),
            // PiP Meeting Overlay (shown when user navigates away from meeting)
            Consumer<PipMeetingManager>(
              builder: (context, pipManager, child) {
                if (!pipManager.isInPipMode) {
                  return const SizedBox.shrink();
                }
                return PipMeetingOverlay(
                  localVideoTrack: pipManager.localVideoTrack,
                  remoteVideoTrack: pipManager.remoteVideoTrack,
                  onExpand: () => pipManager.onExpand?.call(),
                  onEnd: () => pipManager.onEnd?.call(),
                  isHost: pipManager.isHost,
                  meetingTitle: pipManager.meetingTitle,
                  duration: pipManager.duration,
                  isCameraEnabled: pipManager.isCameraEnabled,
                  isMicEnabled: pipManager.isMicEnabled,
                  onToggleCamera: pipManager.onToggleCamera,
                  onToggleMic: pipManager.onToggleMic,
                );
              },
            ),
          ],
        ),
      bottomNavigationBar: 
        // Hide bottom nav when player is expanded, show when minimized
        Builder(
          builder: (context) {
            final audioPlayer = context.watch<AudioPlayerState>();
            
            // Listen to player expansion state changes
            return ValueListenableBuilder<bool>(
              valueListenable: SlidingAudioPlayerState.expansionStateNotifier,
              builder: (context, isExpanded, child) {
                // Show navbar if:
                // 1. No track playing, OR
                // 2. Track playing but player is minimized (not expanded)
                final shouldShowNav = audioPlayer.currentTrack == null || !isExpanded;
                return shouldShowNav ? SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              border: const Border(
                top: BorderSide(
                  color: AppColors.borderPrimary,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.primaryMain,
            unselectedItemColor: AppColors.textSecondary,
            selectedLabelStyle: TextStyle(
              fontSize: isSmallScreen ? 8 : (PlatformUtils.isIOS ? 10 : 9),
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: isSmallScreen ? 8 : (PlatformUtils.isIOS ? 10 : 9),
              fontWeight: FontWeight.w500,
            ),
            iconSize: PlatformUtils.isIOS ? 26 : 22,
            items: [
          BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                activeIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_rounded),
                activeIcon: Icon(Icons.add_circle_rounded),
                label: 'Create',
          ),
          BottomNavigationBarItem(
                icon: Icon(Icons.people_rounded),
                activeIcon: Icon(Icons.people_rounded),
            label: 'Community',
          ),
          BottomNavigationBarItem(
                icon: _buildProfileIcon(adminSupportCount),
                activeIcon: _buildProfileIcon(adminSupportCount),
            label: 'Profile',
          ),
        ],
            ),
          ),
        ) : const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileIcon(int badgeCount) {
    if (badgeCount <= 0) {
      return const Icon(Icons.person_rounded);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.person_rounded),
        Positioned(
          right: -6,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.errorMain,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

