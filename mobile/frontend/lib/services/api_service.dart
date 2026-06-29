import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../models/api_models.dart';
import '../models/content_item.dart';
import '../models/support_message.dart';
import '../models/document_asset.dart';
import '../config/environment.dart';
import 'auth_service.dart';
import '../utils/pinned_http_client.dart';
import '../utils/app_logger.dart';
import '../utils/api_error_utils.dart';

/// API Service for connecting Flutter to backend
/// 
/// Configuration via .env file or --dart-define:
/// - API_BASE_URL: Base URL for API calls (e.g., https://api.yourdomain.com/api/v1)
/// - MEDIA_BASE_URL: Base URL for media files (e.g., https://cdn.yourdomain.com)
/// - LIVEKIT_WS_URL: WebSocket URL for LiveKit (e.g., wss://livekit.yourdomain.com)
/// 
/// Development (.env file):
///   API_BASE_URL=http://localhost:8002/api/v1
/// 
/// Production (--dart-define or .env):
///   flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
class ApiService {
  static final _httpClient = PinnedHttpClient.instance;

  final AuthService _authService = AuthService();
  
  /// Callback for when session is truly expired (after refresh fails)
  /// UI layer should set this to handle logout/redirect
  static void Function()? onSessionExpired;
  
  /// Get API base URL from Environment configuration
  static String get baseUrl => Environment.apiBaseUrl;
  
  /// Get media base URL (for images, audio, video files)
  static String get mediaBaseUrl => Environment.mediaBaseUrl;

  /// Helper to detect if we're pointing at a local/dev backend for media
  static bool _isDevMediaBase(String base) {
    return base.contains('localhost') ||
        base.contains('127.0.0.1') ||
        base.contains(':8002') ||
        base.contains(':8000');
  }
  
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  /// Get headers with authentication token
  Future<Map<String, String>> _getHeaders({Map<String, String>? additional}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?additional,
    };
    final authHeaders = await _authService.getAuthHeaders();
    headers.addAll(authHeaders);
    return headers;
  }

  Never _throwHttpFailure(String context, int statusCode, {String body = ''}) {
    if (body.isNotEmpty) {
      AppLogger.debug(
        '$context: HTTP $statusCode ${ApiErrorUtils.sanitizeForLog(body)}',
      );
    } else {
      AppLogger.debug('$context: HTTP $statusCode');
    }
    throw Exception(
      ApiErrorUtils.sanitizeForUser('HTTP $statusCode', fallback: context),
    );
  }

  Never _throwOperationError(String context, Object error) {
    AppLogger.debug('$context: $error');
    throw Exception(ApiErrorUtils.sanitizeForUser(error, fallback: context));
  }
  
  /// Make an authenticated GET request with automatic token refresh on 401
  Future<http.Response> _authenticatedGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 10),
    bool allowRetry = true,
  }) async {
    final response = await _httpClient.get(
      uri,
      headers: await _getHeaders(),
    ).timeout(timeout);
    
    if (response.statusCode == 401 && allowRetry) {
      // Try to refresh the token
      final newToken = await _authService.refreshAccessToken();
      if (newToken != null) {
        // Retry with new token
        return _authenticatedGet(uri, timeout: timeout, allowRetry: false);
      } else {
        // Refresh failed - session is truly expired
        AppLogger.debug('❌ Session expired - refresh token invalid');
        onSessionExpired?.call();
      }
    }
    
    return response;
  }
  
  /// Make an authenticated POST request with automatic token refresh on 401
  Future<http.Response> _authenticatedPost(
    Uri uri, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
    bool allowRetry = true,
  }) async {
    final response = await _httpClient.post(
      uri,
      headers: await _getHeaders(),
      body: body,
    ).timeout(timeout);
    
    if (response.statusCode == 401 && allowRetry) {
      // Try to refresh the token
      final newToken = await _authService.refreshAccessToken();
      if (newToken != null) {
        // Retry with new token
        return _authenticatedPost(uri, body: body, timeout: timeout, allowRetry: false);
      } else {
        // Refresh failed - session is truly expired
        AppLogger.debug('❌ Session expired - refresh token invalid');
        onSessionExpired?.call();
      }
    }
    
    return response;
  }
  
  /// Make an authenticated PUT request with automatic token refresh on 401
  Future<http.Response> _authenticatedPut(
    Uri uri, {
    Object? body,
    Duration timeout = const Duration(seconds: 10),
    bool allowRetry = true,
  }) async {
    final response = await _httpClient.put(
      uri,
      headers: await _getHeaders(),
      body: body,
    ).timeout(timeout);
    
    if (response.statusCode == 401 && allowRetry) {
      // Try to refresh the token
      final newToken = await _authService.refreshAccessToken();
      if (newToken != null) {
        // Retry with new token
        return _authenticatedPut(uri, body: body, timeout: timeout, allowRetry: false);
      } else {
        // Refresh failed - session is truly expired
        AppLogger.debug('❌ Session expired - refresh token invalid');
        onSessionExpired?.call();
      }
    }
    
    return response;
  }
  
  /// Make an authenticated DELETE request with automatic token refresh on 401
  Future<http.Response> _authenticatedDelete(
    Uri uri, {
    Duration timeout = const Duration(seconds: 10),
    bool allowRetry = true,
  }) async {
    final response = await _httpClient.delete(
      uri,
      headers: await _getHeaders(),
    ).timeout(timeout);
    
    if (response.statusCode == 401 && allowRetry) {
      // Try to refresh the token
      final newToken = await _authService.refreshAccessToken();
      if (newToken != null) {
        // Retry with new token
        return _authenticatedDelete(uri, timeout: timeout, allowRetry: false);
      } else {
        // Refresh failed - session is truly expired
        AppLogger.debug('❌ Session expired - refresh token invalid');
        onSessionExpired?.call();
      }
    }
    
    return response;
  }

  /// Create a live stream/meeting (returns backend stream object)
  Future<Map<String, dynamic>> createStream({
    String title = 'Instant Meeting',
    String? description,
    String? category,
    DateTime? scheduledStart,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'category': category,
        'scheduled_start': scheduledStart?.toIso8601String(),
      }..removeWhere((k, v) => v == null);

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/live/streams'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to create stream', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Network error creating stream', e);
    }
  }

  /// Notify backend that host has joined the stream/meeting.
  /// This triggers notifications to other users that the stream is live.
  Future<void> notifyHostJoined(int streamId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/live/streams/$streamId/host-joined'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        AppLogger.debug('Warning: Host joined notification failed: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('Warning: Failed to notify host joined: $e');
    }
  }

  /// End a stream/meeting - updates status, deletes LiveKit room, notifies participants.
  /// This should be called when the host clicks "End Meeting for All".
  Future<void> endMeeting(int streamId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/live/streams/$streamId/end'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        final errorBody = response.body;
        AppLogger.debug('Failed to end meeting: ${response.statusCode} - $errorBody');
        _throwHttpFailure('Failed to end meeting', response.statusCode, body: response.body);
      }
      
      AppLogger.debug('✅ Meeting ended successfully: $streamId');
    } catch (e) {
      AppLogger.debug('Error ending meeting: $e');
      rethrow;
    }
  }

  /// List streams (optional helper when joining by room without backend route)
  Future<List<Map<String, dynamic>>> listStreams({String? status}) async {
    try {
      Uri uri = Uri.parse('$baseUrl/live/streams');
      if (status != null) {
        uri = uri.replace(queryParameters: {'status': status});
      }
      final response = await _httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      _throwHttpFailure('Failed to list streams', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Network error listing streams', e);
    }
  }

  /// Get full media URL for audio/image/video files.
  ///
  /// Behaviour mirrors the web getMediaUrl implementation and the documented
  /// S3 structure (bucket: cnt-web-media, region: eu-west-2):
  /// - Full URLs (http/https) are returned unchanged.
  /// - S3-style hostnames without protocol get https:// prefixed.
  /// - Legacy paths with `media/` are preserved in dev (localhost) and stripped
  ///   in production, since S3 URLs map directly to the bucket root.
  /// - Relative paths like images/... or audio/... are mapped to either
  ///   `{MEDIA_BASE_URL}/media/...` in dev or `{MEDIA_BASE_URL}/...` in prod.
  String getMediaUrl(String? path) {
    if (path == null) return '';
    path = path.trim();
    if (path.isEmpty) return '';

    // Full URLs
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // CloudFront/S3-style domains without protocol
    if (path.contains('cloudfront.net') ||
        path.contains('.amazonaws.com') ||
        path.contains('.s3.')) {
      return path.startsWith('http') ? path : 'https://$path';
    }

    // Match configured media base host
    final mediaBase = mediaBaseUrl
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .trim();
    if (mediaBase.isNotEmpty && path.contains(mediaBase)) {
      return path.startsWith('http') ? path : 'https://$path';
    }

    // Normalise leading slash
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Handle legacy media/ prefix
    if (cleanPath.startsWith('media/')) {
      final isDev = _isDevMediaBase(mediaBaseUrl);
      if (isDev) {
        // Dev: backend serves from /media
        return '$mediaBaseUrl/$cleanPath';
      } else {
        // Prod: S3 URL maps directly to bucket root, strip media/
        cleanPath = cleanPath.substring(6);
        return '$mediaBaseUrl/$cleanPath';
      }
    }

    // Convert assets/images/ -> images/
    if (cleanPath.startsWith('assets/images/')) {
      cleanPath = cleanPath.replaceFirst('assets/', '');
      return '$mediaBaseUrl/$cleanPath';
    }

    // Direct media-style paths
    final isDev = _isDevMediaBase(mediaBaseUrl);
    final isDirectMediaPath = cleanPath.startsWith('images/') ||
        cleanPath.startsWith('audio/') ||
        cleanPath.startsWith('video/') ||
        cleanPath.startsWith('movies/') ||
        cleanPath.startsWith('documents/');

    if (isDirectMediaPath) {
      if (isDev) {
        // Dev: backend serves from /media/...
        return '$mediaBaseUrl/media/$cleanPath';
      } else {
        // Prod: direct S3 mapping
        return '$mediaBaseUrl/$cleanPath';
      }
    }

    // Fallback: treat as generic relative path
    if (isDev) {
      return '$mediaBaseUrl/media/$cleanPath';
    }
    return '$mediaBaseUrl/$cleanPath';
  }

  /// Get all podcasts
  Future<List<Podcast>> getPodcasts({
    int skip = 0,
    int limit = 100,
    String? status,
    bool newestFirst = false,
    int? creatorId,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (newestFirst) {
        queryParams['sort'] = 'newest';
      }
      if (creatorId != null) {
        queryParams['creator_id'] = creatorId.toString();
      }

      final uri = Uri.parse('$baseUrl/podcasts/').replace(queryParameters: queryParams);
      final response = await _authenticatedGet(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Podcast.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load podcasts', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching podcasts', e);
    }
  }
  
  /// Get podcasts by creator ID (user ID)
  Future<List<Podcast>> getPodcastsByCreator(int creatorId, {
    int skip = 0,
    int limit = 50,
  }) async {
    return getPodcasts(
      creatorId: creatorId,
      skip: skip,
      limit: limit,
      status: 'approved',
      newestFirst: true,
    );
  }

  /// Get single podcast
  Future<Podcast> getPodcast(int id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/podcasts/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Podcast.fromJson(json.decode(response.body));
      } else {
        _throwHttpFailure('Failed to load podcast', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching podcast', e);
    }
  }

  /// Bulk create podcasts (admin only)
  Future<List<Map<String, dynamic>>> createBulkPodcasts(List<Map<String, dynamic>> podcasts) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/podcasts/bulk/'),
        headers: await _getHeaders(),
        body: json.encode(podcasts),
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        _throwHttpFailure('Failed to create podcasts', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error creating podcasts', e);
    }
  }

  /// Get music tracks
  Future<List<MusicTrack>> getMusicTracks({
    int skip = 0,
    int limit = 100,
    String? genre,
    String? artist,
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl/music/tracks?skip=$skip&limit=$limit');
      if (genre != null) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'genre': genre,
        });
      }
      if (artist != null) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'artist': artist,
        });
      }

      final response = await _httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => MusicTrack.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load music tracks', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching music tracks', e);
    }
  }

  /// Get bible stories for Bible reader section
  Future<List<BibleStory>> getBibleStories({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/bible-stories/').replace(
        queryParameters: {
          'skip': skip.toString(),
          'limit': limit.toString(),
        },
      );
      final response = await _httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BibleStory.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load bible stories', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching bible stories', e);
    }
  }

  /// Get single music track
  Future<MusicTrack> getMusicTrack(int id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/music/tracks/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return MusicTrack.fromJson(json.decode(response.body));
      } else {
        _throwHttpFailure('Failed to load music track', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching music track', e);
    }
  }

  /// Get featured podcasts (top plays or status = approved)
  Future<List<Podcast>> getFeaturedPodcasts() async {
    final podcasts = await getPodcasts(limit: 50);
    // Filter and sort by plays_count
    podcasts.sort((a, b) => b.playsCount.compareTo(a.playsCount));
    return podcasts.take(10).toList();
  }

  /// Get recent podcasts (newest first)
  Future<List<Podcast>> getRecentPodcasts() async {
    final podcasts = await getPodcasts(limit: 20);
    // Sort by created_at descending
    podcasts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return podcasts.take(10).toList();
  }

  /// Get community posts
  Future<List<dynamic>> getCommunityPosts({
    String? category,
    int skip = 0,
    int limit = 20,
    bool approvedOnly = true,  // Default to true - only show approved posts
    String? postType,  // Optional filter by post type ('image' or 'text')
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl/community/posts');
      final queryParams = {
        'skip': skip.toString(),
        'limit': limit.toString(),
        'approved_only': approvedOnly.toString(),
      };
      if (category != null && category != 'All' && category.isNotEmpty) {
        queryParams['category'] = category.toLowerCase();
      }
      if (postType != null && postType.isNotEmpty) {
        queryParams['post_type'] = postType;
      }
      
      final response = await _httpClient.get(
        uri.replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      } else {
        _throwHttpFailure('Failed to load posts', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching posts', e);
    }
  }

  /// Create a new community post
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String content,
    String? category,
    String? imageUrl,
    String? postType,  // 'image' or 'text' - auto-detected if not provided
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'content': content,
        'category': category ?? 'General',
      };
      if (imageUrl != null) {
        body['image_url'] = imageUrl;
      }
      if (postType != null && postType.isNotEmpty) {
        body['post_type'] = postType;
      }
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/community/posts'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to create post', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error creating post', e);
    }
  }

  /// Like a post (toggles like/unlike)
  Future<Map<String, dynamic>?> likePost(int postId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/community/posts/$postId/like'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.debug('Error liking post: $e');
      return null;
    }
  }

  /// Get comments for a post
  Future<List<dynamic>> getPostComments(int postId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/community/posts/$postId/comments'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      }
      _throwHttpFailure('Failed to get comments', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching comments', e);
    }
  }

  /// Comment on a post
  Future<Map<String, dynamic>> commentPost(int postId, String comment) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/community/posts/$postId/comments'),
        headers: await _getHeaders(),
        body: json.encode({'content': comment}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to comment', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error commenting', e);
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/users/me'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to get user', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching user', e);
    }
  }

  /// Upload image file (for posts, etc.)
  Future<Map<String, dynamic>> uploadImage({
    required String fileName,
    List<int>? bytes,
    String? filePath,
  }) async {
    if (bytes == null && (filePath == null || filePath.isEmpty)) {
      throw Exception('No file data provided');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image'),
      );
      
      // Add auth headers
      final headers = await _getHeaders();
      request.headers.addAll({
        'Authorization': headers['Authorization'] ?? '',
      });

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );
      } else if (filePath != null && filePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('file', filePath),
        );
      }

      final streamedResponse = await _httpClient.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Return with file_path key for consistency
        return {
          'file_path': data['url'] ?? data['filename'],
          'url': data['url'],
          'filename': data['filename'],
        };
      }
      _throwHttpFailure('Failed to upload image', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading image', e);
    }
  }

  /// Upload avatar image for the current user
  Future<String> uploadProfileImage({
    required String fileName,
    List<int>? bytes,
    String? filePath,
  }) async {
    if (bytes == null && (filePath == null || filePath.isEmpty)) {
      throw Exception('No file data provided');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/profile-image'),
      );

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );
      } else if (filePath != null) {
        final file = await http.MultipartFile.fromPath('file', filePath);
        request.files.add(file);
      }

      request.headers.addAll(await _getHeaders());

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(minutes: 2));

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload profile image', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading profile image', e);
    }
  }

  /// Upload draft audio file to S3 drafts/audio/ folder
  Future<String> uploadDraftAudio({required String filePath}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/draft/audio'),
      );

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      request.headers.addAll(await _getHeaders());

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String? ?? data['file_path'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload draft audio', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading draft audio', e);
    }
  }

  /// Upload draft video file to S3 drafts/video/ folder
  Future<String> uploadDraftVideo({required String filePath}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/draft/video'),
      );

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      request.headers.addAll(await _getHeaders());

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String? ?? data['file_path'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload draft video', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading draft video', e);
    }
  }

  /// Upload draft image file to S3 drafts/images/ folder
  Future<String> uploadDraftImage({required String filePath}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/draft/image'),
      );

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      request.headers.addAll(await _getHeaders());

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String? ?? data['file_path'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload draft image', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading draft image', e);
    }
  }

  /// Get support stats for the current user/admin
  Future<SupportStats> getSupportStats() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/support/messages/stats'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SupportStats.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      _throwHttpFailure('Failed to load support stats', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching support stats', e);
    }
  }

  Future<List<SupportMessage>> getMySupportMessages() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/support/messages/me'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List<dynamic>;
        return list
            .map((item) => SupportMessage.fromJson(item))
            .toList(growable: false);
      }
      _throwHttpFailure('Failed to load support messages', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error loading support messages', e);
    }
  }

  Future<List<SupportMessage>> getSupportMessagesForAdmin({String? status}) async {
    try {
      var uri = Uri.parse('$baseUrl/support/messages');
      if (status != null && status.isNotEmpty) {
        uri = uri.replace(queryParameters: {'status_filter': status});
      }

      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List<dynamic>;
        return list
            .map((item) => SupportMessage.fromJson(item))
            .toList(growable: false);
      }
      _throwHttpFailure('Failed to load admin support messages', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error loading admin support messages', e);
    }
  }

  Future<SupportMessage> createSupportMessage({
    required String subject,
    required String message,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/support/messages'),
        headers: await _getHeaders(),
        body: json.encode({
          'subject': subject,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return SupportMessage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      _throwHttpFailure('Failed to send support message', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error sending support message', e);
    }
  }

  Future<SupportMessage> replyToSupportMessage({
    required int messageId,
    required String responseText,
    String status = 'responded',
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/support/messages/$messageId/reply'),
        headers: await _getHeaders(),
        body: json.encode({
          'response': responseText,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SupportMessage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      _throwHttpFailure('Failed to reply to message', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error replying to support message', e);
    }
  }

  Future<SupportMessage> markSupportMessageRead({
    required int messageId,
    required String actor,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/support/messages/$messageId/mark-read'),
        headers: await _getHeaders(),
        body: json.encode({'actor': actor}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return SupportMessage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      _throwHttpFailure('Failed to update message read state', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error updating support message', e);
    }
  }

  Future<List<DocumentAsset>> getDocuments({String? category}) async {
    try {
      var uri = Uri.parse('$baseUrl/documents/');
      if (category != null && category.isNotEmpty) {
        uri = uri.replace(queryParameters: {'category': category});
      }
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => DocumentAsset.fromJson(e)).toList();
      }
      _throwHttpFailure('Failed to load documents', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching documents', e);
    }
  }

  Future<DocumentAsset> createDocument({
    required String title,
    String? description,
    required String filePath,
    String? thumbnailPath,
    String category = 'Bible',
    bool isFeatured = false,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/documents/'),
        headers: await _getHeaders(),
        body: json.encode({
          'title': title,
          'description': description,
          'file_path': filePath,
          'thumbnail_path': thumbnailPath,
          'category': category,
          'is_featured': isFeatured,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return DocumentAsset.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      _throwHttpFailure('Failed to create document', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error creating document', e);
    }
  }

  Future<void> deleteDocument(int documentId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        _throwHttpFailure('Failed to delete document', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error deleting document', e);
    }
  }

  Future<String> uploadDocumentFile({
    required String fileName,
    List<int>? bytes,
    String? filePath,
  }) async {
    if (bytes == null && (filePath == null || filePath.isEmpty)) {
      throw Exception('No document data provided');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/document'),
      );

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );
      } else if (filePath != null) {
        final file = await http.MultipartFile.fromPath('file', filePath);
        request.files.add(file);
      }

      request.headers.addAll(await _getHeaders());

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(minutes: 2));

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['url'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload document', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading document', e);
    }
  }

  /// Get user stats (total listening time, tracks played, etc.)
  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/users/me'),
        headers: await _getHeaders(),
        body: jsonEncode(profileData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to update profile', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error updating profile', e);
    }
  }
  
  Future<Map<String, dynamic>?> getBankDetails() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/bank-details'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null; // No bank details found
      }
      _throwHttpFailure('Failed to get bank details', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting bank details', e);
    }
  }
  
  Future<bool> updateBankDetails(Map<String, dynamic> bankData) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/bank-details'),
        headers: await _getHeaders(),
        body: jsonEncode(bankData),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error updating bank details', e);
    }
  }
  
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/check-username'),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to check username', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error checking username', e);
    }
  }
  
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      // TODO: Implement actual stats endpoint
      return {
        'total_minutes': 1234,
        'songs_played': 567,
        'streak_days': 30,
      };
    } catch (e) {
      return {
        'total_minutes': 0,
        'songs_played': 0,
        'streak_days': 0,
      };
    }
  }

  /// Get public user profile by user ID
  Future<Map<String, dynamic>?> getPublicUserProfile(int userId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/users/$userId/public'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.debug('Error fetching public user profile: $e');
      return null;
    }
  }

  /// Get all playlists
  Future<List<dynamic>> getPlaylists() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/playlists/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      }
      return [];
    } catch (e) {
      AppLogger.debug('Error fetching playlists: $e');
    return [];
    }
  }

  /// Create a new playlist
  Future<Map<String, dynamic>> createPlaylist({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/playlists/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': description,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to create playlist', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error creating playlist', e);
    }
  }

  /// Add item to playlist
  Future<bool> addToPlaylist(int playlistId, String contentType, int contentId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/playlists/$playlistId/items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'content_type': contentType,
          'content_id': contentId,
        }),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      AppLogger.debug('Error adding to playlist: $e');
      return false;
    }
  }

  /// Get favorites with optional content type filter
  Future<List<Map<String, dynamic>>> getFavorites({String? contentType}) async {
    try {
      final queryParams = <String, String>{};
      if (contentType != null) {
        queryParams['content_type'] = contentType;
      }

      final uri = Uri.parse('$baseUrl/favorites').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      AppLogger.debug('Failed to get favorites: ${response.statusCode}');
      return [];
    } catch (e) {
      AppLogger.debug('Error getting favorites: $e');
      return [];
    }
  }

  /// Add to favorites
  Future<bool> addToFavorites(String contentType, int contentId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/favorites'),
        headers: await _getHeaders(),
        body: json.encode({
          'content_type': contentType,
          'content_id': contentId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      AppLogger.debug('Failed to add to favorites: ${response.statusCode}');
      AppLogger.debug('Response body: ${response.body}');
      AppLogger.debug('Request body: content_type=$contentType, content_id=$contentId');
      return false;
    } catch (e) {
      AppLogger.debug('Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove from favorites
  Future<bool> removeFromFavorites(String contentType, int contentId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/favorites/$contentType/$contentId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
      AppLogger.debug('Failed to remove from favorites: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.debug('Error removing from favorites: $e');
      return false;
    }
  }

  /// Check if an item is favorited
  Future<bool> isFavorited(String contentType, int contentId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/favorites/check/$contentType/$contentId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_favorited'] ?? false;
      }
      return false;
    } catch (e) {
      AppLogger.debug('Error checking favorite status: $e');
      return false;
    }
  }

  // ============ Content Drafts API ============

  /// Get user's content drafts
  Future<Map<String, dynamic>> getDrafts({
    String? draftType,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (draftType != null) {
        queryParams['draft_type'] = draftType;
      }

      final uri = Uri.parse('$baseUrl/drafts/').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      AppLogger.debug('Failed to get drafts: ${response.statusCode}');
      return {'drafts': [], 'total': 0};
    } catch (e) {
      AppLogger.debug('Error getting drafts: $e');
      return {'drafts': [], 'total': 0};
    }
  }

  /// Create a new content draft
  Future<Map<String, dynamic>?> createDraft(Map<String, dynamic> draftData) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/drafts/'),
        headers: await _getHeaders(),
        body: json.encode(draftData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      AppLogger.debug('Failed to create draft: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      AppLogger.debug('Error creating draft: $e');
      return null;
    }
  }

  /// Update an existing content draft
  Future<Map<String, dynamic>?> updateDraft(int draftId, Map<String, dynamic> draftData) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/drafts/$draftId'),
        headers: await _getHeaders(),
        body: json.encode(draftData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      AppLogger.debug('Failed to update draft: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.debug('Error updating draft: $e');
      return null;
    }
  }

  /// Delete a content draft
  Future<bool> deleteDraft(int draftId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/drafts/$draftId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      AppLogger.debug('Error deleting draft: $e');
      return false;
    }
  }

  /// Get a specific draft by ID
  Future<Map<String, dynamic>?> getDraft(int draftId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/drafts/$draftId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      AppLogger.debug('Failed to get draft: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.debug('Error getting draft: $e');
      return null;
    }
  }

  /// Search across all content types
  Future<Map<String, dynamic>> searchContent({
    required String query,
    String? type, // 'podcasts', 'music', 'videos', 'posts', 'users'
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      // For now, implement client-side search as backend search endpoint may not exist
      // Try API first, fallback to client-side search
      Uri uri = Uri.parse('$baseUrl/search');
      final queryParams = {
        'q': query,
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (type != null && type != 'All') {
        queryParams['type'] = type.toLowerCase();
      }
      
      final response = await _httpClient.get(
        uri.replace(queryParameters: queryParams),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      // If search endpoint doesn't exist, return empty results
      // Client-side search will be handled in SearchProvider
      return {'podcasts': [], 'music': [], 'posts': []};
    } catch (e) {
      // Return empty results if search endpoint doesn't exist
      return {'podcasts': [], 'music': [], 'posts': []};
    }
  }

  /// Upload file and get URL (legacy method)
  Future<String> uploadFileToEndpoint(
    String filePath,
    String endpoint, {
    Function(int, int)? onProgress,
  }) async {
    try {
      final file = await http.MultipartFile.fromPath('file', filePath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.files.add(file);
      request.headers.addAll(await _getHeaders());
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 5));
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body);
        return data['url'] ?? data['path'] ?? '';
      }
      _throwHttpFailure('Failed to upload file', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading file', e);
    }
  }

  /// Upload file with type and get metadata
  Future<Map<String, dynamic>> uploadFile(
    String filePath,
    String fileType, {
    Function(int, int)? onProgress,
  }) async {
    try {
      // Verify file exists before uploading
      final fileToUpload = File(filePath);
      if (!await fileToUpload.exists()) {
        throw Exception('File not found at path: $filePath');
      }
      
      final fileSize = await fileToUpload.length();
      AppLogger.debug('📤 Uploading file: $filePath (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      // Determine content type based on file type
      String? contentType;
      if (fileType == 'video') {
        contentType = 'video/mp4';
      } else if (fileType == 'audio') {
        contentType = 'audio/mpeg';
      } else if (fileType == 'image') {
        contentType = 'image/jpeg';
      }
      
      final file = await http.MultipartFile.fromPath(
        'file', 
        filePath,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      );
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload/$fileType'));
      request.files.add(file);
      request.headers.addAll(await _getHeaders());
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Convert 'url' to 'file_path' for consistency
        if (data.containsKey('url') && !data.containsKey('file_path')) {
          data['file_path'] = data['url'];
        }
        return data;
      }
      
      // Get error details from response
      final errorResponse = await http.Response.fromStream(streamedResponse);
      String errorMessage = 'HTTP ${streamedResponse.statusCode}';
      try {
        final errorData = json.decode(errorResponse.body);
        if (errorData is Map && errorData.containsKey('detail')) {
          errorMessage += ': ${errorData['detail']}';
        } else {
          errorMessage += ': ${errorResponse.body}';
        }
      } catch (_) {
        errorMessage += ': ${errorResponse.body}';
      }
      
      _throwOperationError('Failed to upload file', errorMessage);
    } catch (e) {
      _throwOperationError('Error uploading file', e);
    }
  }

  /// Create a podcast with uploaded media
  Future<Map<String, dynamic>> createPodcast({
    required String title,
    String? description,
    int? categoryId,
    String? audioUrl,
    String? videoUrl,
    String? coverImage,
    bool useDefaultThumbnail = false,
    int? thumbnailTimestamp, // Timestamp in seconds for thumbnail extraction (default: 30s)
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'category_id': categoryId,
        'audio_url': audioUrl,
        'video_url': videoUrl,
        'cover_image': coverImage,
        'use_default_thumbnail': useDefaultThumbnail,
        'thumbnail_timestamp': thumbnailTimestamp ?? 30, // Default to 30 seconds
      }..removeWhere((k, v) => v == null);

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/podcasts/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to create podcast', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error creating podcast', e);
    }
  }

  /// Download file from URL
  Future<String> downloadFile(
    String url,
    String savePath, {
    Function(int, int)? onProgress,
  }) async {
    try {
      final fullUrl = getMediaUrl(url);
      final uri = Uri.parse(fullUrl);
      final request = http.Request('GET', uri);
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 5));
      
      if (streamedResponse.statusCode == 200) {
        final file = await http.Response.fromStream(streamedResponse);
        // Save file to savePath
        // This is a simplified version - in production you'd write to FileSystem
        return savePath;
      }
      _throwHttpFailure('Failed to download file', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error downloading file', e);
    }
  }

  /// Video editing endpoints
  Future<Map<String, dynamic>> trimVideo(
    String videoPath,
    double startTime,
    double endTime, {
    Function(int, int)? onProgress,
  }) async {
    try {
      // Validate trim times
      if (startTime < 0) startTime = 0;
      if (endTime <= startTime) {
        throw Exception('End time must be greater than start time');
      }
      
      AppLogger.debug('🎬 Trimming video: $videoPath');
      AppLogger.debug('   Start: $startTime seconds, End: $endTime seconds');
      
      // Check if videoPath is a network URL and download it first
      String localPath = videoPath;
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        AppLogger.debug('   Video is a network URL, downloading first...');
        // Download to temp directory
        final tempDir = await getTemporaryDirectory();
        final fileName = 'temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        localPath = '${tempDir.path}/$fileName';
        
        final response = await _httpClient.get(Uri.parse(videoPath));
        if (response.statusCode == 200) {
          final file = File(localPath);
          await file.writeAsBytes(response.bodyBytes);
          AppLogger.debug('   Downloaded to: $localPath');
        } else {
          throw Exception('Failed to download video for editing');
        }
      }
      
      // Verify file exists
      final videoFile = File(localPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found at path: $localPath');
      }
      
      final file = await http.MultipartFile.fromPath('video_file', localPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/video-editing/trim'));
      request.files.add(file);
      request.fields['start_time'] = startTime.toString();
      request.fields['end_time'] = endTime.toString();
      
      AppLogger.debug('   Sending trim request to backend...');
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        final result = json.decode(response.body);
        AppLogger.debug('   ✅ Trim successful: $result');
        return result;
      }
      
      final errorBody = await http.Response.fromStream(streamedResponse);
      AppLogger.debug('   ❌ Trim failed: ${streamedResponse.statusCode} - ${errorBody.body}');
      _throwHttpFailure('Failed to trim video', streamedResponse.statusCode);
    } catch (e) {
      AppLogger.debug('   ❌ Error trimming video: $e');
      _throwOperationError('Error trimming video', e);
    }
  }

  Future<Map<String, dynamic>> removeAudio(String videoPath) async {
    try {
      final file = await http.MultipartFile.fromPath('video_file', videoPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/video-editing/remove-audio'));
      request.files.add(file);
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to remove audio', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error removing audio', e);
    }
  }

  Future<Map<String, dynamic>> addAudio(String videoPath, String audioPath) async {
    try {
      final videoFile = await http.MultipartFile.fromPath('video_file', videoPath);
      final audioFile = await http.MultipartFile.fromPath('audio_file', audioPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/video-editing/add-audio'));
      request.files.add(videoFile);
      request.files.add(audioFile);
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to add audio', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error adding audio', e);
    }
  }

  Future<Map<String, dynamic>> applyVideoFilters(
    String videoPath, {
    double? brightness,
    double? contrast,
    double? saturation,
  }) async {
    try {
      final file = await http.MultipartFile.fromPath('video_file', videoPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/video-editing/apply-filters'));
      request.files.add(file);
      if (brightness != null) request.fields['brightness'] = brightness.toString();
      if (contrast != null) request.fields['contrast'] = contrast.toString();
      if (saturation != null) request.fields['saturation'] = saturation.toString();
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to apply filters', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error applying filters', e);
    }
  }

  Future<Map<String, dynamic>> rotateVideo(String videoPath, int degrees) async {
    try {
      // Validate degrees
      if (![90, 180, 270].contains(degrees)) {
        throw Exception('Invalid rotation degrees. Must be 90, 180, or 270');
      }
      
      AppLogger.debug('🔄 Rotating video: $videoPath by $degrees degrees');
      
      // Check if videoPath is a network URL and download it first
      String localPath = videoPath;
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        AppLogger.debug('   Video is a network URL, downloading first...');
        final tempDir = await getTemporaryDirectory();
        final fileName = 'temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        localPath = '${tempDir.path}/$fileName';
        
        final response = await _httpClient.get(Uri.parse(videoPath));
        if (response.statusCode == 200) {
          final file = File(localPath);
          await file.writeAsBytes(response.bodyBytes);
          AppLogger.debug('   Downloaded to: $localPath');
        } else {
          throw Exception('Failed to download video for editing');
        }
      }
      
      // Verify file exists
      final videoFile = File(localPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found at path: $localPath');
      }
      
      final file = await http.MultipartFile.fromPath('video_file', localPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/video-editing/rotate'));
      request.files.add(file);
      request.fields['degrees'] = degrees.toString();
      
      AppLogger.debug('   Sending rotate request to backend...');
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        final result = json.decode(response.body);
        AppLogger.debug('   ✅ Rotate successful: $result');
        return result;
      }
      
      final errorBody = await http.Response.fromStream(streamedResponse);
      AppLogger.debug('   ❌ Rotate failed: ${streamedResponse.statusCode} - ${errorBody.body}');
      _throwHttpFailure('Failed to rotate video', streamedResponse.statusCode);
    } catch (e) {
      AppLogger.debug('   ❌ Error rotating video: $e');
      _throwOperationError('Error rotating video', e);
    }
  }

  /// Audio editing endpoints
  Future<Map<String, dynamic>> trimAudio(
    String audioPath,
    double startTime,
    double endTime,
  ) async {
    try {
      final file = await http.MultipartFile.fromPath('audio_file', audioPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio-editing/trim'));
      request.files.add(file);
      request.fields['start_time'] = startTime.toString();
      request.fields['end_time'] = endTime.toString();
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to trim audio', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error trimming audio', e);
    }
  }

  Future<Map<String, dynamic>> mergeAudio(List<String> audioPaths) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio-editing/merge'));
      
      for (final audioPath in audioPaths) {
        final file = await http.MultipartFile.fromPath('audio_files', audioPath);
        request.files.add(file);
      }
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to merge audio', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error merging audio', e);
    }
  }

  Future<Map<String, dynamic>> fadeInAudio(String audioPath, double fadeDuration) async {
    try {
      final file = await http.MultipartFile.fromPath('audio_file', audioPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio-editing/fade-in'));
      request.files.add(file);
      request.fields['fade_duration'] = fadeDuration.toString();
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to apply fade in', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error applying fade in', e);
    }
  }

  Future<Map<String, dynamic>> fadeOutAudio(String audioPath, double fadeDuration) async {
    try {
      final file = await http.MultipartFile.fromPath('audio_file', audioPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio-editing/fade-out'));
      request.files.add(file);
      request.fields['fade_duration'] = fadeDuration.toString();
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to apply fade out', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error applying fade out', e);
    }
  }

  Future<Map<String, dynamic>> fadeInOutAudio(
    String audioPath,
    double fadeInDuration,
    double fadeOutDuration,
  ) async {
    try {
      final file = await http.MultipartFile.fromPath('audio_file', audioPath);
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio-editing/fade-in-out'));
      request.files.add(file);
      request.fields['fade_in_duration'] = fadeInDuration.toString();
      request.fields['fade_out_duration'] = fadeOutDuration.toString();
      
      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 10));
      
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      }
      _throwHttpFailure('Failed to apply fade in/out', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error applying fade in/out', e);
    }
  }

  /// Get all movies
  Future<List<Movie>> getMovies({
    int skip = 0,
    int limit = 100,
    bool? featured,
    int? categoryId,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (featured != null) queryParams['featured'] = featured.toString();
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/movies/').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Movie.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load movies', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching movies', e);
    }
  }

  /// Get single movie
  Future<Movie> getMovie(int id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/movies/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Movie.fromJson(json.decode(response.body));
      } else {
        _throwHttpFailure('Failed to load movie', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching movie', e);
    }
  }

  /// Get featured movies for hero carousel
  Future<List<Movie>> getFeaturedMovies({int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/movies/featured/?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Movie.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load featured movies', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching featured movies', e);
    }
  }

  /// Get animated Bible stories
  Future<List<Movie>> getAnimatedBibleStories({int limit = 20}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/movies/animated-bible-stories/?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Movie.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load animated Bible stories', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching animated Bible stories', e);
    }
  }

  /// Get similar movies
  Future<List<Movie>> getSimilarMovies(int movieId, {int limit = 10}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/movies/$movieId/similar?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Movie.fromJson(json)).toList();
      } else {
        _throwHttpFailure('Failed to load similar movies', response.statusCode, body: response.body);
      }
    } catch (e) {
      _throwOperationError('Error fetching similar movies', e);
    }
  }

  /// Get movie preview URL with timestamp support
  /// Returns video URL with optional start time parameter for direct playback
  String getMoviePreviewUrl(Movie movie) {
    final videoUrl = getMediaUrl(movie.videoUrl);
    // If preview times are set, we'll handle them in the video player
    // For now, just return the full video URL
    return videoUrl;
  }

  /// Convert Movie to ContentItem for display
  ContentItem movieToContentItem(Movie movie, {String? categoryName}) {
    // Prefer preview clip URL for lightweight hero carousel playback when available,
    // otherwise fall back to the full movie URL.
    final String effectiveVideoPath =
        (movie.previewUrl != null && movie.previewUrl!.isNotEmpty)
            ? movie.previewUrl!
            : movie.videoUrl;

    return ContentItem(
      id: movie.id.toString(),
      title: movie.title,
      creator: movie.director ?? 'Christ Tabernacle',
      creatorId: movie.creatorId, // Include creator ID for artist profile navigation
      description: movie.description,
      coverImage: movie.coverImage != null ? getMediaUrl(movie.coverImage!) : null,
      videoUrl: getMediaUrl(effectiveVideoPath),
      duration: movie.duration != null ? Duration(seconds: movie.duration!) : null,
      category: categoryName ?? 'Movies',
      plays: movie.playsCount,
      createdAt: movie.createdAt,
      isFavorite: false,
      director: movie.director,
      cast: movie.cast,
      releaseDate: movie.releaseDate,
      rating: movie.rating,
      previewStartTime: movie.previewStartTime,
      previewEndTime: movie.previewEndTime,
      isMovie: true,
    );
  }

  /// Admin API Methods
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      final headers = await _getHeaders();
      AppLogger.debug('🔐 Admin Dashboard Request Headers: ${headers.keys.toList()}');
      AppLogger.debug('🔐 Authorization header present: ${headers.containsKey('Authorization')}');
      
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/admin/dashboard'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      AppLogger.debug('📡 Admin Dashboard Response Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        AppLogger.debug('❌ Admin Dashboard Error Response: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again. Token may have expired.');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Admin access required.');
      }
      _throwHttpFailure('Failed to get admin dashboard', response.statusCode, body: response.body);
    } catch (e) {
      AppLogger.debug('💥 Admin Dashboard Exception: $e');
      _throwOperationError('Error fetching admin dashboard', e);
    }
  }
  
  Future<List<dynamic>> getPendingContent() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/admin/pending'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      }
      _throwHttpFailure('Failed to get pending content', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching pending content', e);
    }
  }
  
  Future<bool> approveContent(String contentType, int contentId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/admin/approve/$contentType/$contentId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error approving content', e);
    }
  }
  
  Future<bool> rejectContent(String contentType, int contentId, {String? reason}) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/admin/reject/$contentType/$contentId'),
        headers: await _getHeaders(),
        body: json.encode({'reason': reason}),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error rejecting content', e);
    }
  }
  
  Future<List<dynamic>> getAllContent({
    String? contentType,
    String? status,
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (contentType != null) queryParams['content_type'] = contentType;
      if (status != null) queryParams['status'] = status;
      
      final uri = Uri.parse('$baseUrl/admin/content').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      }
      _throwHttpFailure('Failed to get content', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching content', e);
    }
  }
  
  /// Google Drive API Methods
  Future<String> getGoogleDriveAuthUrl() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/admin/google-drive/auth-url'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['auth_url'] as String;
      } else if (response.statusCode == 503) {
        // Service Unavailable - Google Drive not configured
        final errorData = json.decode(response.body);
        throw Exception('Google Drive not configured: ${errorData['detail']?['message'] ?? 'Setup required'}');
      }
      _throwHttpFailure('Failed to get auth URL', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting Google Drive auth URL', e);
    }
  }

  /// Get Google OAuth Client ID for frontend
  Future<String?> getGoogleClientId() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/auth/google-client-id'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['client_id'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.debug('⚠️  Could not fetch Google Client ID from backend: $e');
      return null;
    }
  }

  /// Get OAuth token for Google Picker API
  Future<Map<String, dynamic>> getGoogleDrivePickerToken() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/admin/google-drive/picker-token'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to get picker token', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting Google Drive picker token', e);
    }
  }
  
  Future<List<dynamic>> listGoogleDriveFiles({String? mimeType, int limit = 100}) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (mimeType != null) queryParams['mime_type'] = mimeType;
      
      final uri = Uri.parse('$baseUrl/admin/google-drive/files').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['files'] as List<dynamic>;
      }
      _throwHttpFailure('Failed to list files', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error listing Google Drive files', e);
    }
  }
  
  Future<Map<String, dynamic>> importGoogleDriveFile(String fileId, String fileType) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/admin/google-drive/import/$fileId?file_type=$fileType'),
        headers: await _getHeaders(),
      ).timeout(const Duration(minutes: 5));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to import file', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error importing file', e);
    }
  }

  /// Get LiveKit WebSocket URL
  /// Configure via .env file: LIVEKIT_WS_URL=wss://your-livekit-server.com
  String getLiveKitUrl() {
    // Use centralized Environment configuration
    return Environment.liveKitWsUrl;
  }
  
  /// Get LiveKit access token for voice agent
  Future<Map<String, dynamic>> getLiveKitVoiceToken(String roomName, {String? userIdentity}) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/livekit/voice/token'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'room_name': roomName,
          if (userIdentity != null) 'user_identity': userIdentity,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to get token', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting LiveKit token', e);
    }
  }
  
  /// Create a LiveKit room for voice agent
  Future<Map<String, dynamic>> createLiveKitRoom(String roomName, {int maxParticipants = 10}) async {
    try {
      final url = '$baseUrl/livekit/voice/room';
      AppLogger.debug('🌐 Creating LiveKit room: POST $url');
      AppLogger.debug('🌐 Room name: $roomName, max participants: $maxParticipants');
      
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: await _getHeaders(),
        body: jsonEncode({
          'room_name': roomName,
          'max_participants': maxParticipants,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Room creation request timed out. Check if backend is running at $baseUrl');
        },
      );
      
      AppLogger.debug('🌐 Response status: ${response.statusCode}');
      AppLogger.debug('🌐 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        AppLogger.debug('✅ Room created successfully: $result');
        return result;
      } else if (response.statusCode == 500) {
        // Try to parse error message from response
        try {
          final errorBody = json.decode(response.body) as Map<String, dynamic>;
          final detail = errorBody['detail'] ?? errorBody['message'] ?? response.body;
          _throwOperationError('Backend error', detail);
        } catch (_) {
          _throwHttpFailure('Failed to create room', response.statusCode, body: response.body);
        }
      } else {
        _throwHttpFailure('Failed to create room', response.statusCode, body: response.body);
      }
    } on TimeoutException catch (e) {
      AppLogger.debug('❌ Timeout creating room: $e');
      rethrow;
    } on http.ClientException catch (e) {
      AppLogger.debug('❌ Network error creating room: $e');
      _throwOperationError(
        'Network error creating room',
        e,
      );
    } catch (e) {
      AppLogger.debug('❌ Error creating LiveKit room: $e');
      if (e is Exception) {
        rethrow;
      }
      _throwOperationError('Error creating LiveKit room', e);
    }
  }

  /// Get LiveKit access token for joining a meeting by stream ID
  Future<Map<String, dynamic>> getLiveKitMeetingToken(
    int streamId, {
    required String userIdentity,
    required String userName,
    String? userEmail,
    bool isHost = false,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/live/streams/$streamId/livekit-token');
      final body = <String, dynamic>{
        'identity': userIdentity,
        'name': userName,
      };
      if (userEmail != null && userEmail.isNotEmpty) {
        body['email'] = userEmail;
      }

      final response = await _httpClient.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to get LiveKit meeting token', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting LiveKit meeting token', e);
    }
  }

  /// Get LiveKit access token for joining a meeting by room name
  Future<Map<String, dynamic>> getLiveKitMeetingTokenByRoom(
    String roomName, {
    required String userIdentity,
    required String userName,
    String? userEmail,
    bool isHost = false,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/live/streams/by-room/$roomName/livekit-token');
      final body = <String, dynamic>{
        'identity': userIdentity,
        'name': userName,
      };
      if (userEmail != null && userEmail.isNotEmpty) {
        body['email'] = userEmail;
      }

      final response = await _httpClient.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to get LiveKit meeting token by room', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting LiveKit meeting token by room', e);
    }
  }

  /// Convert Podcast to ContentItem for display
  ContentItem podcastToContentItem(Podcast podcast, {String? categoryName}) {
    final audioUrl = podcast.audioUrl != null && podcast.audioUrl!.isNotEmpty
        ? getMediaUrl(podcast.audioUrl!)
        : null;
    final videoUrl = podcast.videoUrl != null && podcast.videoUrl!.isNotEmpty
        ? getMediaUrl(podcast.videoUrl!)
        : null;

    // Helper to get category name
    String getCategoryName(int? categoryId) {
      switch (categoryId) {
        case 1: return 'Sermons';
        case 2: return 'Bible Study';
        case 3: return 'Devotionals';
        case 4: return 'Prayer';
        case 5: return 'Worship';
        case 6: return 'Gospel';
        default: return categoryName ?? 'Podcast';
      }
    }

    return ContentItem(
      id: podcast.id.toString(),
      title: podcast.title,
      creator: 'Christ Tabernacle',
      creatorId: podcast.creatorId, // Include creator ID for artist profile navigation
      description: podcast.description,
      coverImage: podcast.coverImage != null ? getMediaUrl(podcast.coverImage!) : null,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
      duration: podcast.duration != null ? Duration(seconds: podcast.duration!) : null,
      category: getCategoryName(podcast.categoryId),
      plays: podcast.playsCount,
      createdAt: podcast.createdAt,
      isFavorite: false,
      isMovie: false,
    );
  }

  // ============================================================================
  // ARTIST API METHODS
  // ============================================================================

  /// Get all artists
  Future<List<Map<String, dynamic>>> getArtists({int? limit, int? skip}) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (skip != null) queryParams['skip'] = skip.toString();
      
      final uri = Uri.parse('$baseUrl/artists').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      _throwHttpFailure('Failed to get artists', response.statusCode, body: response.body);
    } catch (e) {
      AppLogger.debug('Error getting artists: $e');
      return [];
    }
  }

  /// Get a single artist by user ID
  Future<Map<String, dynamic>?> getArtist(int userId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      }
      _throwHttpFailure('Failed to get artist', response.statusCode, body: response.body);
    } catch (e) {
      AppLogger.debug('Error getting artist: $e');
      return null;
    }
  }

  /// Create an artist profile
  Future<Map<String, dynamic>?> createArtist({
    required String artistName,
    String? coverImage,
    String? bio,
    Map<String, String>? socialLinks,
  }) async {
    try {
      final body = <String, dynamic>{
        'artist_name': artistName,
      };
      if (coverImage != null) body['cover_image'] = coverImage;
      if (bio != null) body['bio'] = bio;
      if (socialLinks != null) body['social_links'] = socialLinks;
      
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/artists'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to create artist', response.statusCode, body: response.body);
    } catch (e) {
      AppLogger.debug('Error creating artist: $e');
      return null;
    }
  }

  /// Update an artist profile
  Future<Map<String, dynamic>?> updateArtist(int artistId, {
    String? artistName,
    String? coverImage,
    String? bio,
    Map<String, String>? socialLinks,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (artistName != null) body['artist_name'] = artistName;
      if (coverImage != null) body['cover_image'] = coverImage;
      if (bio != null) body['bio'] = bio;
      if (socialLinks != null) body['social_links'] = socialLinks;
      
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/artists/$artistId'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to update artist', response.statusCode, body: response.body);
    } catch (e) {
      AppLogger.debug('Error updating artist: $e');
      return null;
    }
  }

  /// Follow an artist
  Future<bool> followArtist(int artistId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/artists/$artistId/follow'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      AppLogger.debug('Error following artist: $e');
      return false;
    }
  }

  /// Unfollow an artist (toggle - same endpoint as follow)
  Future<bool> unfollowArtist(int artistId) async {
    // The backend toggles follow status, so we use the same endpoint
    return followArtist(artistId);
  }

  /// Get artist followers
  Future<List<Map<String, dynamic>>> getArtistFollowers(int artistId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/$artistId/followers'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      AppLogger.debug('Error getting artist followers: $e');
      return [];
    }
  }

  /// Get artist content (podcasts, music)
  Future<Map<String, dynamic>> getArtistContent(int artistId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/$artistId/content'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'podcasts': [], 'music': []};
    } catch (e) {
      AppLogger.debug('Error getting artist content: $e');
      return {'podcasts': [], 'music': []};
    }
  }

  /// Get current user's artist profile (auto-creates if not exists)
  Future<Map<String, dynamic>> getMyArtist() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/me'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      }
      _throwHttpFailure('Failed to get artist profile', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting artist profile', e);
    }
  }

  /// Get artist by user ID
  Future<Map<String, dynamic>> getArtistByUserId(int userId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/by-user/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Artist not found for this user');
      }
      _throwHttpFailure('Failed to get artist', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting artist', e);
    }
  }

  /// Update current user's artist profile
  Future<Map<String, dynamic>> updateMyArtist(Map<String, dynamic> data) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/artists/me'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required');
      }
      _throwHttpFailure('Failed to update artist profile', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error updating artist profile', e);
    }
  }

  /// Upload artist cover image
  Future<String> uploadArtistCover({
    required String fileName,
    List<int>? bytes,
    String? filePath,
  }) async {
    if (bytes == null && (filePath == null || filePath.isEmpty)) {
      throw Exception('No image data provided');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/artists/me/cover-image'),
      );

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );
      } else if (filePath != null) {
        final file = await http.MultipartFile.fromPath('file', filePath);
        request.files.add(file);
      }

      request.headers.addAll(await _getHeaders());

      final streamedResponse = await _httpClient.send(request).timeout(const Duration(minutes: 2));

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final response = await http.Response.fromStream(streamedResponse);
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['cover_image'] as String? ?? data['url'] as String? ?? '';
      }

      _throwHttpFailure('Failed to upload cover image', streamedResponse.statusCode);
    } catch (e) {
      _throwOperationError('Error uploading cover image', e);
    }
  }

  /// Get podcasts by artist
  Future<List<ContentItem>> getArtistPodcasts(int artistId, {int skip = 0, int limit = 100}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/artists/$artistId/podcasts?skip=$skip&limit=$limit'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) {
          // Convert podcast JSON to ContentItem
          final podcast = json as Map<String, dynamic>;
          return ContentItem(
            id: podcast['id']?.toString() ?? '',
            title: podcast['title'] ?? '',
            creator: podcast['creator_name'] ?? 'Christ Tabernacle',
            description: podcast['description'],
            coverImage: podcast['cover_image'] != null 
                ? getMediaUrl(podcast['cover_image']) 
                : null,
            audioUrl: podcast['audio_url'] != null 
                ? getMediaUrl(podcast['audio_url']) 
                : null,
            videoUrl: podcast['video_url'] != null 
                ? getMediaUrl(podcast['video_url']) 
                : null,
            duration: podcast['duration'] != null 
                ? Duration(seconds: podcast['duration'] as int) 
                : null,
            category: _getCategoryName(podcast['category_id'] as int?),
            plays: podcast['plays_count'] ?? 0,
            createdAt: podcast['created_at'] != null
                ? DateTime.parse(podcast['created_at'])
                : DateTime.now(),
          );
        }).toList();
      }
      _throwHttpFailure('Failed to get artist podcasts', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error getting artist podcasts', e);
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

  // ============ Additional Admin Methods ============

  /// Approve a specific podcast
  Future<bool> approvePodcast(int podcastId) async {
    return approveContent('podcast', podcastId);
  }

  /// Reject a specific podcast
  Future<bool> rejectPodcast(int podcastId, {String? reason}) async {
    return rejectContent('podcast', podcastId, reason: reason);
  }

  /// Delete a specific podcast
  Future<bool> deletePodcast(int podcastId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/podcasts/$podcastId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _throwOperationError('Error deleting podcast', e);
    }
  }

  /// Get all users (admin only)
  Future<List<dynamic>> getUsers({int skip = 0, int limit = 100}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/admin/users?skip=$skip&limit=$limit'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      }
      _throwHttpFailure('Failed to get users', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching users', e);
    }
  }

  /// Update user admin status
  Future<bool> updateUserAdmin(int userId, bool isAdmin) async {
    try {
      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/admin/users/$userId/admin'),
        headers: await _getHeaders(),
        body: json.encode({'is_admin': isAdmin}),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error updating user admin status', e);
    }
  }

  /// Delete a user (admin only)
  Future<bool> deleteUser(int userId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/admin/users/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      _throwOperationError('Error deleting user', e);
    }
  }

  // ============ Events API Methods ============

  /// Create a new event
  Future<Map<String, dynamic>> createEvent({
    required String title,
    String? description,
    required DateTime eventDate,
    String? location,
    int? maxAttendees,
    String? coverImage,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description,
        'event_date': eventDate.toIso8601String(),
        'location': location,
        'max_attendees': maxAttendees ?? 0,
        'cover_image': coverImage,
      }..removeWhere((k, v) => v == null);

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/events/'),
        headers: await _getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to create event', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error creating event', e);
    }
  }

  /// Get list of events
  Future<Map<String, dynamic>> getEvents({
    int skip = 0,
    int limit = 20,
    String? statusFilter,
    bool upcomingOnly = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (statusFilter != null) queryParams['status_filter'] = statusFilter;
      if (upcomingOnly) queryParams['upcoming_only'] = 'true';

      final uri = Uri.parse('$baseUrl/events/').replace(queryParameters: queryParams);
      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to fetch events', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching events', e);
    }
  }

  /// Get event details by ID
  Future<Map<String, dynamic>> getEvent(int eventId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to fetch event', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching event', e);
    }
  }

  /// Request to join an event
  Future<Map<String, dynamic>> joinEvent(int eventId) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/events/$eventId/join'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to join event', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error joining event', e);
    }
  }

  /// Leave an event
  Future<bool> leaveEvent(int eventId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/events/$eventId/leave'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error leaving event', e);
    }
  }

  /// Get event attendees
  Future<List<dynamic>> getEventAttendees(int eventId, {String? statusFilter}) async {
    try {
      var uri = Uri.parse('$baseUrl/events/$eventId/attendees');
      if (statusFilter != null) {
        uri = uri.replace(queryParameters: {'status_filter': statusFilter});
      }

      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _throwHttpFailure('Failed to fetch attendees', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching attendees', e);
    }
  }

  /// Update attendee status (approve/reject)
  Future<bool> updateAttendeeStatus(int eventId, int userId, String status) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/events/$eventId/attendees/$userId'),
        headers: await _getHeaders(),
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error updating attendee status', e);
    }
  }

  /// Get my hosted events
  Future<List<dynamic>> getMyHostedEvents() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/events/my/hosted'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _throwHttpFailure('Failed to fetch hosted events', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching hosted events', e);
    }
  }

  /// Get events I'm attending
  Future<List<dynamic>> getMyAttendingEvents() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/events/my/attending'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      _throwHttpFailure('Failed to fetch attending events', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching attending events', e);
    }
  }

  /// Delete/cancel an event
  Future<bool> deleteEvent(int eventId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error deleting event', e);
    }
  }

  // ============================================
  // NOTIFICATIONS API
  // ============================================

  /// Get notifications for current user
  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/notifications').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (unreadOnly) 'unread_only': 'true',
        },
      );

      final response = await _httpClient.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      _throwHttpFailure('Failed to fetch notifications', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching notifications', e);
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unread_count'] as int? ?? 0;
      }
      _throwHttpFailure('Failed to fetch unread count', response.statusCode, body: response.body);
    } catch (e) {
      _throwOperationError('Error fetching unread count', e);
    }
  }

  /// Mark specific notifications as read
  Future<bool> markNotificationsAsRead(List<int> notificationIds) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/notifications/read'),
        headers: await _getHeaders(),
        body: json.encode({'notification_ids': notificationIds}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error marking notifications as read', e);
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error marking all notifications as read', e);
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error deleting notification', e);
    }
  }

  /// Delete all notifications
  Future<bool> deleteAllNotifications({bool readOnly = false}) async {
    try {
      final uri = Uri.parse('$baseUrl/notifications').replace(
        queryParameters: readOnly ? {'read_only': 'true'} : null,
      );

      final response = await _httpClient.delete(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      _throwOperationError('Error deleting all notifications', e);
    }
  }
}
