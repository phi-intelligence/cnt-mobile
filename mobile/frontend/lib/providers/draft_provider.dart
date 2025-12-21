import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Draft types matching the backend DraftType enum
enum DraftType {
  videoPodcast('video_podcast'),
  audioPodcast('audio_podcast'),
  communityPost('community_post'),
  quotePost('quote_post');

  final String value;
  const DraftType(this.value);

  static DraftType? fromString(String? value) {
    if (value == null) return null;
    for (final type in DraftType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Draft status enum
enum DraftStatus {
  editing('editing'),
  ready('ready');

  final String value;
  const DraftStatus(this.value);
}

/// Content draft model for mobile
class ContentDraft {
  final int? id;
  final int userId;
  final DraftType draftType;
  final String? title;
  final String? description;
  final String? originalMediaUrl;
  final String? editedMediaUrl;
  final String? thumbnailUrl;
  final String? content;
  final String? category;
  final Map<String, dynamic>? editingState;
  final int? duration;
  final DraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentDraft({
    this.id,
    required this.userId,
    required this.draftType,
    this.title,
    this.description,
    this.originalMediaUrl,
    this.editedMediaUrl,
    this.thumbnailUrl,
    this.content,
    this.category,
    this.editingState,
    this.duration,
    this.status = DraftStatus.editing,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ContentDraft.fromJson(Map<String, dynamic> json) {
    return ContentDraft(
      id: json['id'] as int?,
      userId: json['user_id'] as int? ?? 0,
      draftType: DraftType.fromString(json['draft_type'] as String?) ?? DraftType.audioPodcast,
      title: json['title'] as String?,
      description: json['description'] as String?,
      originalMediaUrl: json['original_media_url'] as String?,
      editedMediaUrl: json['edited_media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      content: json['content'] as String?,
      category: json['category'] as String?,
      editingState: json['editing_state'] as Map<String, dynamic>?,
      duration: json['duration'] as int?,
      status: json['status'] == 'ready' ? DraftStatus.ready : DraftStatus.editing,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'draft_type': draftType.value,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (originalMediaUrl != null) 'original_media_url': originalMediaUrl,
      if (editedMediaUrl != null) 'edited_media_url': editedMediaUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (editingState != null) 'editing_state': editingState,
      if (duration != null) 'duration': duration,
      'status': status.value,
    };
  }

  ContentDraft copyWith({
    int? id,
    int? userId,
    DraftType? draftType,
    String? title,
    String? description,
    String? originalMediaUrl,
    String? editedMediaUrl,
    String? thumbnailUrl,
    String? content,
    String? category,
    Map<String, dynamic>? editingState,
    int? duration,
    DraftStatus? status,
  }) {
    return ContentDraft(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      draftType: draftType ?? this.draftType,
      title: title ?? this.title,
      description: description ?? this.description,
      originalMediaUrl: originalMediaUrl ?? this.originalMediaUrl,
      editedMediaUrl: editedMediaUrl ?? this.editedMediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      content: content ?? this.content,
      category: category ?? this.category,
      editingState: editingState ?? this.editingState,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get display name for the draft type
  String get typeDisplayName {
    switch (draftType) {
      case DraftType.videoPodcast:
        return 'Video';
      case DraftType.audioPodcast:
        return 'Audio';
      case DraftType.communityPost:
        return 'Post';
      case DraftType.quotePost:
        return 'Quote';
    }
  }
}

class DraftProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ContentDraft> _drafts = [];
  bool _isLoading = false;
  String? _error;
  int _totalDrafts = 0;

  List<ContentDraft> get drafts => _drafts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalDrafts => _totalDrafts;
  bool get hasDrafts => _drafts.isNotEmpty;

  /// Fetch user's drafts from the backend
  Future<void> fetchDrafts({DraftType? draftType}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.getDrafts(
        draftType: draftType?.value,
        limit: 50,
      );

      final draftsData = result['drafts'] as List<dynamic>? ?? [];
      _drafts = draftsData
          .map((d) => ContentDraft.fromJson(d as Map<String, dynamic>))
          .toList();
      _totalDrafts = result['total'] as int? ?? _drafts.length;
      _error = null;
    } catch (e) {
      _error = 'Failed to load drafts: $e';
      print('Error fetching drafts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new draft
  Future<ContentDraft?> createDraft(ContentDraft draft) async {
    try {
      final result = await _api.createDraft(draft.toJson());
      if (result != null) {
        final newDraft = ContentDraft.fromJson(result);
        _drafts.insert(0, newDraft);
        _totalDrafts++;
        notifyListeners();
        return newDraft;
      }
      return null;
    } catch (e) {
      print('Error creating draft: $e');
      return null;
    }
  }

  /// Update an existing draft
  Future<ContentDraft?> updateDraft(ContentDraft draft) async {
    if (draft.id == null) return null;

    try {
      final result = await _api.updateDraft(draft.id!, draft.toJson());
      if (result != null) {
        final updatedDraft = ContentDraft.fromJson(result);
        final index = _drafts.indexWhere((d) => d.id == draft.id);
        if (index != -1) {
          _drafts[index] = updatedDraft;
          notifyListeners();
        }
        return updatedDraft;
      }
      return null;
    } catch (e) {
      print('Error updating draft: $e');
      return null;
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(int draftId) async {
    try {
      final success = await _api.deleteDraft(draftId);
      if (success) {
        _drafts.removeWhere((d) => d.id == draftId);
        _totalDrafts--;
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error deleting draft: $e');
      return false;
    }
  }

  /// Get a specific draft by ID
  Future<ContentDraft?> getDraft(int draftId) async {
    try {
      final result = await _api.getDraft(draftId);
      if (result != null) {
        return ContentDraft.fromJson(result);
      }
      return null;
    } catch (e) {
      print('Error getting draft: $e');
      return null;
    }
  }

  /// Save or update a draft (convenience method)
  Future<ContentDraft?> saveDraft(ContentDraft draft) async {
    if (draft.id != null) {
      return updateDraft(draft);
    } else {
      return createDraft(draft);
    }
  }
}
