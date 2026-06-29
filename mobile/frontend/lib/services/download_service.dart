import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/content_item.dart';
import 'api_service.dart';
import '../utils/app_logger.dart';
import '../utils/pinned_http_client.dart';

/// Download status enum
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
}

/// Download progress model
class DownloadProgress {
  final String itemId;
  final double progress; // 0.0 to 1.0
  final DownloadStatus status;
  final String? error;

  DownloadProgress({
    required this.itemId,
    required this.progress,
    required this.status,
    this.error,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Database? _database;

  // Progress stream for UI updates
  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  // Track active downloads
  final Map<String, DownloadStatus> _downloadStatuses = {};

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      AppLogger.debug('✅ DownloadService: Initializing database...');
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'downloads.db');

      final db = await openDatabase(
        path,
        version: 2, // Bumped version for media_type support
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE downloads (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              creator TEXT,
              cover_image TEXT,
              media_url TEXT NOT NULL,
              media_type TEXT NOT NULL,
              local_path TEXT NOT NULL,
              duration INTEGER,
              category TEXT,
              file_size INTEGER,
              downloaded_at INTEGER NOT NULL
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Migrate from audio_url to media_url/media_type
            await db.execute('ALTER TABLE downloads RENAME COLUMN audio_url TO media_url');
            await db.execute("ALTER TABLE downloads ADD COLUMN media_type TEXT DEFAULT 'audio'");
          }
        },
      );
      AppLogger.debug('✅ DownloadService: Database initialized successfully');
      return db;
    } catch (e) {
      AppLogger.debug('❌ DownloadService: Error initializing database: $e');
      rethrow;
    }
  }

  /// Get download status for an item
  DownloadStatus getStatus(String id) {
    return _downloadStatuses[id] ?? DownloadStatus.pending;
  }

  /// Download content with progress reporting
  Future<bool> downloadContent(
    ContentItem item, {
    Function(double)? onProgress,
  }) async {
    try {
      // Determine media URL and type
      String? mediaUrl = item.audioUrl ?? item.videoUrl;
      String mediaType = item.audioUrl != null ? 'audio' : 'video';

      if (mediaUrl == null || mediaUrl.isEmpty) {
        _emitProgress(item.id, 0.0, DownloadStatus.failed, error: 'No media URL');
        return false;
      }

      // Resolve relative URLs via ApiService so dev/prod S3 logic is reused
      if (!mediaUrl.startsWith('http://') && !mediaUrl.startsWith('https://')) {
        mediaUrl = ApiService().getMediaUrl(mediaUrl);
      }

      final db = await database;

      // Check if already downloaded
      final existing = await db.query(
        'downloads',
        where: 'id = ?',
        whereArgs: [item.id],
      );

      if (existing.isNotEmpty) {
        _emitProgress(item.id, 1.0, DownloadStatus.completed);
        return true;
      }

      // Start download
      _downloadStatuses[item.id] = DownloadStatus.downloading;
      _emitProgress(item.id, 0.0, DownloadStatus.downloading);

      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create HTTP client for streaming download
      final request = http.Request('GET', Uri.parse(mediaUrl));
      final client = PinnedHttpClient.instance;
      final response = await client.send(request);

      if (response.statusCode != 200) {
        _emitProgress(item.id, 0.0, DownloadStatus.failed,
            error: 'HTTP ${response.statusCode}');
        return false;
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final bytes = <int>[];

      // Stream download with progress
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;

        final progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
        _emitProgress(item.id, progress, DownloadStatus.downloading);
        onProgress?.call(progress);
      }

      // Determine file extension
      final extension = mediaType == 'video' ? 'mp4' : 'mp3';
      final fileName = '${item.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Save to database
      await db.insert('downloads', {
        'id': item.id,
        'title': item.title,
        'creator': item.creator,
        'cover_image': item.coverImage ?? '',
        'media_url': mediaUrl,
        'media_type': mediaType,
        'local_path': file.path,
        'duration': item.duration?.inSeconds,
        'category': item.category,
        'file_size': await file.length(),
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      });

      _downloadStatuses[item.id] = DownloadStatus.completed;
      _emitProgress(item.id, 1.0, DownloadStatus.completed);

      return true;
    } catch (e) {
      AppLogger.debug('Error downloading content: $e');
      _downloadStatuses[item.id] = DownloadStatus.failed;
      _emitProgress(item.id, 0.0, DownloadStatus.failed, error: e.toString());
      return false;
    }
  }

  void _emitProgress(String itemId, double progress, DownloadStatus status,
      {String? error}) {
    _progressController.add(DownloadProgress(
      itemId: itemId,
      progress: progress,
      status: status,
      error: error,
    ));
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    try {
      final db = await database;
      return await db.query(
        'downloads',
        orderBy: 'downloaded_at DESC',
      );
    } catch (e) {
      AppLogger.debug('Error getting downloads: $e');
      return [];
    }
  }

  Future<bool> deleteDownload(String id) async {
    try {
      final db = await database;
      
      // Get local path
      final downloads = await db.query(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (downloads.isNotEmpty) {
        final localPath = downloads.first['local_path'] as String;
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Remove from database
      await db.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      return true;
    } catch (e) {
      AppLogger.debug('Error deleting download: $e');
      return false;
    }
  }

  Future<String?> getLocalPath(String id) async {
    try {
      final db = await database;
      final downloads = await db.query(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
        columns: ['local_path'],
      );
      
      if (downloads.isNotEmpty) {
        final localPath = downloads.first['local_path'] as String;
        final file = File(localPath);
        if (await file.exists()) {
          return localPath;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isDownloaded(String id) async {
    try {
      final db = await database;
      final downloads = await db.query(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
      return downloads.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

