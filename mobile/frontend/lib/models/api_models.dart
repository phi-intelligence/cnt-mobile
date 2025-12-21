/// API Models for Backend Integration

class Podcast {
  final int id;
  final String title;
  final String? description;
  final String? audioUrl;
  final String? videoUrl;
  final String? coverImage;
  final int? creatorId;
  final int? categoryId;
  final int? duration; // seconds
  final String status;
  final int playsCount;
  final DateTime createdAt;

  Podcast({
    required this.id,
    required this.title,
    this.description,
    this.audioUrl,
    this.videoUrl,
    this.coverImage,
    this.creatorId,
    this.categoryId,
    this.duration,
    required this.status,
    required this.playsCount,
    required this.createdAt,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) {
    return Podcast(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      audioUrl: json['audio_url'] as String?,
      videoUrl: json['video_url'] as String?,
      coverImage: json['cover_image'] as String?,
      creatorId: (json['creator_id'] ?? json['user_id']) as int?, // Support both fields
      categoryId: json['category_id'] as int?,
      duration: json['duration'] as int?,
      status: json['status'] as String,
      playsCount: json['plays_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'audio_url': audioUrl,
      'video_url': videoUrl,
      'cover_image': coverImage,
      'creator_id': creatorId,
      'category_id': categoryId,
      'duration': duration,
      'status': status,
      'plays_count': playsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MusicTrack {
  final int id;
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final String audioUrl;
  final String? coverImage;
  final int? duration; // seconds
  final String? lyrics;
  final int? userId; // User ID of the creator (for artist profile navigation)
  final bool isFeatured;
  final bool isPublished;
  final int playsCount;
  final DateTime createdAt;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    required this.audioUrl,
    this.coverImage,
    this.duration,
    this.lyrics,
    this.userId,
    required this.isFeatured,
    required this.isPublished,
    required this.playsCount,
    required this.createdAt,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      genre: json['genre'] as String?,
      audioUrl: json['audio_url'] as String,
      coverImage: json['cover_image'] as String?,
      duration: json['duration'] as int?,
      lyrics: json['lyrics'] as String?,
      userId: json['user_id'] as int?,
      isFeatured: (json['is_featured'] ?? false) as bool,
      isPublished: (json['is_published'] ?? true) as bool,
      playsCount: json['plays_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'audio_url': audioUrl,
      'cover_image': coverImage,
      'duration': duration,
      'lyrics': lyrics,
      'user_id': userId,
      'is_featured': isFeatured,
      'is_published': isPublished,
      'plays_count': playsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Movie {
  final int id;
  final String title;
  final String? description;
  final String videoUrl;
  final String? coverImage;
  final String? previewUrl;
  final int? previewStartTime; // Start time in seconds for preview segment
  final int? previewEndTime; // End time in seconds for preview segment
  final String? director;
  final String? cast; // JSON array or comma-separated
  final DateTime? releaseDate;
  final double? rating; // User rating (0-10)
  final int? categoryId;
  final int? creatorId;
  final int? duration; // Total duration in seconds
  final String status;
  final int playsCount;
  final bool isFeatured; // Featured in hero carousel
  final DateTime createdAt;

  Movie({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.coverImage,
    this.previewUrl,
    this.previewStartTime,
    this.previewEndTime,
    this.director,
    this.cast,
    this.releaseDate,
    this.rating,
    this.categoryId,
    this.creatorId,
    this.duration,
    required this.status,
    required this.playsCount,
    required this.isFeatured,
    required this.createdAt,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String,
      coverImage: json['cover_image'] as String?,
      previewUrl: json['preview_url'] as String?,
      previewStartTime: json['preview_start_time'] as int?,
      previewEndTime: json['preview_end_time'] as int?,
      director: json['director'] as String?,
      cast: json['cast'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'] as String)
          : null,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      categoryId: json['category_id'] as int?,
      creatorId: json['creator_id'] as int?,
      duration: json['duration'] as int?,
      status: json['status'] as String,
      playsCount: json['plays_count'] as int,
      isFeatured: (json['is_featured'] ?? false) as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'cover_image': coverImage,
      'preview_url': previewUrl,
      'preview_start_time': previewStartTime,
      'preview_end_time': previewEndTime,
      'director': director,
      'cast': cast,
      'release_date': releaseDate?.toIso8601String(),
      'rating': rating,
      'category_id': categoryId,
      'creator_id': creatorId,
      'duration': duration,
      'status': status,
      'plays_count': playsCount,
      'is_featured': isFeatured,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class BibleStory {
  final int id;
  final String title;
  final String scriptureReference;
  final String content;
  final String? audioUrl;
  final String? coverImage;
  final DateTime createdAt;

  BibleStory({
    required this.id,
    required this.title,
    required this.scriptureReference,
    required this.content,
    this.audioUrl,
    this.coverImage,
    required this.createdAt,
  });

  factory BibleStory.fromJson(Map<String, dynamic> json) {
    return BibleStory(
      id: json['id'] as int,
      title: json['title'] as String,
      scriptureReference: json['scripture_reference'] as String? ?? '',
      content: json['content'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      coverImage: json['cover_image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scripture_reference': scriptureReference,
      'content': content,
      'audio_url': audioUrl,
      'cover_image': coverImage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

