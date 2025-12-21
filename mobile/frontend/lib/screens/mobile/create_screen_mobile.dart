import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/draft_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../creation/video_podcast_create_screen.dart';
import '../creation/audio_podcast_create_screen.dart';
import '../creation/audio_preview_screen.dart';
import '../creation/video_preview_screen.dart';
import '../community/create_post_screen.dart';
import 'meeting_options_screen_mobile.dart';
import '../live/live_stream_start_screen.dart';
import 'quote_create_screen_mobile.dart';
import '../events/events_list_screen.dart';
import 'drafts_list_screen.dart';
import '../../utils/bank_details_helper.dart';
import '../admin/bulk_upload_screen.dart';
import '../admin/bible_upload_screen.dart';

/// Plus/Create Screen - Main entry point for creating content
/// Now includes "My Drafts" section for resuming unfinished content
class CreateScreenMobile extends StatefulWidget {
  const CreateScreenMobile({super.key});

  @override
  State<CreateScreenMobile> createState() => _CreateScreenMobileState();
}

class _CreateScreenMobileState extends State<CreateScreenMobile> {
  @override
  void initState() {
    super.initState();
    // Fetch drafts when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DraftProvider>().fetchDrafts();
    });
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openDraft(ContentDraft draft) {
    // Navigate to the appropriate editor based on draft type
    switch (draft.draftType) {
      case DraftType.videoPodcast:
        if (draft.originalMediaUrl != null) {
          final api = ApiService();
          final mediaUrl = api.getMediaUrl(draft.originalMediaUrl!);
          _navigateToScreen(
            context,
            VideoPreviewScreen(
              videoUri: mediaUrl,
              source: 'draft',
              duration: draft.duration ?? 0,
              fileSize: 0,
              draftId: draft.id,
              initialTitle: draft.title,
              initialDescription: draft.description,
            ),
          );
        }
        break;
      case DraftType.audioPodcast:
        if (draft.originalMediaUrl != null) {
          final api = ApiService();
          final mediaUrl = api.getMediaUrl(draft.originalMediaUrl!);
          _navigateToScreen(
            context,
            AudioPreviewScreen(
              audioUri: mediaUrl,
              source: 'draft',
              duration: draft.duration ?? 0,
              fileSize: 0,
              draftId: draft.id,
              initialTitle: draft.title,
              initialDescription: draft.description,
            ),
          );
        }
        break;
      case DraftType.quotePost:
        _navigateToScreen(context, const QuoteCreateScreenMobile());
        break;
      case DraftType.communityPost:
        _navigateToScreen(
          context,
          CreatePostScreen(draftId: draft.id),
        );
        break;
    }
  }

  Future<void> _deleteDraft(ContentDraft draft) async {
    if (draft.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Text('Are you sure you want to delete "${draft.title ?? "Untitled"}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<DraftProvider>().deleteDraft(draft.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;
    
    // Order: Row 1 (Video, Audio), Row 2 (Meeting, Live Stream), Row 3 (Quote, Events)
    // Admin gets Bulk Upload as an additional card
    final List<Widget> optionCards = [
      _buildOptionCard(
        context,
        title: 'Video',
        icon: Icons.videocam,
        onTap: () => _navigateToScreen(context, const VideoPodcastCreateScreen()),
      ),
      _buildOptionCard(
        context,
        title: 'Audio',
        icon: Icons.mic,
        onTap: () => _navigateToScreen(context, const AudioPodcastCreateScreen()),
      ),
      _buildOptionCard(
        context,
        title: 'Meeting',
        icon: Icons.group,
        onTap: () => _navigateToScreen(
          context,
          const MeetingOptionsScreenMobile(),
        ),
      ),
      _buildOptionCard(
        context,
        title: 'Live Stream',
        icon: Icons.live_tv,
        onTap: () => _navigateToScreen(
          context,
          const LiveStreamStartScreen(),
        ),
      ),
      _buildOptionCard(
        context,
        title: 'Quote',
        icon: Icons.format_quote,
        onTap: () => _navigateToScreen(context, const QuoteCreateScreenMobile()),
      ),
      _buildOptionCard(
        context,
        title: 'Events',
        icon: Icons.event,
        onTap: () => _navigateToScreen(
          context,
          const EventsListScreen(),
        ),
      ),
      // Admin-only: Bulk Upload
      if (isAdmin)
        _buildOptionCard(
          context,
          title: 'Bulk Upload',
          icon: Icons.cloud_upload,
          isAdminFeature: true,
          onTap: () => _navigateToScreen(
            context,
            const BulkUploadScreen(),
        ),
      ),
      // Admin-only: Bible Documents
      if (isAdmin)
        _buildOptionCard(
          context,
          title: 'Bible Docs',
          icon: Icons.menu_book,
          isAdminFeature: true,
          onTap: () => _navigateToScreen(
            context,
            const BibleUploadScreen(),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create Content',
                    style: AppTypography.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.large),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.medium,
                  mainAxisSpacing: AppSpacing.medium,
                  childAspectRatio: 0.9,
                ),
                itemCount: optionCards.length,
                itemBuilder: (context, index) => optionCards[index],
              ),

              const SizedBox(height: AppSpacing.large),

              // My Drafts Pill Button
              _buildDraftsPillButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftsPillButton() {
    return Consumer<DraftProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        return Center(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DraftsListScreen(),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large,
                vertical: AppSpacing.medium,
              ),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
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
                  const Icon(Icons.drafts, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    provider.hasDrafts
                        ? 'My Drafts (${provider.totalDrafts})'
                        : 'My Drafts',
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDraftsBottomSheet(BuildContext context, DraftProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large,
                vertical: AppSpacing.medium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Drafts',
                    style: AppTypography.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (provider.hasDrafts)
                    Text(
                      '${provider.totalDrafts} items',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Drafts list
            Flexible(
              child: provider.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.large),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : !provider.hasDrafts
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.large),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.drafts_outlined,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: AppSpacing.medium),
                              Text(
                                'No drafts yet',
                                style: AppTypography.heading4.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.small),
                              Text(
                                'Your saved drafts will appear here',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.large,
                          ),
                          itemCount: provider.drafts.length,
                          itemBuilder: (context, index) {
                            final draft = provider.drafts[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.medium,
                              ),
                              child: _buildDraftCard(draft),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(ContentDraft draft) {
    final apiService = ApiService();
    final thumbnailUrl = draft.thumbnailUrl != null
        ? apiService.getMediaUrl(draft.thumbnailUrl!)
        : null;

    return GestureDetector(
      onTap: () => _openDraft(draft),
      onLongPress: () => _deleteDraft(draft),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: AppSpacing.small),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderPrimary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail or icon
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: thumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: thumbnailUrl == null
                  ? Center(
                      child: Icon(
                        _getDraftIcon(draft.draftType),
                        color: AppColors.warmBrown,
                        size: 24,
                      ),
                    )
                  : null,
            ),
            // Title and type - Fixed height instead of Expanded
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    draft.title ?? 'Untitled',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warmBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          draft.typeDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.warmBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDraftIcon(DraftType type) {
    switch (type) {
      case DraftType.videoPodcast:
        return Icons.videocam;
      case DraftType.audioPodcast:
        return Icons.mic;
      case DraftType.communityPost:
        return Icons.article;
      case DraftType.quotePost:
        return Icons.format_quote;
    }
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isAdminFeature = false,
  }) {
    final cardColor = isAdminFeature ? Colors.red.shade700 : AppColors.warmBrown;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          color: cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
                ),
                if (isAdminFeature)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              title,
              style: AppTypography.heading3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
