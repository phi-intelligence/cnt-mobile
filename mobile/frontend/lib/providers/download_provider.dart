import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/download_service.dart';
import '../models/content_item.dart';
import '../utils/app_logger.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _service = DownloadService();

  // Track download progress for each item
  final Map<String, DownloadProgress> _downloads = {};

  // Completed downloads from database
  List<Map<String, dynamic>> _completedDownloads = [];

  bool _isLoading = false;
  StreamSubscription<DownloadProgress>? _progressSubscription;

  DownloadProvider() {
    _initProgressListener();
    loadDownloads();
  }

  void _initProgressListener() {
    _progressSubscription = _service.progressStream.listen((progress) {
      _downloads[progress.itemId] = progress;
      notifyListeners();

      // Reload completed downloads when a download finishes
      if (progress.status == DownloadStatus.completed) {
        loadDownloads();
      }
    });
  }

  List<Map<String, dynamic>> get completedDownloads => _completedDownloads;
  int get downloadCount => _completedDownloads.length;
  bool get isLoading => _isLoading;

  /// Get download status for an item
  DownloadStatus getDownloadStatus(String id) {
    final progress = _downloads[id];
    if (progress != null) {
      return progress.status;
    }

    // Check if already downloaded
    final isDownloaded =
        _completedDownloads.any((d) => d['id'].toString() == id);
    return isDownloaded ? DownloadStatus.completed : DownloadStatus.pending;
  }

  /// Get download progress (0.0 to 1.0) for an item
  double getProgress(String id) {
    return _downloads[id]?.progress ?? 0.0;
  }

  /// Check if item is currently downloading
  bool isDownloading(String id) {
    return _downloads[id]?.status == DownloadStatus.downloading;
  }

  /// Check if item is downloaded
  bool isDownloaded(String id) {
    if (_downloads[id]?.status == DownloadStatus.completed) return true;
    return _completedDownloads.any((d) => d['id'].toString() == id);
  }

  /// Load completed downloads from database
  Future<void> loadDownloads() async {
    _isLoading = true;
    notifyListeners();

    try {
      _completedDownloads = await _service.getDownloads();
    } catch (e) {
      AppLogger.debug('Error loading downloads: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start downloading an item
  Future<bool> downloadItem(ContentItem item) async {
    // Update status immediately for optimistic UI
    _downloads[item.id] = DownloadProgress(
      itemId: item.id,
      progress: 0.0,
      status: DownloadStatus.downloading,
    );
    notifyListeners();

    final success = await _service.downloadContent(item);

    if (success) {
      await loadDownloads();
    }

    return success;
  }

  /// Delete a downloaded item
  Future<bool> deleteDownload(String id) async {
    final success = await _service.deleteDownload(id);
    if (success) {
      _completedDownloads.removeWhere((d) => d['id'].toString() == id);
      _downloads.remove(id);
      notifyListeners();
    }
    return success;
  }

  /// Get local path for a downloaded item
  Future<String?> getLocalPath(String id) async {
    return await _service.getLocalPath(id);
  }

  /// Calculate total storage used by downloads
  int get totalStorageBytes {
    int total = 0;
    for (final download in _completedDownloads) {
      total += (download['file_size'] as int?) ?? 0;
    }
    return total;
  }

  /// Get human-readable storage size
  String get formattedStorageSize {
    final bytes = totalStorageBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
