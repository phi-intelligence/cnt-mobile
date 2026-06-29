import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'api_service.dart';
import '../utils/pinned_http_client.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Audio Editing Service
/// Handles audio editing operations: trim, merge
/// 
/// Processing Strategy:
/// - Mobile: Uses local FFmpeg for faster processing (local files only)
/// - Web/Network URLs: Falls back to server API for compatibility
/// 
/// Environment Handling:
/// - Automatically detects local files vs network URLs
/// - Uses getMediaUrl() for consistent URL resolution
/// - Handles both development and production environments
/// 
/// Note: Fade effects are not included (removed to match mobile app feature set)
class AudioEditingService {
  final ApiService _apiService = ApiService();

  /// Trim audio - Cut audio from start time to end time
  /// 
  /// Processing Logic:
  /// - Local files (mobile): Uses FFmpeg locally for instant trimming
  /// - Network URLs: Uses server API for processing
  /// 
  /// Returns:
  /// - Mobile: Local file path to trimmed audio
  /// - Web: Full URL to trimmed audio (CloudFront or localhost)
  Future<String?> trimAudio(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    // Use local trimming on mobile for faster processing
    if (!kIsWeb && !inputPath.startsWith('http')) {
      return _trimAudioLocally(inputPath, startTime, endTime, onProgress: onProgress, onError: onError);
    }
    
    // Fallback to server-side processing for web or network URLs
    return _trimAudioServer(inputPath, startTime, endTime, onProgress: onProgress, onError: onError);
  }

  /// Local trim implementation using FFmpeg
  /// Uses fast seek (-ss before -i) for instant trimming without full re-encoding
  Future<String?> _trimAudioLocally(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/trimmed_$timestamp.m4a';
      
      onProgress?.call(10);
      
      // Calculate start time in seconds and duration
      final startSec = startTime.inMilliseconds / 1000.0;
      final durationSec = (endTime - startTime).inMilliseconds / 1000.0;
      
      // Small delay to allow UI to render loading dialog
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint('🎵 Trimming audio locally: $inputPath');
      debugPrint('🎵 Start: $startSec sec, Duration: $durationSec sec');
      
      // FFmpeg command for audio trimming
      // -ss before -i = fast input seeking
      // -t = duration
      // -c:a aac = encode to AAC (M4A container)
      // -b:a 128k = bitrate
      final cmd = '-ss $startSec -i "$inputPath" -t $durationSec -c:a aac -b:a 128k -y "$outputPath"';
      
      debugPrint('🎵 FFmpeg trim command: $cmd');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      onProgress?.call(90);
      
      if (ReturnCode.isSuccess(returnCode)) {
        // Verify file exists
        final file = File(outputPath);
        if (await file.exists()) {
          onProgress?.call(100);
          debugPrint('🎵 Audio trim successful: $outputPath');
          return outputPath;
        }
      }
      
      final logs = await session.getAllLogsAsString();
      debugPrint('🎵 FFmpeg trim failed: $logs');
      onError?.call('Audio trim failed: $logs');
      return null;
    } catch (e) {
      debugPrint('🎵 Error trimming audio locally: $e');
      onError?.call('Error trimming audio locally: $e');
      return null;
    }
  }

  /// Server-side trim implementation
  Future<String?> _trimAudioServer(
    String inputPath,
    Duration startTime,
    Duration endTime, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      onProgress?.call(10);
      
      final result = await _apiService.trimAudio(
        inputPath,
        startTime.inSeconds.toDouble(),
        endTime.inSeconds.toDouble(),
      );

      onProgress?.call(60);

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        onProgress?.call(100);
        return _apiService.getMediaUrl(outputUrl);
      }

      // Download the edited audio
      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      onProgress?.call(80);
      
      final response = await PinnedHttpClient.instance.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        onProgress?.call(100);
        return savePath;
      }

      onError?.call('Failed to download edited audio');
      return null;
    } catch (e) {
      onError?.call('Error trimming audio: $e');
      return null;
    }
  }

  /// Merge multiple audio files into one
  /// Uses local FFmpeg on mobile, server API for web/network URLs
  Future<String?> mergeAudioFiles(
    List<String> inputPaths, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    if (inputPaths.isEmpty) {
      onError?.call('No audio files to merge');
      return null;
    }

    if (inputPaths.length == 1) {
      return inputPaths.first;
    }

    // Use local merging on mobile for local files
    if (!kIsWeb && inputPaths.every((path) => !path.startsWith('http'))) {
      return _mergeAudioLocally(inputPaths, onProgress: onProgress, onError: onError);
    }

    // Fallback to server for web or network URLs
    return _mergeAudioServer(inputPaths, onProgress: onProgress, onError: onError);
  }

  /// Local merge implementation using FFmpeg filter_complex
  /// This approach works reliably with different audio formats (MP3, M4A, WAV, etc.)
  Future<String?> _mergeAudioLocally(
    List<String> inputPaths, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/merged_$timestamp.m4a';
      
      onProgress?.call(10);
      
      debugPrint('🎵 Merging ${inputPaths.length} audio files locally...');
      
      // Small delay to allow UI to show loading dialog
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Build FFmpeg command with filter_complex concat
      // This approach handles different audio formats correctly
      
      // Build input arguments: -i "file1" -i "file2" ...
      final inputArgs = inputPaths.map((path) => '-i "$path"').join(' ');
      
      // Build filter inputs: [0:a][1:a][2:a]...
      final filterInputs = List.generate(inputPaths.length, (i) => '[$i:a]').join('');
      
      // Build filter: [0:a][1:a]concat=n=2:v=0:a=1[out]
      final filter = '${filterInputs}concat=n=${inputPaths.length}:v=0:a=1[out]';
      
      // Full command with filter_complex
      final command = '$inputArgs -filter_complex "$filter" -map "[out]" -c:a aac -b:a 128k -y "$outputPath"';
      
      debugPrint('🎵 FFmpeg merge command: $command');
      onProgress?.call(30);
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      onProgress?.call(90);
      
      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          debugPrint('🎵 Audio merge successful: $outputPath');
          onProgress?.call(100);
          return outputPath;
        }
      }
      
      // Log error if merge failed
      final logs = await session.getAllLogsAsString();
      debugPrint('🎵 FFmpeg merge failed: $logs');
      
      onError?.call('Audio merge failed locally');
      return null;
    } catch (e) {
      debugPrint('🎵 Error merging audio locally: $e');
      onError?.call('Error merging audio: $e');
      return null;
    }
  }

  /// Server-side merge implementation
  Future<String?> _mergeAudioServer(
    List<String> inputPaths, {
    Function(int)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      onProgress?.call(10);
      
      final result = await _apiService.mergeAudio(inputPaths);

      onProgress?.call(60);

      final outputUrl = result['url'] ?? result['path'] ?? '';
      if (outputUrl.isEmpty) {
        onError?.call('No output URL returned from server');
        return null;
      }

      if (kIsWeb) {
        onProgress?.call(100);
        return _apiService.getMediaUrl(outputUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = outputUrl.split('/').last;
      final savePath = '${tempDir.path}/$fileName';
      
      final fullUrl = _apiService.getMediaUrl(outputUrl);
      
      onProgress?.call(80);
      
      final response = await PinnedHttpClient.instance.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        onProgress?.call(100);
        return savePath;
      }

      onError?.call('Failed to download merged audio');
      return null;
    } catch (e) {
      onError?.call('Error merging audio: $e');
      return null;
    }
  }

  /// Get audio duration using FFprobe
  Future<Duration?> getAudioDuration(String audioPath) async {
    if (kIsWeb || audioPath.startsWith('http')) {
      return null;
    }
    
    try {
      final session = await FFprobeKit.getMediaInformation(audioPath);
      final info = session.getMediaInformation();
      
      if (info != null) {
        final durationStr = info.getDuration();
        if (durationStr != null) {
          final durationSec = double.tryParse(durationStr) ?? 0;
          return Duration(milliseconds: (durationSec * 1000).toInt());
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting audio duration: $e');
      return null;
    }
  }

  /// Get audio metadata using FFprobe
  Future<Map<String, dynamic>?> getAudioMetadata(String audioPath) async {
    if (kIsWeb || audioPath.startsWith('http')) {
      return null;
    }
    
    try {
      final session = await FFprobeKit.getMediaInformation(audioPath);
      final info = session.getMediaInformation();
      
      if (info != null) {
        // Get duration
        final durationStr = info.getDuration();
        final durationMs = durationStr != null 
            ? (double.tryParse(durationStr) ?? 0) * 1000 
            : 0;
        
        // Get audio stream info
        String? codec;
        int? sampleRate;
        int? channels;
        final streams = info.getStreams();
        if (streams != null) {
          for (final stream in streams) {
            if (stream.getType() == 'audio') {
              codec = stream.getCodec();
              // getSampleRate returns String?, convert to int
              final sampleRateStr = stream.getSampleRate();
              sampleRate = sampleRateStr != null ? int.tryParse(sampleRateStr) : null;
              channels = stream.getChannelLayout() != null ? 2 : 1;
              break;
            }
          }
        }
        
        // Get file size
        final sizeStr = info.getSize();
        final fileSize = sizeStr != null ? int.tryParse(sizeStr) : null;
        
        return {
          'duration': Duration(milliseconds: durationMs.toInt()),
          'durationSeconds': durationMs / 1000,
          'format': info.getFormat(),
          'codec': codec,
          'sampleRate': sampleRate,
          'channels': channels,
          'fileSize': fileSize,
          'bitrate': info.getBitrate(),
        };
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting audio metadata: $e');
      return null;
    }
  }
}
