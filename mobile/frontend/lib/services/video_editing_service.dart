import 'dart:io' if (dart.library.html) '../utils/file_stub.dart' as io;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'api_service.dart';
import 'package:http/http.dart' as http;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/text_overlay.dart';

/// Video Editing Service
/// Handles video editing operations: trim, cut, audio track manipulation, rotation, filters
/// 
/// Processing Strategy:
/// - Mobile: Uses local FFmpeg for faster processing (local files only)
/// - Web/Network URLs: Falls back to server API for compatibility
/// 
/// Environment Handling:
/// - Automatically detects local files vs network URLs
/// - Uses getMediaUrl() for consistent URL resolution
/// - Handles both development and production environments
class VideoEditingService {
  final ApiService _apiService = ApiService();

  /// Trim video - Cut video from start time to end time
  /// 
  /// Processing Logic:
  /// - Local files (mobile): Uses FFmpeg locally for instant trimming
  /// - Network URLs: Uses server API for processing
  /// 
  /// Returns:
  /// - Mobile: Local file path to trimmed video
  /// - Web: Full URL to trimmed video (CloudFront or localhost)
  Future<String?> trimVideo(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Use local editing on mobile for faster processing
    if (!kIsWeb && !inputPath.startsWith('http')) {
      return _trimVideoLocally(inputPath, startTime, endTime, onProgress: onProgress, onError: onError);
    }
    
    // Fallback to server-side processing for web or network URLs
    return _trimVideoServer(inputPath, startTime, endTime, onProgress: onProgress, onError: onError);
  }

  /// Local trim implementation using FFmpeg
  /// Uses fast seek (-ss before -i) and stream copy (-c copy) for instant trimming
  Future<String?> _trimVideoLocally(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/trimmed_$timestamp.mp4';
      
      onProgress?.call(10);
      
      // Calculate start time in seconds and duration
      final startSec = startTime.inMilliseconds / 1000.0;
      final durationSec = (endTime - startTime).inMilliseconds / 1000.0;
      
      // FFmpeg command: fast seek + stream copy (no re-encoding = instant)
      // -ss before -i = input seeking (fast)
      // -c copy = copy streams without re-encoding
      final cmd = '-ss $startSec -i "$inputPath" -t $durationSec -c copy -y "$outputPath"';
      
      debugPrint('FFmpeg trim command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100);
        debugPrint('Video trim successful: $outputPath');
        return outputPath;
      }
      
      final logs = await session.getAllLogsAsString();
      onError?.call('Video trim failed: $logs');
      debugPrint('FFmpeg trim failed: $logs');
      return null;
    } catch (e) {
      onError?.call('Error trimming video locally: $e');
      debugPrint('Error trimming video locally: $e');
      // Fallback to server
      return _trimVideoServer(inputPath, startTime, endTime, onProgress: onProgress, onError: onError);
    }
  }

  /// Server-side trim implementation (fallback)
  Future<String?> _trimVideoServer(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final result = await _apiService.trimVideo(
        inputPath,
        startTime.inSeconds.toDouble(),
        endTime.inSeconds.toDouble(),
      );

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      // On web, return the URL directly (don't download/save files)
      if (kIsWeb) {
        return _apiService.getMediaUrl(outputUrl);
      }

      // On mobile, download the edited video and save to temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = io.File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }

      onError?.call('Failed to download edited video');
      return null;
    } catch (e) {
      onError?.call('Error trimming video: $e');
      return null;
    }
  }

  /// Remove audio track from video
  /// Uses local FFmpeg on mobile, server API on web
  Future<String?> removeAudioTrack(
    String inputPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Use local editing on mobile for faster processing
    if (!kIsWeb && !inputPath.startsWith('http')) {
      return _removeAudioLocally(inputPath, onProgress: onProgress, onError: onError);
    }
    
    // Fallback to server-side processing
    return _removeAudioServer(inputPath, onProgress: onProgress, onError: onError);
  }

  /// Local remove audio implementation using FFmpeg
  Future<String?> _removeAudioLocally(
    String inputPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/no_audio_$timestamp.mp4';
      
      onProgress?.call(10);
      
      // FFmpeg command: -an removes audio, -c:v copy keeps video without re-encoding
      final cmd = '-i "$inputPath" -an -c:v copy -y "$outputPath"';
      
      debugPrint('FFmpeg remove audio command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100);
        debugPrint('Remove audio successful: $outputPath');
        return outputPath;
      }
      
      final logs = await session.getAllLogsAsString();
      onError?.call('Remove audio failed: $logs');
      debugPrint('FFmpeg remove audio failed: $logs');
      return null;
    } catch (e) {
      onError?.call('Error removing audio locally: $e');
      debugPrint('Error removing audio locally: $e');
      // Fallback to server
      return _removeAudioServer(inputPath, onProgress: onProgress, onError: onError);
    }
  }

  /// Server-side remove audio implementation (fallback)
  Future<String?> _removeAudioServer(
    String inputPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final result = await _apiService.removeAudio(inputPath);

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        return _apiService.getMediaUrl(outputUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = io.File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }

      onError?.call('Failed to download edited video');
      return null;
    } catch (e) {
      onError?.call('Error removing audio: $e');
      return null;
    }
  }

  /// Add audio track to video
  /// Uses local FFmpeg on mobile, server API on web
  Future<String?> addAudioTrack(
    String videoPath,
    String audioPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Use local editing on mobile
    if (!kIsWeb && !videoPath.startsWith('http') && !audioPath.startsWith('http')) {
      return _addAudioLocally(videoPath, audioPath, onProgress: onProgress, onError: onError);
    }
    
    // Fallback to server-side processing
    return _addAudioServer(videoPath, audioPath, onProgress: onProgress, onError: onError);
  }

  /// Local add audio implementation using FFmpeg
  Future<String?> _addAudioLocally(
    String videoPath,
    String audioPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/with_audio_$timestamp.mp4';
      
      onProgress?.call(10);
      
      // FFmpeg command: add audio to video
      // -c:v copy = keep video without re-encoding
      // -c:a aac = encode audio to AAC
      // -map 0:v:0 -map 1:a:0 = take video from first input, audio from second
      // -shortest = end at shortest stream
      final cmd = '-i "$videoPath" -i "$audioPath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest -y "$outputPath"';
      
      debugPrint('FFmpeg add audio command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100);
        debugPrint('Add audio successful: $outputPath');
        return outputPath;
      }
      
      final logs = await session.getAllLogsAsString();
      onError?.call('Add audio failed: $logs');
      debugPrint('FFmpeg add audio failed: $logs');
      return null;
    } catch (e) {
      onError?.call('Error adding audio locally: $e');
      debugPrint('Error adding audio locally: $e');
      // Fallback to server
      return _addAudioServer(videoPath, audioPath, onProgress: onProgress, onError: onError);
    }
  }

  /// Server-side add audio implementation (fallback)
  Future<String?> _addAudioServer(
    String videoPath,
    String audioPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final result = await _apiService.addAudio(videoPath, audioPath);

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        return _apiService.getMediaUrl(outputUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = io.File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }

      onError?.call('Failed to download edited video');
      return null;
    } catch (e) {
      onError?.call('Error adding audio: $e');
      return null;
    }
  }

  /// Replace audio track in video
  Future<String?> replaceAudioTrack(
    String videoPath,
    String audioPath, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    return addAudioTrack(videoPath, audioPath, onProgress: onProgress, onError: onError);
  }

  /// Apply filters to video
  /// Server-side only (complex filters better handled by server)
  Future<String?> applyFilters(
    String inputPath,
    Map<String, double> filters, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Always use server for filters
    return _applyFiltersServer(inputPath, filters, onProgress: onProgress, onError: onError);
  }

  /// Server-side apply filters implementation
  Future<String?> _applyFiltersServer(
    String inputPath,
    Map<String, double> filters, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final result = await _apiService.applyVideoFilters(
        inputPath,
        brightness: filters['brightness'],
        contrast: filters['contrast'],
        saturation: filters['saturation'],
      );

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        return _apiService.getMediaUrl(outputUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = io.File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }

      onError?.call('Failed to download edited video');
      return null;
    } catch (e) {
      onError?.call('Error applying filters: $e');
      return null;
    }
  }

  /// Rotate video by specified degrees (90, 180, 270)
  /// Uses local FFmpeg on mobile, server API on web
  Future<String?> rotateVideo(
    String inputPath,
    int degrees, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Use local editing on mobile
    if (!kIsWeb && !inputPath.startsWith('http')) {
      return _rotateVideoLocally(inputPath, degrees, onProgress: onProgress, onError: onError);
    }
    
    // Fallback to server
    return _rotateVideoServer(inputPath, degrees, onProgress: onProgress, onError: onError);
  }

  /// Local rotate implementation using FFmpeg
  Future<String?> _rotateVideoLocally(
    String inputPath,
    int degrees, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/rotated_$timestamp.mp4';
      
      onProgress?.call(10);
      
      // Map degrees to FFmpeg filter
      // transpose=1 = 90 degrees clockwise
      // rotate=PI = 180 degrees
      // transpose=2 = 90 degrees counter-clockwise (270)
      String filter;
      switch (degrees) {
        case 90:
          filter = 'transpose=1';
          break;
        case 180:
          filter = 'rotate=PI';
          break;
        case 270:
          filter = 'transpose=2';
          break;
        default:
          onError?.call('Invalid rotation degrees: $degrees');
          return null;
      }
      
      // FFmpeg command with video filter, keep audio
      final cmd = '-i "$inputPath" -vf "$filter" -c:a copy -y "$outputPath"';
      
      debugPrint('FFmpeg rotate command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(100);
        debugPrint('Video rotation successful: $outputPath');
        return outputPath;
      }
      
      final logs = await session.getAllLogsAsString();
      onError?.call('Video rotation failed: $logs');
      debugPrint('FFmpeg rotate failed: $logs');
      return null;
    } catch (e) {
      onError?.call('Error rotating video locally: $e');
      debugPrint('Error rotating video locally: $e');
      return _rotateVideoServer(inputPath, degrees, onProgress: onProgress, onError: onError);
    }
  }

  /// Server-side rotate implementation (fallback)
  Future<String?> _rotateVideoServer(
    String inputPath,
    int degrees, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final result = await _apiService.rotateVideo(inputPath, degrees);

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        return _apiService.getMediaUrl(outputUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = io.File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }

      onError?.call('Failed to download rotated video');
      return null;
    } catch (e) {
      onError?.call('Error rotating video: $e');
      return null;
    }
  }

  /// Burn text overlays into video
  /// Uses FFmpeg drawtext filter
  Future<String?> burnTextOverlays(
    String inputPath,
    List<TextOverlay> overlays, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    if (kIsWeb || inputPath.startsWith('http')) {
      onError?.call('Burn text overlays not supported on web');
      return null;
    }
    
    if (overlays.isEmpty) {
      return inputPath; // Nothing to burn
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/with_text_$timestamp.mp4';
      
      onProgress?.call(10);
      
      // Build drawtext filters for each overlay
      final filterList = <String>[];
      
      for (final overlay in overlays) {
        // Escape special characters for FFmpeg
        // For drawtext, we need to escape: ' \ : 
        String text = overlay.text;
        text = text.replaceAll('\\', '\\\\\\\\'); // Escape backslash
        text = text.replaceAll("'", "'\\''"); // Escape single quote
        text = text.replaceAll(':', '\\:'); // Escape colon
        
        // Convert color int to FFmpeg hex format (#RRGGBB)
        final colorHex = '#${(overlay.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        
        // Calculate position - x and y are 0.0 to 1.0, convert to FFmpeg expression
        // Center the text at the position (subtract half text width/height)
        final xPos = '(w*${overlay.x.toStringAsFixed(4)}-tw/2)';
        final yPos = '(h*${overlay.y.toStringAsFixed(4)}-th/2)';
        
        // Time range for overlay visibility
        final startSec = overlay.startTime.inMilliseconds / 1000.0;
        final endSec = overlay.endTime.inMilliseconds / 1000.0;
        
        // Build drawtext filter - use fontfile for Android compatibility
        // On Android, we use the default sans-serif font
        final filter = "drawtext=text='$text':x=$xPos:y=$yPos:fontsize=${overlay.fontSize.toInt()}:fontcolor=$colorHex:enable='between(t\\,$startSec\\,$endSec)'";
        filterList.add(filter);
      }
      
      final filters = filterList.join(',');
      
      // FFmpeg command with video filter, keep audio
      // Use -preset ultrafast for faster encoding
      final cmd = '-i "$inputPath" -vf "$filters" -c:v libx264 -preset ultrafast -c:a copy -y "$outputPath"';
      
      debugPrint('FFmpeg burn text command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      onProgress?.call(90);
      
      if (ReturnCode.isSuccess(returnCode)) {
        // Verify file exists
        final file = io.File(outputPath);
        if (await file.exists()) {
          onProgress?.call(100);
          debugPrint('Burn text overlays successful: $outputPath');
          return outputPath;
        }
      }
      
      // Get only the last few lines of error (not the entire FFmpeg banner)
      final logs = await session.getAllLogsAsString();
      final errorLines = logs?.split('\n').where((line) => 
        line.contains('Error') || 
        line.contains('error') || 
        line.contains('Invalid') ||
        line.contains('failed')
      ).take(5).join('\n');
      
      final errorMsg = errorLines?.isNotEmpty == true 
          ? errorLines 
          : 'Text overlay encoding failed';
      onError?.call('Burn text overlays failed: $errorMsg');
      debugPrint('FFmpeg burn text failed. Return code: ${returnCode?.getValue()}');
      return null;
    } catch (e) {
      onError?.call('Error burning text overlays: $e');
      debugPrint('Error burning text overlays: $e');
      return null;
    }
  }

  /// Get video metadata using FFprobe
  Future<Map<String, dynamic>?> getVideoMetadata(String videoPath) async {
    if (kIsWeb || videoPath.startsWith('http')) {
      return null;
    }
    
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();
      
      if (info != null) {
        // Get duration
        final durationStr = info.getDuration();
        final durationMs = durationStr != null 
            ? (double.tryParse(durationStr) ?? 0) * 1000 
            : 0;
        
        // Get video stream info
        int? width;
        int? height;
        int? rotation;
        final streams = info.getStreams();
        if (streams != null) {
          for (final stream in streams) {
            if (stream.getType() == 'video') {
              width = stream.getWidth();
              height = stream.getHeight();
              // Check for rotation in tags
              final tags = stream.getAllProperties();
              if (tags != null && tags['tags'] != null) {
                rotation = int.tryParse(tags['tags']['rotate']?.toString() ?? '0');
              }
              break;
            }
          }
        }
        
        // Get file size
        final sizeStr = info.getSize();
        final fileSize = sizeStr != null ? int.tryParse(sizeStr) : null;
        
        return {
          'duration': Duration(milliseconds: durationMs.toInt()),
          'width': width,
          'height': height,
          'fileSize': fileSize,
          'rotation': rotation ?? 0,
          'format': info.getFormat(),
          'bitrate': info.getBitrate(),
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting video metadata: $e');
      return null;
    }
  }

  /// Get video duration
  Future<Duration?> getVideoDuration(String videoPath) async {
    final metadata = await getVideoMetadata(videoPath);
    if (metadata != null && metadata['duration'] != null) {
      return metadata['duration'] as Duration;
    }
    return null;
  }
  
  /// Generate thumbnail from video at specific timestamp
  Future<String?> generateThumbnail(
    String videoPath,
    Duration timestamp, {
    int width = 320,
    int height = 180,
  }) async {
    if (kIsWeb || videoPath.startsWith('http')) {
      return null;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/thumbnail_$ts.jpg';
      
      final seekSec = timestamp.inMilliseconds / 1000.0;
      
      // FFmpeg command to extract frame at timestamp
      // -ss before -i for fast seeking
      // -vframes 1 = extract single frame
      // -vf scale = resize to specified dimensions
      final cmd = '-ss $seekSec -i "$videoPath" -vframes 1 -vf "scale=$width:$height" -y "$outputPath"';
      
      debugPrint('FFmpeg thumbnail command: $cmd');
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('Thumbnail generated: $outputPath');
        return outputPath;
      }
      
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpeg thumbnail failed: $logs');
      return null;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }
}
