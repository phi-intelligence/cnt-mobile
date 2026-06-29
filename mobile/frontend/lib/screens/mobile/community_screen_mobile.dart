import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/community_provider.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/community/instagram_post_card.dart';
import '../../utils/format_utils.dart';
import '../community/comment_screen.dart';
import '../community/create_post_screen.dart';
import '../../utils/app_logger.dart';

class CommunityScreenMobile extends StatefulWidget {
  final int? postId; // Optional postId to scroll to
  
  const CommunityScreenMobile({super.key, this.postId});

  @override
  State<CommunityScreenMobile> createState() => _CommunityScreenMobileState();
}

class _CommunityScreenMobileState extends State<CommunityScreenMobile> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _postKeys = {}; // Store keys for posts to scroll to
  bool _hasScrolledToPost = false;

  @override
  void initState() {
    super.initState();
    AppLogger.debug('✅ CommunityScreenMobile initState');
    // Fetch posts on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<CommunityProvider>().fetchPosts(refresh: true);
      } catch (e) {
        AppLogger.debug('❌ CommunityScreenMobile: Error fetching posts: $e');
      }
    });
    
    // Load more on scroll
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.9) {
      final provider = context.read<CommunityProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.fetchPosts();
      }
    }
  }

  void _scrollToPost(int postId) {
    if (_hasScrolledToPost) return; // Only scroll once
    
    final provider = context.read<CommunityProvider>();
    if (provider.posts.isEmpty) return;
    
    // Find the post index
    final index = provider.posts.indexWhere((post) {
      final postIdValue = post is Map<String, dynamic> 
          ? post['id'] 
          : post.id;
      final id = postIdValue is int 
          ? postIdValue 
          : int.tryParse(postIdValue.toString());
      return id == postId;
    });
    
    if (index < 0) {
      AppLogger.debug('⚠️ Post $postId not found in list');
      return;
    }
    
    // Wait for ListView to be built, then scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Use GlobalKey to get exact position if available
      final key = _postKeys[postId];
      if (key?.currentContext != null) {
        final RenderBox? renderBox = key!.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final scrollPosition = _scrollController.offset + position.dy - 100; // Offset for padding
          _scrollController.animateTo(
            scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
          _hasScrolledToPost = true;
          return;
        }
      }
      
      // Fallback: estimate position based on index
      // Approximate item height (including padding) is ~400-500px
      const estimatedItemHeight = 450.0;
      final scrollPosition = (index * estimatedItemHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      
      _scrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _hasScrolledToPost = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePostScreen(),
        fullscreenDialog: true,
      ),
    ).then((created) {
      if (created == true) {
        context.read<CommunityProvider>().fetchPosts(refresh: true);
      }
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text('Community'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildCreatePill(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<CommunityProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.posts.isEmpty) {
                  return ListView.builder(
                    itemCount: 5,
                    padding: EdgeInsets.all(AppSpacing.medium),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.medium),
                        child: const LoadingShimmer(width: double.infinity, height: 200),
                      );
                    },
                  );
                }

                if (provider.posts.isEmpty && !provider.isLoading) {
                  return const EmptyState(
                    icon: Icons.forum,
                    title: 'No Posts Yet',
                    message: 'Be the first to share something with the community!',
                  );
                }

                // Scroll to post if postId is provided and posts are loaded
                if (widget.postId != null && !provider.isLoading && provider.posts.isNotEmpty && !_hasScrolledToPost) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _scrollToPost(widget.postId!);
                    }
                  });
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchPosts(refresh: true);
                    _hasScrolledToPost = false; // Reset to allow scrolling again after refresh
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(AppSpacing.medium),
                    itemCount: provider.posts.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.medium),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = provider.posts[index];
                      // Convert post to Map if needed
                      final postMap = post is Map<String, dynamic>
                          ? post
                          : {
                              'id': post.id,
                              'user_id': post.user_id,
                              'user_name': post.user_name ?? 'User',
                              'user_avatar': post.user_avatar,
                              'title': post.title,
                              'content': post.content,
                              'image_url': post.image_url,
                              'category': post.category,
                              'likes_count': post.likes_count,
                              'comments_count': post.comments_count,
                              'is_liked': post.is_liked,
                              'created_at': post.created_at.toString(),
                            };

                      // Get post ID for key
                      final postIdValue = postMap['id'];
                      final postIdInt = postIdValue is int 
                          ? postIdValue 
                          : int.tryParse(postIdValue.toString());
                      
                      // Create key for target post
                      if (postIdInt != null && widget.postId == postIdInt && !_postKeys.containsKey(postIdInt)) {
                        _postKeys[postIdInt] = GlobalKey();
                      }

                      final postCard = InstagramPostCard(
                        post: postMap,
                        onLike: () {
                          final postId = postMap['id'];
                          if (postId != null) {
                            final id = postId is int
                                ? postId
                                : int.tryParse(postId.toString());
                            if (id != null) {
                              provider.likePost(id);
                            }
                          }
                        },
                        onComment: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommentScreen(post: postMap),
                            ),
                          );
                        },
                        onShare: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share coming soon')),
                          );
                        },
                        onBookmark: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bookmark coming soon')),
                          );
                        },
                      );

                      return Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.small),
                        child: postIdInt != null && widget.postId == postIdInt && _postKeys.containsKey(postIdInt)
                            ? Container(
                                key: _postKeys[postIdInt],
                                child: postCard,
                              )
                            : postCard,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePill() {
    return GestureDetector(
      onTap: _handleCreatePost,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          // Use a strong, high-contrast background so the text is always readable
          color: AppColors.warmBrown.withOpacity(0.98),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.warmBrown.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            // Slightly stronger border to stand out against the AppBar background
            color: Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              'New Post',
              style: AppTypography.body.copyWith(
                // Force pure white text for maximum contrast in both light and dark themes
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

