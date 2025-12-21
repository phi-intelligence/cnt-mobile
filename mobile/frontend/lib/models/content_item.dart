class ContentItem {
  final String id;
  final String title;
  final String creator;
  final int? creatorId; // User ID of the creator (for navigation to artist profile)
  final String? description;
  final String? coverImage;
  final String? audioUrl;
  final String? videoUrl;
  final Duration? duration;
  final String category;
  final int plays;
  final int likes;
  final DateTime createdAt;
  final bool isFavorite;
  // Movie-specific fields
  final String? director;
  final String? cast; // JSON array or comma-separated
  final DateTime? releaseDate;
  final double? rating; // User rating (0-10)
  final int? previewStartTime; // Start time in seconds for preview segment
  final int? previewEndTime; // End time in seconds for preview segment
  final bool isMovie; // Whether this is a movie

  ContentItem({
    required this.id,
    required this.title,
    required this.creator,
    this.creatorId,
    this.description,
    this.coverImage,
    this.audioUrl,
    this.videoUrl,
    this.duration,
    required this.category,
    this.plays = 0,
    this.likes = 0,
    required this.createdAt,
    this.isFavorite = false,
    this.director,
    this.cast,
    this.releaseDate,
    this.rating,
    this.previewStartTime,
    this.previewEndTime,
    this.isMovie = false,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      creator: json['creator'] ?? json['creator_name'] ?? json['author'] ?? '',
      creatorId: json['creator_id'] as int?,
      description: json['description'],
      coverImage: json['cover_image'] ?? json['thumbnail'] ?? json['coverImage'],
      audioUrl: json['audio_url'] ?? json['audioUrl'],
      videoUrl: json['video_url'] ?? json['videoUrl'],
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration']) 
          : null,
      category: json['category'] ?? 'general',
      plays: json['plays'] ?? json['plays_count'] ?? 0,
      likes: json['likes'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isFavorite: json['is_favorite'] ?? false,
      director: json['director'],
      cast: json['cast'],
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      previewStartTime: json['preview_start_time'] as int?,
      previewEndTime: json['preview_end_time'] as int?,
      isMovie: json['is_movie'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'creator': creator,
      'creator_id': creatorId,
      'description': description,
      'cover_image': coverImage,
      'audio_url': audioUrl,
      'video_url': videoUrl,
      'duration': duration?.inSeconds,
      'category': category,
      'plays': plays,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
      'is_favorite': isFavorite,
      'director': director,
      'cast': cast,
      'release_date': releaseDate?.toIso8601String(),
      'rating': rating,
      'preview_start_time': previewStartTime,
      'preview_end_time': previewEndTime,
      'is_movie': isMovie,
    };
  }

  ContentItem copyWith({
    String? id,
    String? title,
    String? creator,
    int? creatorId,
    String? description,
    String? coverImage,
    String? audioUrl,
    String? videoUrl,
    Duration? duration,
    String? category,
    int? plays,
    int? likes,
    DateTime? createdAt,
    bool? isFavorite,
    String? director,
    String? cast,
    DateTime? releaseDate,
    double? rating,
    int? previewStartTime,
    int? previewEndTime,
    bool? isMovie,
  }) {
    return ContentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      creator: creator ?? this.creator,
      creatorId: creatorId ?? this.creatorId,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      plays: plays ?? this.plays,
      likes: likes ?? this.likes,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      director: director ?? this.director,
      cast: cast ?? this.cast,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      previewStartTime: previewStartTime ?? this.previewStartTime,
      previewEndTime: previewEndTime ?? this.previewEndTime,
      isMovie: isMovie ?? this.isMovie,
    );
  }

  /// Helper method to get category name from category ID
  static String _getCategoryName(int? categoryId) {
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
}

