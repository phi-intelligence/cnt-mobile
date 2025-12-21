import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../screens/mobile/home_screen_mobile.dart';
import '../screens/mobile/search_screen_mobile.dart';
import '../screens/mobile/live_screen_mobile.dart';
import '../screens/mobile/community_screen_mobile.dart';
import '../screens/mobile/profile_screen_mobile.dart';

/// Main Bottom Tab Navigation - Exact replica of React Native implementation
/// 5 tabs: Home, Search, Live, Community, Profile
class MainBottomTabNavigation extends StatelessWidget {
  const MainBottomTabNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = PlatformUtils.isIOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: TabBarView(
          children: const [
            HomeScreenMobile(),
            SearchScreenMobile(),
            LiveScreenMobile(),
            CommunityScreenMobile(),
            ProfileScreenMobile(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            border: Border(
              top: BorderSide(
                color: AppColors.borderPrimary,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: isIOS
                  ? (isSmallScreen ? 90 : 85)
                  : 60,
              child: TabBar(
                indicator: const BoxDecoration(),
                labelPadding: const EdgeInsets.all(0),
                tabs: [
                  _buildTab(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: true,
                  ),
                  _buildTab(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    isActive: false,
                  ),
                  _buildTab(
                    icon: Icons.radio_rounded,
                    label: 'Live',
                    isActive: false,
                  ),
                  _buildTab(
                    icon: Icons.people_rounded,
                    label: 'Community',
                    isActive: false,
                  ),
                  _buildTab(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isActive: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      padding: EdgeInsets.only(
        top: PlatformUtils.isIOS ? 8 : 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primaryMain : AppColors.textSecondary,
            size: PlatformUtils.isIOS ? 28 : 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: PlatformUtils.isIOS
                  ? (label == 'Home' ? 11 : 10)
                  : 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.primaryMain : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

