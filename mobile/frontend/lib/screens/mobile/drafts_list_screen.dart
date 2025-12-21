import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../widgets/shared/image_helper.dart';
import '../creation/video_preview_screen.dart';
import '../creation/audio_preview_screen.dart';
import '../community/create_post_screen.dart';
import 'quote_create_screen_mobile.dart';

/// Full-page screen displaying all user drafts
class DraftsListScreen extends StatefulWidget {
  const DraftsListScreen({super.key});

  @override
  State<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends State<DraftsListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch drafts when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DraftProvider>().fetchDrafts();
    });
  }

  void _openDraft(ContentDraft draft) {
    // Navigate to the appropriate editor based on draft type
    switch (draft.draftType) {
      case DraftType.videoPodcast:
        if (draft.originalMediaUrl != null) {
          final api = ApiService();
          final mediaUrl = api.getMediaUrl(draft.originalMediaUrl!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPreviewScreen(
                videoUri: mediaUrl,
                source: 'draft',
                duration: draft.duration ?? 0,
                fileSize: 0,
                draftId: draft.id,
                initialTitle: draft.title,
                initialDescription: draft.description,
              ),
            ),
          );
        }
        break;
      case DraftType.audioPodcast:
        if (draft.originalMediaUrl != null) {
          final api = ApiService();
          final mediaUrl = api.getMediaUrl(draft.originalMediaUrl!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPreviewScreen(
                audioUri: mediaUrl,
                source: 'draft',
                duration: draft.duration ?? 0,
                fileSize: 0,
                draftId: draft.id,
                initialTitle: draft.title,
                initialDescription: draft.description,
              ),
            ),
          );
        }
        break;
      case DraftType.quotePost:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const QuoteCreateScreenMobile(),
          ),
        );
        break;
      case DraftType.communityPost:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(draftId: draft.id),
          ),
        );
        break;
    }
  }

  Future<void> _deleteDraft(ContentDraft draft) async {
    if (draft.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this draft? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorMain,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<DraftProvider>();
      final success = await provider.deleteDraft(draft.id!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            backgroundColor: AppColors.successMain,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete draft'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Color _getDraftTypeColor(DraftType type) {
    switch (type) {
      case DraftType.videoPodcast:
        return const Color(0xFFE53935); // Red for video
      case DraftType.audioPodcast:
        return const Color(0xFF43A047); // Green for audio
      case DraftType.communityPost:
        return const Color(0xFF1E88E5); // Blue for post
      case DraftType.quotePost:
        return const Color(0xFF8E24AA); // Purple for quote
    }
  }

  Widget _buildDraftCard(ContentDraft draft) {
    final apiService = ApiService();
    
    // Try to get thumbnail from thumbnailUrl, or fall back to originalMediaUrl for images
    String? mediaUrl;
    if (draft.thumbnailUrl != null) {
      mediaUrl = apiService.getMediaUrl(draft.thumbnailUrl!);
    } else if (draft.originalMediaUrl != null && 
               (draft.draftType == DraftType.communityPost ||
                draft.originalMediaUrl!.contains('.jpg') ||
                draft.originalMediaUrl!.contains('.jpeg') ||
                draft.originalMediaUrl!.contains('.png') ||
                draft.originalMediaUrl!.contains('.webp'))) {
      mediaUrl = apiService.getMediaUrl(draft.originalMediaUrl!);
    }

    final typeColor = _getDraftTypeColor(draft.draftType);

    return Dismissible(
      key: Key('draft-${draft.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Draft'),
            content: const Text('Are you sure you want to delete this draft?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.errorMain),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        if (draft.id != null) {
          context.read<DraftProvider>().deleteDraft(draft.id!);
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
        decoration: BoxDecoration(
          color: AppColors.errorMain,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onTap: () => _openDraft(draft),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Thumbnail or icon with type indicator
              Stack(
                children: [
            Container(
                    width: 110,
                    height: 110,
              decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                    ),
                    child: mediaUrl != null
                        ? ImageHelper.buildCachedImage(
                            imageUrl: mediaUrl,
                            fallbackAsset: 'assets/images/thumbnail1.jpg',
                        fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                _getDraftIcon(draft.draftType),
                                color: typeColor,
                                size: 36,
                              ),
                            ),
                          )
                        : Center(
                      child: Icon(
                        _getDraftIcon(draft.draftType),
                              color: typeColor,
                              size: 36,
                            ),
                          ),
                  ),
                  // Type badge overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getDraftIcon(draft.draftType),
                            color: Colors.white,
                            size: 12,
                      ),
                          const SizedBox(width: 4),
                          Text(
                            draft.typeDisplayName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ),
              // Title, description, and metadata
            Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              draft.title ?? 'Untitled Draft',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                                fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                          ),
                          // Delete button (visible)
                          GestureDetector(
                            onTap: () => _deleteDraft(draft),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.more_vert,
                                color: AppColors.textTertiary,
                                size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (draft.description != null && draft.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                      Text(
                        draft.description!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                            height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(draft.updatedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (draft.duration != null && draft.duration! > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${draft.duration! ~/ 60}:${(draft.duration! % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
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
        title: Text(
          'My Drafts',
          style: AppTypography.heading2.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<DraftProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.warmBrown,
              ),
            );
          }

          if (!provider.hasDrafts) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.extraLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 60,
                        color: AppColors.warmBrown,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.large),
                    Text(
                      'No Drafts Yet',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      'When you save content as a draft,\nit will appear here',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.extraLarge),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Content'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warmBrown,
                        side: BorderSide(color: AppColors.warmBrown),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchDrafts(),
            color: AppColors.warmBrown,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.large),
              itemCount: provider.drafts.length,
              itemBuilder: (context, index) {
                final draft = provider.drafts[index];
                return _buildDraftCard(draft);
              },
            ),
          );
        },
      ),
    );
  }
}

