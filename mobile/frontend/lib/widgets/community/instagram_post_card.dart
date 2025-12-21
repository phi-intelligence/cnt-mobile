import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/format_utils.dart';
import '../../services/api_service.dart';
import '../shared/image_helper.dart';

/// Instagram-like post card widget
/// Shows photo posts with like, comment, share, and bookmark functionality
class InstagramPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;

  const InstagramPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onBookmark,
  });

  @override
  State<InstagramPostCard> createState() => _InstagramPostCardState();
}

class _InstagramPostCardState extends State<InstagramPostCard>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likesCount;
  bool _isAnimating = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['is_liked'] ?? false;
    _likesCount = widget.post['likes_count'] ?? 0;

    // Animation for like heart
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      if (_isLiked) {
        _likesCount--;
      } else {
        _likesCount++;
        // Animate heart on like
        _isAnimating = true;
        _animationController.forward().then((_) {
          _animationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isAnimating = false;
              });
            }
          });
        });
      }
      _isLiked = !_isLiked;
    });

    // Call callback if provided
    if (widget.onLike != null) {
      widget.onLike!();
    }
  }

  String _getImageUrl() {
    final imageUrl = widget.post['image_url'];
    if (imageUrl == null) return '';
    
    // If image_url starts with 'images/', treat as asset path
    // Otherwise, treat as full media URL
    if (imageUrl.toString().startsWith('images/')) {
      // Use asset path for images in assets folder
      return imageUrl.toString().replaceFirst('images/', 'assets/images/');
    }
    
    // Otherwise, use API service to get media URL
    final apiService = ApiService();
    return apiService.getMediaUrl(imageUrl.toString());
  }

  Widget _buildProfilePicture(String? avatarUrl, String userName) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: ImageHelper.getImageProvider(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: avatarUrl.isEmpty 
            ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: AppTypography.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }
    
    // Fallback: Use first letter of username as avatar
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryMain,
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
        style: AppTypography.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.post['user_name'] ?? 'User';
    final userAvatar = widget.post['user_avatar'];
    final content = widget.post['content'] ?? widget.post['title'] ?? '';
    final imageUrl = widget.post['image_url'];
    final createdAt = widget.post['created_at'];
    final commentsCount = widget.post['comments_count'] ?? 0;
    final DateTime? createdDate = createdAt != null
        ? (createdAt is DateTime
            ? createdAt
            : DateTime.tryParse(createdAt.toString()))
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile picture, username, three dots menu
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small * 0.75,
              ),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warmBrown.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            child: Row(
              children: [
                _buildProfilePicture(userAvatar, userName),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    userName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textInverse,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  color: AppColors.textInverse,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // Show options menu
                  },
                ),
              ],
            ),
          ),

          // Image section
          if (imageUrl != null && imageUrl.toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: GestureDetector(
                onDoubleTap: _handleLike, // Double tap to like
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                      // Main image - reduced size on web
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: imageUrl.toString().startsWith('assets/')
                            ? Image.asset(
                                imageUrl.toString(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppColors.backgroundTertiary,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: AppColors.textTertiary,
                                      size: 48,
                                    ),
                                  );
                                },
                              )
                            : CachedNetworkImage(
                                imageUrl: _getImageUrl(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                memCacheWidth: 800, // Optimize memory usage
                                memCacheHeight: 800,
                                placeholder: (context, url) => Container(
                                  color: AppColors.backgroundTertiary,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryMain,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: AppColors.backgroundTertiary,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: AppColors.textTertiary,
                                      size: 48,
                                    ),
                                  );
                                },
                              ),
                      ),
                    // Animated heart overlay on double tap
                    if (_isAnimating)
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Icon(
                          Icons.favorite,
                          size: 80,
                          color: AppColors.errorMain,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Footer: Like, comment, share, bookmark icons
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? AppColors.errorMain : AppColors.textSecondary,
                  ),
                  onPressed: _handleLike,
                  padding: EdgeInsets.all(AppSpacing.small),
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: AppSpacing.small),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  color: AppColors.textSecondary,
                  onPressed: widget.onComment,
                  padding: EdgeInsets.all(AppSpacing.small),
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: AppSpacing.small),
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  color: AppColors.textSecondary,
                  onPressed: widget.onShare,
                  padding: EdgeInsets.all(AppSpacing.small),
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  color: AppColors.textSecondary,
                  onPressed: widget.onBookmark,
                  padding: EdgeInsets.all(AppSpacing.small),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Likes count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: Text(
              '${_likesCount == 0 ? 'No' : _likesCount} like${_likesCount == 1 ? '' : 's'}',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.small),

          // Caption: Username + content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: RichText(
              text: TextSpan(
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$userName ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),

          // Comments count
          if (commentsCount > 0) ...[
            const SizedBox(height: AppSpacing.small),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
              child: Text(
                'View all $commentsCount comment${commentsCount == 1 ? '' : 's'}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],

          // Timestamp
          if (createdDate != null) ...[
            const SizedBox(height: AppSpacing.small),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
              child: Text(
                FormatUtils.formatRelativeTime(createdDate),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],

          SizedBox(height: AppSpacing.small),
        ],
      ),
      ),
    );
  }
}

