/// Artist model for content creators
/// 
/// Artists are users who create podcasts, music, or other content.
/// They have a public profile with follower counts and statistics.
class Artist {
  final int id; // Artist's primary key
  final int userId;
  final String artistName;
  final String? coverImage;
  final String? bio;
  final Map<String, String>? socialLinks;
  final int followersCount;
  final int totalPlays;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Artist({
    required this.id,
    required this.userId,
    required this.artistName,
    this.coverImage,
    this.bio,
    this.socialLinks,
    required this.followersCount,
    required this.totalPlays,
    required this.isVerified,
    required this.createdAt,
    this.updatedAt,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    // Parse social_links from JSON string or map
    Map<String, String>? parsedSocialLinks;
    if (json['social_links'] != null) {
      if (json['social_links'] is String) {
        // social_links stored as JSON string - skip parsing for now
        parsedSocialLinks = null;
      } else if (json['social_links'] is Map) {
        final socialMap = json['social_links'] as Map<dynamic, dynamic>;
        parsedSocialLinks = socialMap.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    }

    return Artist(
      id: json['id'] as int? ?? json['user_id'] as int, // Use id if available, fallback to user_id
      userId: json['user_id'] as int,
      artistName: json['artist_name'] as String,
      coverImage: json['cover_image'] as String?,
      bio: json['bio'] as String?,
      socialLinks: parsedSocialLinks,
      followersCount: (json['followers_count'] as int?) ?? 0,
      totalPlays: (json['total_plays'] as int?) ?? 0,
      isVerified: (json['is_verified'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artist_name': artistName,
      'cover_image': coverImage,
      'bio': bio,
      'social_links': socialLinks,
      'followers_count': followersCount,
      'total_plays': totalPlays,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Artist copyWith({
    int? id,
    int? userId,
    String? artistName,
    String? coverImage,
    String? bio,
    Map<String, String>? socialLinks,
    int? followersCount,
    int? totalPlays,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Artist(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      artistName: artistName ?? this.artistName,
      coverImage: coverImage ?? this.coverImage,
      bio: bio ?? this.bio,
      socialLinks: socialLinks ?? this.socialLinks,
      followersCount: followersCount ?? this.followersCount,
      totalPlays: totalPlays ?? this.totalPlays,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Artist(userId: $userId, artistName: $artistName, followersCount: $followersCount)';
  }
}

/// Artist follower relationship
class ArtistFollower {
  final int id;
  final int artistId;
  final int followerId;
  final DateTime createdAt;

  ArtistFollower({
    required this.id,
    required this.artistId,
    required this.followerId,
    required this.createdAt,
  });

  factory ArtistFollower.fromJson(Map<String, dynamic> json) {
    return ArtistFollower(
      id: json['id'] as int,
      artistId: json['artist_id'] as int,
      followerId: json['follower_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'artist_id': artistId,
      'follower_id': followerId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

