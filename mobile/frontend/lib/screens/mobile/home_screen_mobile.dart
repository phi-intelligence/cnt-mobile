import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/shared/content_section.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';
import '../../services/api_service.dart';
import '../../providers/music_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/content_item.dart';
import '../../models/api_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../video/video_player_full_screen.dart';
import '../../widgets/hero_carousel_widget.dart';
import '../movie_detail_screen.dart';
import '../voice/ai_voice_agent_screen.dart';
import '../../models/document_asset.dart';
import '../../screens/bible/bible_document_selector_screen.dart';
import '../../screens/bible/pdf_viewer_screen.dart';
import 'community_screen_mobile.dart';
import '../../navigation/mobile_navigation.dart';
import '../../utils/app_logger.dart';

/// Popular Bible verses for the daily quote feature
const List<Map<String, String>> _bibleVerses = [
  {'reference': 'John 3:16', 'text': 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.'},
  {'reference': 'Jeremiah 29:11', 'text': 'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.'},
  {'reference': 'Philippians 4:13', 'text': 'I can do all this through him who gives me strength.'},
  {'reference': 'Romans 8:28', 'text': 'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.'},
  {'reference': 'Proverbs 3:5-6', 'text': 'Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.'},
  {'reference': 'Isaiah 41:10', 'text': 'So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.'},
  {'reference': 'Psalm 23:1', 'text': 'The Lord is my shepherd, I lack nothing.'},
  {'reference': 'Matthew 11:28', 'text': 'Come to me, all you who are weary and burdened, and I will give you rest.'},
  {'reference': 'Romans 12:2', 'text': 'Do not conform to the pattern of this world, but be transformed by the renewing of your mind.'},
  {'reference': 'Joshua 1:9', 'text': 'Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.'},
  {'reference': 'Psalm 46:1', 'text': 'God is our refuge and strength, an ever-present help in trouble.'},
  {'reference': '2 Timothy 1:7', 'text': 'For God has not given us a spirit of fear, but of power and of love and of a sound mind.'},
  {'reference': 'Hebrews 11:1', 'text': 'Now faith is confidence in what we hope for and assurance about what we do not see.'},
  {'reference': 'Psalm 119:105', 'text': 'Your word is a lamp for my feet, a light on my path.'},
  {'reference': 'Matthew 6:33', 'text': 'But seek first his kingdom and his righteousness, and all these things will be given to you as well.'},
];

class HomeScreenMobile extends StatefulWidget {
  const HomeScreenMobile({super.key});

  @override
  State<HomeScreenMobile> createState() => _HomeScreenMobileState();
}

class _HomeScreenMobileState extends State<HomeScreenMobile> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<ContentItem> _audioPodcasts = [];
  List<ContentItem> _videoPodcasts = [];
  List<ContentItem> _recentPodcasts = [];
  List<ContentItem> _movies = [];
  List<ContentItem> _animatedBibleStories = [];
  List<BibleStory> _bibleStories = [];
  List<DocumentAsset> _bibleDocuments = [];
  bool _isLoadingPodcasts = false;
  bool _isLoadingMovies = false;
  bool _isLoadingAnimatedBibleStories = false;
  bool _isLoadingBibleStories = false;
  bool _isLoadingBibleDocuments = false;
  
  // Scroll tracking for parallax/fade effects - using ValueNotifier to avoid setState on every scroll
  late final ValueNotifier<double> _scrollOffsetNotifier;
  
  // Throttle scroll updates to max 60fps (16ms intervals)
  DateTime? _lastScrollUpdate;

  @override
  void initState() {
    super.initState();
    AppLogger.debug('✅ HomeScreenMobile initState');
    
    // Initialize ValueNotifier for scroll offset
    _scrollOffsetNotifier = ValueNotifier<double>(0.0);
    
    // Fetch data on load - stagger requests to prevent main thread blocking
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        AppLogger.debug('✅ HomeScreenMobile: Fetching data...');
        // Start critical data first (podcasts for main content)
        _fetchPodcasts();
        
        // Stagger other requests to prevent blocking
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _fetchMovies();
          _fetchAnimatedBibleStories();
        });
        
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _fetchBibleStories();
          _fetchBibleDocuments();
        });
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          context.read<MusicProvider>().fetchTracks();
          context.read<UserProvider>().fetchUser();
        });
        
        AppLogger.debug('✅ HomeScreenMobile: Data fetch initiated');
      } catch (e) {
        AppLogger.debug('❌ HomeScreenMobile: Error initializing providers: $e');
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }
  
  // Calculate carousel opacity based on scroll position
  double _calculateCarouselOpacity(double scrollOffset) {
    const fadeStart = 100.0;
    const fadeEnd = 300.0;
    
    if (scrollOffset < fadeStart) return 1.0;
    if (scrollOffset > fadeEnd) return 0.0;
    
    final fadeProgress = (scrollOffset - fadeStart) / (fadeEnd - fadeStart);
    return (1.0 - fadeProgress).clamp(0.0, 1.0);
  }
  
  // Calculate parallax offset for carousel
  double _calculateParallaxOffset(double scrollOffset) {
    // Disable vertical shift on mobile to prevent hero carousel from moving
    // when scrolling the underlying content sections.
    return 0.0;
  }
  
  // Throttled scroll update handler
  void _handleScrollUpdate(double offset) {
    final now = DateTime.now();
    if (_lastScrollUpdate != null) {
      final elapsed = now.difference(_lastScrollUpdate!);
      // Throttle to max 60fps (16ms intervals)
      if (elapsed.inMilliseconds < 16) return;
    }
    _lastScrollUpdate = now;
    _scrollOffsetNotifier.value = offset;
  }

  Future<void> _fetchPodcasts() async {
    if (_isLoadingPodcasts) return;
    
    setState(() {
      _isLoadingPodcasts = true;
    });

    try {
      final podcastsData = await _api.getPodcasts(
        status: 'approved',
        newestFirst: true,
      );
      podcastsData.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Convert Podcast models to ContentItem models
      final allContentItems = podcastsData.map((podcast) {
        final audioUrl = podcast.audioUrl != null && podcast.audioUrl!.isNotEmpty
            ? _api.getMediaUrl(podcast.audioUrl!)
            : null;
        final videoUrl = podcast.videoUrl != null && podcast.videoUrl!.isNotEmpty
            ? _api.getMediaUrl(podcast.videoUrl!)
            : null;
        
        return ContentItem(
          id: podcast.id.toString(),
          title: podcast.title,
          creator: 'Christ Tabernacle',
          description: podcast.description,
          coverImage: podcast.coverImage != null 
            ? _api.getMediaUrl(podcast.coverImage!) 
            : null,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          duration: podcast.duration != null 
            ? Duration(seconds: podcast.duration!)
            : null,
          category: _getCategoryName(podcast.categoryId),
          plays: podcast.playsCount,
          createdAt: podcast.createdAt,
        );
      }).toList();
      
      // Separate audio and video podcasts
      _audioPodcasts = allContentItems.where((p) => 
        p.audioUrl != null && 
        p.audioUrl!.isNotEmpty && 
        (p.videoUrl == null || p.videoUrl!.isEmpty)
      ).toList();
      
      _videoPodcasts = allContentItems.where((p) => 
        p.videoUrl != null && 
        p.videoUrl!.isNotEmpty
      ).toList();
      
      // Get recent podcasts (audio podcasts sorted by created_at)
      _recentPodcasts = List.from(_audioPodcasts);
      _recentPodcasts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recentPodcasts = _recentPodcasts.take(5).toList();
      
      AppLogger.debug('✅ Loaded ${_audioPodcasts.length} audio podcasts and ${_videoPodcasts.length} video podcasts');
    } catch (e) {
      AppLogger.debug('❌ Error fetching podcasts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPodcasts = false;
        });
      }
    }
  }

  Future<void> _fetchMovies() async {
    if (_isLoadingMovies) return;
    
    setState(() {
      _isLoadingMovies = true;
    });

    try {
      final moviesData = await _api.getMovies(limit: 20);
      
      // Convert Movie models to ContentItem models
      _movies = moviesData.map((movie) {
        return _api.movieToContentItem(movie);
      }).toList();
      
      AppLogger.debug('✅ Loaded ${_movies.length} movies');
    } catch (e) {
      AppLogger.debug('❌ Error fetching movies: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMovies = false;
        });
      }
    }
  }

  Future<void> _fetchBibleStories() async {
    if (_isLoadingBibleStories) return;

    setState(() {
      _isLoadingBibleStories = true;
    });

    try {
      final stories = await _api.getBibleStories(limit: 10);
      if (mounted) {
        setState(() {
          _bibleStories = stories;
        });
      }
    } catch (e) {
      AppLogger.debug('❌ Error fetching bible stories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBibleStories = false;
        });
      }
    }
  }

  Future<void> _fetchBibleDocuments() async {
    if (_isLoadingBibleDocuments) return;

    setState(() {
      _isLoadingBibleDocuments = true;
    });

    try {
      final docs = await _api.getDocuments(category: 'Bible');
      if (mounted) {
        setState(() {
          _bibleDocuments = docs;
        });
      }
    } catch (e) {
      AppLogger.debug('❌ Error fetching bible documents: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBibleDocuments = false;
        });
      }
    }
  }

  Future<void> _fetchAnimatedBibleStories() async {
    if (_isLoadingAnimatedBibleStories) return;

    setState(() {
      _isLoadingAnimatedBibleStories = true;
    });

    try {
      // Fetch animated Bible stories from dedicated endpoint
      final storiesData = await _api.getAnimatedBibleStories(limit: 20);
      
      _animatedBibleStories = storiesData.map((movie) {
        return _api.movieToContentItem(movie);
      }).toList();
      
      AppLogger.debug('✅ Loaded ${_animatedBibleStories.length} animated Bible stories');
    } catch (e) {
      AppLogger.debug('❌ Error fetching animated Bible stories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnimatedBibleStories = false;
        });
      }
    }
  }

  String _getCategoryName(int? categoryId) {
    switch (categoryId) {
      case 1: return 'Sermons';
      case 2: return 'Bible Study';
      case 3: return 'Devotionals';
      case 4: return 'Prayer';
      case 5: return 'Worship';
      case 6: return 'Gospel';
      default: return 'Podcast';
    }
  }

  void _handlePlay(ContentItem item) {
    if (item.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio available for ${item.title}')),
      );
      return;
    }

    // Play audio via AudioPlayerState without section context
    context.read<AudioPlayerState>().playContent(item);
  }

  // Audio Podcasts specific play handler with queue
  void _handlePlayAudioPodcast(ContentItem item) {
    if (item.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio available for ${item.title}')),
      );
      return;
    }

    // Play with queue and section context for continuous playback
    context.read<AudioPlayerState>().playContentWithQueue(
      item,
      _audioPodcasts,
      section: 'Audio Podcasts',
    );
  }

  // Music specific play handler with queue
  void _handlePlayMusic(ContentItem item) {
    if (item.audioUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio available for ${item.title}')),
      );
      return;
    }

    final musicProvider = context.read<MusicProvider>();
    final musicTracks = musicProvider.tracks;
    
    // Play with queue and section context for continuous playback
    context.read<AudioPlayerState>().playContentWithQueue(
      item,
      musicTracks,
      section: 'Music',
    );
  }

  void _handleItemTap(ContentItem item) {
    // Navigate to player - handled by SlidingAudioPlayer
    _handlePlay(item);
  }

  void _handlePlayVideo(ContentItem item) {
    if (item.videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No video available for ${item.title}')),
      );
      return;
    }

    // Navigate to full-screen video podcast player
    final playlist = _videoPodcasts
        .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
        .toList();
    final initialIndex = playlist.indexWhere((p) => p.id == item.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerFullScreen(
          videoId: item.id,
          title: item.title,
          author: item.creator,
          authorId: item.creatorId,
          duration: item.duration?.inSeconds ?? 0,
          gradientColors: const [AppColors.backgroundPrimary, AppColors.backgroundSecondary],
          videoUrl: item.videoUrl!,
          playlist: playlist,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
          onBack: () => Navigator.of(context).pop(),
          onFavorite: () {},
          onSeek: null,
        ),
      ),
    );
  }

  void _handleItemTapVideo(ContentItem item) {
    // Navigate to video player
    _handlePlayVideo(item);
  }

  void _handleMovieTap(ContentItem item) {
    // Navigate to movie detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailScreen(
          item: item,
          movieId: int.tryParse(item.id),
        ),
      ),
    );
  }

  void _openBibleStory(BibleStory story) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.large,
              left: AppSpacing.large,
              right: AppSpacing.large,
              top: AppSpacing.large,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        story.title,
                        style: AppTypography.heading2,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  story.scriptureReference,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      story.content,
                      style: AppTypography.bodyMedium.copyWith(height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBibleReaderSection() {
    final isLoading = _isLoadingBibleStories || _isLoadingBibleDocuments;
    final hasContent =
        _bibleStories.isNotEmpty || _bibleDocuments.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bible Reader Card - matching Daily Bible Quote design
        if (isLoading)
          _buildBibleReaderCard(
            isLoading: true,
          )
        else
          _buildBibleReaderCard(
            isLoading: false,
            hasContent: hasContent,
          ),
        
        const SizedBox(height: AppSpacing.medium),
        
        // Daily Bible Quote Card
        _buildDailyBibleQuoteCard(),
      ],
    );
  }

  // Bible Reader card styled like Daily Bible Quote
  // Standardized height of 80px for consistency with Bible Quote card
  Widget _buildBibleReaderCard({
    required bool isLoading,
    bool hasContent = false,
  }) {
    const double cardHeight = 80.0;
    
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: cardHeight,
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          color: AppColors.warmBrown.withOpacity(0.95),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            SizedBox(width: AppSpacing.medium),
            Text(
              'Loading Bible content...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: hasContent ? _handleBibleReaderTap : null,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        color: AppColors.warmBrown.withOpacity(0.95),
        child: Container(
          width: double.infinity,
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            color: AppColors.warmBrown.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: AppColors.warmBrown.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Bible icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bible Reader',
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textInverse,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasContent
                          ? 'Tap to read Bible stories and documents'
                          : 'No Bible content available yet',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textInverse.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow indicator (only show if has content)
              if (hasContent)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBibleReaderTap() {
    // If documents exist, show document selector or open first document
    if (_bibleDocuments.isNotEmpty) {
      final firstDoc = _bibleDocuments.first;
      if (_bibleDocuments.length > 1) {
        // Show selector if multiple documents
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BibleDocumentSelectorScreen(
              documents: _bibleDocuments,
            ),
          ),
        );
      } else {
        // Open the single document
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerScreen(document: firstDoc),
          ),
        );
      }
    } else if (_bibleStories.isNotEmpty) {
      // Open the first Bible story
      _openBibleStory(_bibleStories.first);
    }
  }

  // Daily Bible Quote card styled like Bible Reader cards
  // Standardized height of 80px for consistency with Bible Reader card
  Widget _buildDailyBibleQuoteCard() {
    const double cardHeight = 80.0;
    
    return GestureDetector(
      onTap: _showBibleQuotePopup,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        color: AppColors.warmBrown.withOpacity(0.95),
        child: Container(
          width: double.infinity,
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            color: AppColors.warmBrown.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: AppColors.warmBrown.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Quote icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.format_quote,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Daily Bible Quote',
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textInverse,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap for an inspiring verse',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textInverse.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }


  final Random _random = Random();

  // Show Bible quote popup
  void _showBibleQuotePopup() {
    final verse = _bibleVerses[_random.nextInt(_bibleVerses.length)];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.extraLarge),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: AppColors.warmBrown,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Text(
                        'Bible Verse',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.warmBrown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              // Verse text
              Text(
                '"${verse['text']}"',
                style: AppTypography.body.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.medium),
              // Reference
              Text(
                '— ${verse['reference']}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warmBrown,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              // Get another quote button
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showBibleQuotePopup();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Another Verse'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warmBrown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Voice Bubble section with greeting inside pill-shaped brown box
  Widget _buildVoiceBubble() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final username = userProvider.user?['name'] ?? 'Guest';
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIVoiceAgentScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.warmBrown,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warmBrown.withOpacity(0.35),
                    offset: const Offset(0, 8),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left side: Greeting text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hey $username!',
                          style: AppTypography.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Talk with Tabernacle Voice Assistant',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Right side: Voice Bubble circle - larger, white with brown bars
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: _buildBrownSoundbarGlyph(90),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build brown soundbar glyph for white voice bubble
  Widget _buildBrownSoundbarGlyph(double size) {
    final scale = size / 80;
    final bars = [14.0 * scale, 22.0 * scale, 28.0 * scale, 22.0 * scale, 14.0 * scale];
    final barWidth = 5 * scale;
    final barSpacing = 4 * scale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(bars.length, (index) {
        return Container(
          width: barWidth,
          height: bars[index],
          margin: EdgeInsets.only(right: index == bars.length - 1 ? 0 : barSpacing),
          decoration: BoxDecoration(
            color: AppColors.warmBrown,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        );
      }),
    );
  }

  // Build soundbar glyph for voice bubble (matching web design)
  Widget _buildSoundbarGlyph(double size) {
    final scale = size / 80;
    final bars = [12.0 * scale, 18.0 * scale, 24.0 * scale, 18.0 * scale, 12.0 * scale];
    final barWidth = 4 * scale;
    final barSpacing = 3 * scale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(bars.length, (index) {
        return Container(
          width: barWidth,
          height: bars[index],
          margin: EdgeInsets.only(right: index == bars.length - 1 ? 0 : barSpacing),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(2 * scale),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Carousel dimensions
    final carouselHeight = screenHeight * 0.35;
    final whiteCardTopMargin = carouselHeight * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Background - Hero Carousel (fixed position with parallax/fade)
          // Wrap with RepaintBoundary to isolate carousel repaints
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: carouselHeight,
            child: RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, scrollOffset, _) {
                  // Only auto-scroll hero when user is near the top of the page.
                  final bool autoScrollEnabled = scrollOffset < 50.0;
                  return Transform.translate(
                    offset: Offset(0, _calculateParallaxOffset(scrollOffset)),
                    child: Opacity(
                      opacity: _calculateCarouselOpacity(scrollOffset),
                      child: HeroCarouselWidget(
                        height: carouselHeight,
                        showTitleOverlay: false, // Mobile hero hides text labels
                        autoScrollEnabled: autoScrollEnabled,
                        onItemTap: (postId) {
                          final navState = MobileNavigationLayout.of(context);
                          if (navState != null) {
                            navState.navigateToCommunityWithPost(postId);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CommunityScreenMobile(postId: postId),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Layer 2: Foreground - Scrollable white card overlay
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                // Use throttled update instead of setState
                _handleScrollUpdate(notification.metrics.pixels);
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _fetchPodcasts(),
                  _fetchMovies(),
                  _fetchAnimatedBibleStories(),
                  _fetchBibleStories(),
                  _fetchBibleDocuments(),
                  musicProvider.fetchTracks(),
                ]);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Spacer to show carousel behind
                    SizedBox(height: whiteCardTopMargin),
                    
                    // White floating card with all content
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight: screenHeight - whiteCardTopMargin,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle indicator
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.borderPrimary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          // Voice Bubble (standalone, centered)
                          _buildVoiceBubble(),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Audio Podcasts Section (first like web)
                          if (_isLoadingPodcasts)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                              child: Column(
                                children: List.generate(3, (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                                  child: const LoadingShimmer(width: double.infinity, height: 100),
                                )),
                              ),
                            )
                          else if (_audioPodcasts.isEmpty)
                            const SizedBox.shrink()
                          else
                            RepaintBoundary(
                              child: ContentSection(
                                title: 'Audio Podcasts',
                                items: _audioPodcasts.take(5).toList(),
                                isHorizontal: false,
                                useDiscDesign: true,
                                onItemPlay: _handlePlayAudioPodcast,
                                onItemTap: _handleItemTap,
                              ),
                            ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Video Podcasts Section
                          if (_isLoadingPodcasts)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                              child: SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 3,
                                  itemBuilder: (_, __) => Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.small),
                                    child: const LoadingShimmer(width: 160, height: 180),
                                  ),
                                ),
                              ),
                            )
                          else if (_videoPodcasts.isEmpty)
                            const SizedBox.shrink()
                          else
                            RepaintBoundary(
                              child: ContentSection(
                                title: 'Video Podcasts',
                                items: _videoPodcasts,
                                isHorizontal: true,
                                onItemPlay: _handlePlayVideo,
                                onItemTap: _handleItemTapVideo,
                              ),
                            ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Bible Reader Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                            child: _buildBibleReaderSection(),
                          ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Movies Section (moved here after Daily Bible Quote)
                          if (_isLoadingMovies)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                              child: SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 3,
                                  itemBuilder: (_, __) => Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.small),
                                    child: const LoadingShimmer(width: 160, height: 180),
                                  ),
                                ),
                              ),
                            )
                          else if (_movies.isEmpty)
                            const SizedBox.shrink()
                          else
                            RepaintBoundary(
                              child: ContentSection(
                                title: 'Movies',
                                items: _movies,
                                isHorizontal: true,
                                onItemTap: _handleMovieTap,
                              ),
                            ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Animated Bible Stories Section
                          if (_isLoadingAnimatedBibleStories)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                              child: SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 3,
                                  itemBuilder: (_, __) => Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.small),
                                    child: const LoadingShimmer(width: 160, height: 180),
                                  ),
                                ),
                              ),
                            )
                          else if (_animatedBibleStories.isEmpty)
                            const SizedBox.shrink()
                          else
                            RepaintBoundary(
                              child: ContentSection(
                                title: 'Animated Bible Stories',
                                items: _animatedBibleStories,
                                isHorizontal: true,
                                onItemTap: _handleMovieTap,
                              ),
                            ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Recently Played Section
                          if (_isLoadingPodcasts)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                              child: Column(
                                children: List.generate(3, (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                                  child: const LoadingShimmer(width: double.infinity, height: 100),
                                )),
                              ),
                            )
                          else if (_recentPodcasts.isEmpty)
                            const EmptyState(
                              icon: Icons.history,
                              title: 'No Recent Playbacks',
                              message: 'Start exploring content to see your recently played items here',
                            )
                          else
                            RepaintBoundary(
                              child: ContentSection(
                                title: 'Recently Played',
                                items: _recentPodcasts,
                                isHorizontal: false,
                                onItemPlay: _handlePlay,
                                onItemTap: _handleItemTap,
                              ),
                            ),
                          
                          const SizedBox(height: AppSpacing.large),
                          
                          // Featured Music Section - Use Selector to only rebuild when featuredTracks change
                          Selector<MusicProvider, List<ContentItem>>(
                            selector: (context, provider) => provider.featuredTracks,
                            builder: (context, featuredTracks, child) {
                              if (featuredTracks.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              
                              return RepaintBoundary(
                                child: ContentSection(
                                  title: 'Featured Music',
                                  items: featuredTracks,
                                  isHorizontal: true,
                                  onItemPlay: _handlePlayMusic,
                                  onItemTap: _handleItemTap,
                                ),
                              );
                            },
                          ),
                          
                          Consumer<AudioPlayerState>(
                            builder: (context, audioPlayer, _) {
                              final playerClearance = audioPlayer.currentTrack != null
                                  ? 80.0
                                  : 0.0;
                              return SizedBox(
                                height: AppSpacing.large + playerClearance,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

