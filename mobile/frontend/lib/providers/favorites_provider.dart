import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/content_item.dart';

class FavoritesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ContentItem> _favorites = [];
  Set<String> _favoriteIds = {}; // Track favorited content IDs
  bool _isLoading = false;
  String? _error;

  List<ContentItem> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get favoriteCount => _favorites.length;
  bool isFavorite(String contentId) => _favoriteIds.contains(contentId);

  /// Map backend favorites content_type to our internal types.
  /// Ensures we always send one of: podcast, movie, music.
  String _resolveContentType(ContentItem item) {
    final categoryLower = item.category.toLowerCase();

    // Explicit movie flag/category
    if (item.isMovie || categoryLower == 'movies' || categoryLower == 'movie') {
      return 'movie';
    }

    // Music genres
    if (categoryLower == 'music' ||
        categoryLower.contains('worship') ||
        categoryLower.contains('hymn') ||
        categoryLower.contains('gospel')) {
      return 'music';
    }

    // Audio-only that doesn't look like music -> treat as podcast
    if (item.audioUrl != null &&
        item.audioUrl!.isNotEmpty &&
        (item.videoUrl == null || item.videoUrl!.isEmpty)) {
      return 'podcast';
    }

    // Video content that isn't a movie -> likely a video podcast
    if (item.videoUrl != null && item.videoUrl!.isNotEmpty) {
      return 'podcast';
    }

    // Safe default
    return 'podcast';
  }

  /// Fetch favorites from backend
  Future<void> fetchFavorites({String? contentType}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.getFavorites(contentType: contentType);

      _favorites = data.where((fav) => fav['content'] != null).map((fav) {
        final content = fav['content'] as Map<String, dynamic>;

        // Duration from seconds
        final dynamic rawDuration = content['duration'];
        Duration? duration;
        if (rawDuration is int) {
          duration = Duration(seconds: rawDuration);
        } else if (rawDuration is num) {
          duration = Duration(seconds: rawDuration.toInt());
        }

        // Created_at from content or favorite record
        final createdAtStr =
            (content['created_at'] ?? fav['created_at']) as String?;
        DateTime createdAt;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        } else {
          createdAt = DateTime.now();
        }

        final contentTypeValue = (fav['content_type'] as String?) ?? 'podcast';

        return ContentItem(
          id: (content['id'] ?? fav['content_id']).toString(),
          title: (content['title'] as String?) ?? 'Unknown',
          creator: (content['creator'] ??
                  content['creator_name'] ??
                  content['author'] ??
                  'Unknown') as String,
          creatorId: content['creator_id'] as int?,
          description: content['description'] as String?,
          coverImage: content['cover_image'] as String?,
          audioUrl: content['audio_url'] as String?,
          videoUrl: content['video_url'] as String?,
          duration: duration,
          category: contentTypeValue,
          plays: (content['plays'] ?? content['plays_count'] ?? 0) as int,
          likes: (content['likes'] ?? 0) as int,
          createdAt: createdAt,
          isFavorite: true,
          isMovie: contentTypeValue == 'movie',
        );
      }).toList();

      _favoriteIds = _favorites.map((f) => f.id.toString()).toSet();
      _error = null;
    } catch (e) {
      _error = 'Failed to load favorites: $e';
      print('Error fetching favorites: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle favorite with optimistic updates
  Future<bool> toggleFavorite(ContentItem item) async {
    final isCurrentlyFavorite = _favoriteIds.contains(item.id);

    // Optimistic update
    if (isCurrentlyFavorite) {
      _favoriteIds.remove(item.id);
      _favorites.removeWhere((f) => f.id == item.id);
    } else {
      _favoriteIds.add(item.id);
      _favorites.add(item);
    }
    notifyListeners();

    // Actual API call
    try {
      bool success;
      final backendType = _resolveContentType(item);
      if (isCurrentlyFavorite) {
        success = await _api.removeFromFavorites(
          backendType,
          int.parse(item.id),
        );
      } else {
        success = await _api.addToFavorites(
          backendType,
          int.parse(item.id),
        );
      }

      if (!success) {
        // Rollback on failure
        _revertOptimisticUpdate(item, isCurrentlyFavorite);
      }
      return success;
    } catch (e) {
      print('Error toggling favorite: $e');
      _revertOptimisticUpdate(item, isCurrentlyFavorite);
      return false;
    }
  }

  /// Revert optimistic update on failure
  void _revertOptimisticUpdate(ContentItem item, bool wasOriginallyFavorite) {
    if (wasOriginallyFavorite) {
      _favoriteIds.add(item.id);
      _favorites.add(item);
    } else {
      _favoriteIds.remove(item.id);
      _favorites.removeWhere((f) => f.id == item.id);
    }
    notifyListeners();
  }

  /// Check if specific content is favorited (syncs with backend)
  Future<bool> checkIsFavorited(String contentType, int contentId) async {
    try {
      final isFav = await _api.isFavorited(contentType, contentId);
      // Update local state
      final id = contentId.toString();
      if (isFav && !_favoriteIds.contains(id)) {
        _favoriteIds.add(id);
        notifyListeners();
      } else if (!isFav && _favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
        notifyListeners();
      }
      return isFav;
    } catch (e) {
      print('Error checking favorite: $e');
      return _favoriteIds.contains(contentId.toString());
    }
  }
}

