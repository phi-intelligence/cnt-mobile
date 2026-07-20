import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/content_item.dart';
import '../models/api_models.dart';
import '../utils/app_logger.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<ContentItem> _results = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  String? _error;
  String? _query;
  String? _selectedFilter;
  
  List<ContentItem> get results => _results;
  List<String> get recentSearches => _recentSearches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get query => _query;
  String? get selectedFilter => _selectedFilter;
  
  SearchProvider() {
    _loadRecentSearches();
  }
  
  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];
      _recentSearches = searches.take(10).toList();
      notifyListeners();
    } catch (e) {
      AppLogger.debug('Error loading recent searches: $e');
    }
  }
  
  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', _recentSearches);
    } catch (e) {
      AppLogger.debug('Error saving recent searches: $e');
    }
  }
  
  Future<void> search(String query, {String? type}) async {
    if (query.trim().isEmpty) {
      // If no query but type is specified, fetch all content of that type
      if (type != null && type != 'all') {
        await fetchAllByType(type);
        return;
      }
      clearResults();
      return;
    }
    
    _query = query.trim();
    _selectedFilter = type;
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // Add to recent searches
    if (!_recentSearches.contains(_query)) {
      _recentSearches.insert(0, _query!);
      _recentSearches = _recentSearches.take(10).toList();
      _saveRecentSearches();
    }
    
    try {
      final data = await _api.searchContent(query: _query!, type: type);
      _results = _parseSearchResults(data);
      _error = null;
    } catch (e) {
      _error = 'Search failed: $e';
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fetch all content of a specific type (for filter selection without search query)
  Future<void> fetchAllByType(String type) async {
    _selectedFilter = type;
    _isLoading = true;
    _error = null;
    _query = null;
    notifyListeners();
    
    try {
      List<ContentItem> items = [];
      
      switch (type.toLowerCase()) {
        case 'audio':
          // Fetch all audio podcasts
          final podcasts = await _api.getPodcasts(
            status: 'approved',
            newestFirst: true,
            limit: 50,
          );
          items = podcasts
              .where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty)
              .map((p) => _api.podcastToContentItem(p, categoryName: 'Audio Podcast'))
              .toList();
          break;
          
        case 'video':
          // Fetch all video podcasts
          final videoPodcasts = await _api.getPodcasts(
            status: 'approved',
            newestFirst: true,
            limit: 50,
          );
          items = videoPodcasts
              .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
              .map((p) => _api.podcastToContentItem(p, categoryName: 'Video Podcast'))
              .toList();
          break;
          
        case 'movie':
        case 'movies':
          // Fetch all movies
          final movies = await _api.getMovies(limit: 50);
          items = movies.map((m) => _api.movieToContentItem(m)).toList();
          break;
          
        case 'music':
          // Fetch music tracks
          final tracks = await _api.getMusicTracks(limit: 50);
          items = tracks.map((t) => ContentItem(
            id: t.id.toString(),
            title: t.title,
            creator: t.artist,
            creatorId: t.userId,
            description: t.album,
            coverImage: _api.getMediaUrl(t.coverImage),
            audioUrl: _api.getMediaUrl(t.audioUrl),
            duration: t.duration != null ? Duration(seconds: t.duration!) : null,
            category: t.genre ?? 'Music',
            plays: t.playsCount,
            createdAt: t.createdAt,
          )).toList();
          break;
          
        case 'animated':
          // Fetch animated Bible stories/movies
          final animatedMovies = await _api.getAnimatedBibleStories(limit: 50);
          items = animatedMovies.map((m) => _api.movieToContentItem(m)).toList();
          break;
          
        case 'all':
        default:
          // All - fetch everything
          items = await _fetchAllContent();
          break;
      }
      
      _results = items;
      _error = null;
    } catch (e) {
      _error = 'Failed to fetch content: $e';
      _results = [];
      AppLogger.debug('Error fetching content by type: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Fetch all content types
  Future<List<ContentItem>> _fetchAllContent() async {
    final List<ContentItem> items = [];
    
    try {
      // Fetch audio podcasts
      final audioPodcasts = await _api.getPodcasts(
        status: 'approved',
        newestFirst: true,
        limit: 20,
      );
      items.addAll(
        audioPodcasts
            .where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty)
            .map((p) => _api.podcastToContentItem(p, categoryName: 'Audio Podcast'))
      );
      
      // Fetch video podcasts
      final videoPodcasts = await _api.getPodcasts(
        status: 'approved',
        newestFirst: true,
        limit: 20,
      );
      items.addAll(
        videoPodcasts
            .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
            .map((p) => _api.podcastToContentItem(p, categoryName: 'Video Podcast'))
      );
      
      // Fetch movies
      final movies = await _api.getMovies(limit: 20);
      items.addAll(movies.map((m) => _api.movieToContentItem(m)));
      
    } catch (e) {
      AppLogger.debug('Error fetching all content: $e');
    }
    
    // Sort by created date
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return items;
  }
  
  List<ContentItem> _parseSearchResults(Map<String, dynamic> data) {
    final List<ContentItem> items = [];
    
    try {
      if (data['podcasts'] != null) {
        final podcasts = data['podcasts'] as List;
        for (var p in podcasts) {
          try {
            if (p is Map<String, dynamic>) {
              final podcast = Podcast.fromJson(p);
              items.add(ContentItem(
                id: podcast.id.toString(),
                title: podcast.title,
                creator: 'Christ Tabernacle',
                creatorId: podcast.creatorId, // Use creatorId for artist profile navigation
                description: podcast.description,
                coverImage: _api.getMediaUrl(podcast.coverImage),
                audioUrl: _api.getMediaUrl(podcast.audioUrl),
                videoUrl: _api.getMediaUrl(podcast.videoUrl),
                duration: podcast.duration != null 
                    ? Duration(seconds: podcast.duration!)
                    : null,
                category: 'Podcast',
                plays: podcast.playsCount,
                createdAt: podcast.createdAt,
              ));
            }
          } catch (e) {
            AppLogger.debug('Error parsing podcast: $e');
          }
        }
      }
      
      if (data['movies'] != null) {
        final movies = data['movies'] as List;
        for (var m in movies) {
          try {
            if (m is Map<String, dynamic>) {
              final movie = Movie.fromJson(m);
              items.add(_api.movieToContentItem(movie));
            }
          } catch (e) {
            AppLogger.debug('Error parsing movie: $e');
          }
        }
      }
      
      if (data['music'] != null) {
        final music = data['music'] as List;
        for (var m in music) {
          try {
            if (m is Map<String, dynamic>) {
              final track = MusicTrack.fromJson(m);
              items.add(ContentItem(
                id: track.id.toString(),
                title: track.title,
                creator: track.artist,
                creatorId: track.userId,
                description: track.album,
                coverImage: _api.getMediaUrl(track.coverImage),
                audioUrl: _api.getMediaUrl(track.audioUrl),
                duration: track.duration != null 
                    ? Duration(seconds: track.duration!)
                    : null,
                category: track.genre ?? 'Music',
                plays: track.playsCount,
                createdAt: track.createdAt,
              ));
            }
          } catch (e) {
            AppLogger.debug('Error parsing music track: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.debug('Error parsing search results: $e');
    }
    
    return items;
  }
  
  void clearResults() {
    _results = [];
    _query = null;
    _selectedFilter = null;
    notifyListeners();
  }
  
  void clearRecentSearches() async {
    _recentSearches = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    notifyListeners();
  }
}
