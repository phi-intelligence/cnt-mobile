import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_provider.dart';
import '../../providers/artist_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/creator_provider.dart';
import '../../utils/format_utils.dart';
import '../admin_dashboard.dart';
import '../admin/admin_support_page.dart';
import '../user_login_screen.dart';
import '../edit_profile_screen.dart';
import '../bank_details_screen.dart';
import '../support/support_center_screen.dart';
import '../artist/artist_profile_manage_screen.dart';
import '../../utils/media_utils.dart';
import '../../utils/bank_details_helper.dart';
import 'favorites_screen_mobile.dart';
import 'downloads_screen_mobile.dart';
import 'notifications_screen_mobile.dart';
import 'about_screen_mobile.dart';
import 'billing_screen_mobile.dart';
import 'donation_history_screen_mobile.dart';
import '../../utils/app_logger.dart';

class ProfileScreenMobile extends StatefulWidget {
  const ProfileScreenMobile({super.key});

  @override
  State<ProfileScreenMobile> createState() => _ProfileScreenMobileState();
}

class _ProfileScreenMobileState extends State<ProfileScreenMobile> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    AppLogger.debug('✅ ProfileScreenMobile initState');
    // Fetch user data on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<UserProvider>().fetchUser();
        context.read<SupportProvider>().fetchStats();
        // Also try to fetch artist profile (will fail silently if user is not an artist)
        context.read<ArtistProvider>().fetchMyArtist();
      } catch (e) {
        AppLogger.debug('❌ ProfileScreenMobile: Error fetching user: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Consumer4<AuthProvider, UserProvider, SupportProvider, ArtistProvider>(
        builder: (context, authProvider, userProvider, supportProvider, artistProvider, child) {
          final profileUser = userProvider.user ?? authProvider.user;
          final isAdmin = authProvider.isAdmin;
          final avatarUrl = resolveMediaUrl(profileUser?['avatar'] as String?);
          final supportStats = supportProvider.stats;
          final openSupportCount = supportStats?.openCount ?? 0;
          final unreadSupportCount = isAdmin
              ? supportProvider.unreadAdminCount
              : supportProvider.unreadUserCount;
          final supportSubtitle = isAdmin
              ? 'Open tickets: $openSupportCount • New: $unreadSupportCount'
              : 'Open requests: $openSupportCount • Responses: $unreadSupportCount';

          return ListView(
            children: [
              // Profile Header with warmBrown theme
              Container(
                padding: EdgeInsets.fromLTRB(AppSpacing.large, AppSpacing.extraLarge, AppSpacing.large, AppSpacing.large),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (userProvider.isLoading)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 55,
                                      color: AppColors.warmBrown,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingAvatar ? null : _handleAvatarChange,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: _isUploadingAvatar
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: AppColors.warmBrown,
                                        size: 18,
                                      ),
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.large),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              profileUser?['name'] ?? 'Guest User',
                              style: AppTypography.heading2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profileUser?['email'] ?? '',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      // About Us and Donate buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // About Us button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutScreenMobile(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.warmBrown,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'About Us',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.warmBrown,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.medium),
                          // Donate button
                          GestureDetector(
                            onTap: () => showOrganizationDonationModal(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volunteer_activism,
                                    color: AppColors.warmBrown,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Donate',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.warmBrown,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.medium),

              // Creator section — Become a Creator or manage artist
              Consumer<CreatorProvider>(
                builder: (context, creatorProvider, _) {
                  final isReady = creatorProvider.isCreatorReady;
                  final hasArtist =
                      artistProvider.hasArtistProfile ||
                      artistProvider.myArtist != null;

                  if (creatorProvider.isLoading && !creatorProvider.hasLoaded) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.large),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.warmBrown,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Creator'),
                      if (isReady && hasArtist) ...[
                        _buildSettingTile(
                          icon: Icons.mic_external_on,
                          title: 'My Artist Profile',
                          subtitle: artistProvider.myArtist?.artistName ??
                              'Manage your creator profile',
                          iconColor: AppColors.primaryMain,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ArtistProfileManageScreen(),
                              ),
                            );
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.account_balance_outlined,
                          title: 'Payout Settings',
                          subtitle: 'Paystack bank or mobile money',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BankDetailsScreen(),
                              ),
                            );
                          },
                        ),
                      ] else if (isReady) ...[
                        _buildSettingTile(
                          icon: Icons.mic_external_on,
                          title: 'Manage Artist Profile',
                          subtitle: 'Set up your public artist page',
                          iconColor: AppColors.primaryMain,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ArtistProfileManageScreen(),
                              ),
                            );
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.account_balance_outlined,
                          title: 'Payout Settings',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BankDetailsScreen(),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        _buildSettingTile(
                          icon: Icons.star_outline,
                          title: 'Become a Creator',
                          subtitle:
                              'Set up Paystack payouts to publish content',
                          iconColor: AppColors.warmBrown,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BankDetailsScreen(
                                  isFromCreator: true,
                                ),
                              ),
                            ).then((_) => creatorProvider.refresh());
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.small),
                    ],
                  );
                },
              ),

              // Account Section
              _buildSectionTitle('Account'),
              _buildSettingTile(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.volunteer_activism_outlined,
                title: 'Donation History',
                subtitle: 'Sent and received donations',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DonationHistoryScreenMobile(),
                    ),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.card_membership_outlined,
                title: 'Subscription & Billing',
                subtitle: 'Manage your CNT subscription',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BillingScreenMobile(),
                    ),
                  );
                },
              ),
              _buildSettingTile(
                icon: isAdmin ? Icons.support_agent : Icons.help_outline,
                title: isAdmin ? 'Support Inbox' : 'Help & Support',
                subtitle: supportSubtitle,
                trailing: _buildSupportTrailing(unreadSupportCount),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          isAdmin ? const AdminSupportPage() : const SupportCenterScreen(),
                    ),
                  ).then((_) {
                    supportProvider.fetchStats();
                    if (isAdmin) {
                      supportProvider.fetchAdminMessages();
                    } else {
                      supportProvider.fetchMyMessages();
                    }
                  });
                },
              ),

              const SizedBox(height: AppSpacing.small),

              // My Content Section
              _buildSectionTitle('My Content'),
              _buildSettingTile(
                icon: Icons.favorite,
                title: 'Favorites',
                subtitle: 'Your liked content',
                iconColor: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FavoritesScreenMobile(),
                    ),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.download,
                title: 'Downloads',
                subtitle: 'Offline content',
                iconColor: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadsScreenMobile(),
                    ),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'View all notifications',
                iconColor: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreenMobile(),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.small),

              // Admin Section (only for admins)
              if (isAdmin) ...[
                _buildSectionTitle('Admin'),
                _buildSettingTile(
                  icon: Icons.dashboard,
                  title: 'Admin Dashboard',
                  iconColor: Colors.red.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.small),
              ],

              const SizedBox(height: AppSpacing.small),

              _buildSettingTile(
                icon: Icons.logout,
                title: 'Logout',
                titleColor: AppColors.errorMain,
                onTap: () async {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const UserLoginScreen()),
                      (route) => false,
                  );
                  }
                },
              ),

              const SizedBox(height: AppSpacing.extraLarge),
            ],
          );
        },
      ),
    );
  }

  String _formatMemberSince(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return FormatUtils.formatRelativeTime(date);
    } catch (e) {
      return 'Recently';
    }
  }

  Future<void> _handleAvatarChange() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final fileName = image.name;
      String? filePath;
      List<int>? bytes;

      if (kIsWeb) {
        bytes = await image.readAsBytes();
      } else {
        filePath = image.path;
      }

      final userProvider = context.read<UserProvider>();
      final newUrl = await userProvider.uploadAvatar(
        fileName: fileName,
        filePath: filePath,
        bytes: bytes,
      );

      if (newUrl != null && mounted) {
        await context.read<AuthProvider>().updateCachedUser({'avatar': newUrl});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update avatar: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.small,
      ),
      child: Text(
        title,
        style: AppTypography.heading4.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warmBrown.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.warmBrown).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.warmBrown, size: 22),
        ),
        title: Text(
          title,
          style: AppTypography.body.copyWith(
            color: titleColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        trailing: trailing ??
            Icon(
              Icons.chevron_right,
              color: AppColors.warmBrown.withOpacity(0.5),
            ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSupportTrailing(int unreadCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.errorMain,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unreadCount.toString(),
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (unreadCount > 0) const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ],
    );
  }
}
