import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/video_editing_service.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/app_logger.dart';

/// Video Editor Screen - Professional Video Editing UI
/// Features: Trimming, audio editing, rotation
class VideoEditorScreen extends StatefulWidget {
  final String videoPath;
  final String? title;
  final bool isFrontCamera;

  const VideoEditorScreen({
    super.key,
    required this.videoPath,
    this.title,
    this.isFrontCamera = false,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  final VideoEditingService _editingService = VideoEditingService();
  late TabController _tabController;
  
  bool _isInitializing = true;
  bool _isEditing = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Video metadata
  String? _projectTitle;
  String _resolution = '1440p';
  double _fps = 30.0;
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  
  // Editing state
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  bool _audioRemoved = false;
  String? _audioFilePath;
  
  // Rotation state (0, 90, 180, 270 degrees)
  int _rotation = 0;
  
  String? _editedVideoPath;
  
  // Track if there are unsaved changes
  bool get _hasUnsavedChanges {
    final hasTrimChanges = _trimStart > Duration.zero || _trimEnd < _videoDuration;
    final hasRotationChanges = _rotation != 0;
    final hasAudioChanges = _audioRemoved || _audioFilePath != null;
    return hasTrimChanges || hasRotationChanges || hasAudioChanges;
  }
  
  /// Show confirmation dialog when user tries to leave with unsaved changes
  Future<bool> _showDiscardChangesDialog() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text('Unsaved Changes', style: AppTypography.heading4),
          ],
        ),
        content: Text(
          'You have unsaved edits. Would you like to save them before leaving?',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Discard
            child: Text('Discard', style: TextStyle(color: AppColors.errorMain)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel, stay
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, null); // Save and exit
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
    
    if (result == null) {
      // User chose to save and exit - apply changes then exit
      await _handleSaveAndContinue();
      // After saving, exit with the edited path
      if (mounted) {
        final pathToReturn = _editedVideoPath ?? widget.videoPath;
        Navigator.pop(context, pathToReturn);
      }
      return false; // Already handled the pop
    }
    
    return result; // true = discard, false = cancel
  }
  
  /// Handle back button press
  Future<void> _handleBackPress() async {
    final shouldLeave = await _showDiscardChangesDialog();
    if (shouldLeave && mounted) {
      Navigator.pop(context);
    }
  }
  
  /// Handle export - applies any pending changes and returns the final video
  Future<void> _handleExport() async {
    // If there are unsaved changes, apply them first
    if (_hasUnsavedChanges) {
      await _handleSaveAndContinue();
    }
    
    // Return the edited video path (or original if no edits)
    final pathToReturn = _editedVideoPath ?? widget.videoPath;
    if (mounted) {
      Navigator.pop(context, pathToReturn);
    }
  }
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs: Trim, Audio, Rotate
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    try {
      final isNetwork = widget.videoPath.startsWith('http');
      
      if (isNetwork) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoPath));
      }
      
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      
      // Extract project title from filename
      final fileName = path.basename(widget.videoPath);
      _projectTitle = widget.title ?? fileName.split('.').first;
      
      // Extract video metadata
      final size = _controller!.value.size;
      _resolution = _getResolutionFromSize(size);
      _fps = _controller!.value.size.height > 720 ? 30.0 : 29.97; // Estimate, video_player doesn't expose FPS directly
      
      setState(() {
        _isInitializing = false;
        _videoDuration = _controller!.value.duration;
        _trimEnd = _videoDuration;
      });
      
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  String _getResolutionFromSize(Size size) {
    final height = size.height;
    if (height >= 2160) return '4K';
    if (height >= 1440) return '1440p';
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    if (height >= 480) return '480p';
    return '360p';
  }

  void _videoListener() {
    if (mounted && _controller != null) {
      setState(() {
        _currentPosition = _controller!.value.position;
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  Future<void> _applyTrim() async {
    // Validate trim range
    if (_trimStart >= _trimEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start time must be less than end time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate minimum duration (at least 1 second)
    if ((_trimEnd - _trimStart).inSeconds < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trimmed video must be at least 1 second long'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    try {
      // Get current video path (use edited version if available)
      final inputPath = _editedVideoPath ?? widget.videoPath;
      
      final outputPath = await _editingService.trimVideo(
        inputPath,
        _trimStart,
        _trimEnd,
        onProgress: (progress) {
          AppLogger.debug('Trim progress: $progress%');
        },
        onError: (error) {
          throw Exception(error);
        },
      );

      if (outputPath != null && mounted) {
        setState(() {
          _editedVideoPath = outputPath;
          _isEditing = false;
        });
        
        // Reload player with trimmed video
        await _reloadPlayer(outputPath);
        
        // Update trim markers to match new video duration
        setState(() {
          _trimStart = Duration.zero;
          _trimEnd = _controller!.value.duration;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Video trimmed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Trim operation returned null');
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trim video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAudio() async {
    // Get current video path (use edited version if available)
    final inputPath = _editedVideoPath ?? widget.videoPath;
    
    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    try {
      final outputPath = await _editingService.removeAudioTrack(
        inputPath,
        onProgress: (progress) {
          AppLogger.debug('Remove audio progress: $progress%');
        },
        onError: (error) {
          throw Exception(error);
        },
      );

      if (outputPath != null && mounted) {
        setState(() {
          _editedVideoPath = outputPath;
          _audioRemoved = true;
          _audioFilePath = null; // Clear any added audio
          _isEditing = false;
        });
        
        // Reload player with audio-removed video
        await _reloadPlayer(outputPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Audio removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Remove audio operation returned null');
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final audioPath = result.files.single.path!;
        final audioFile = File(audioPath);
        
        // Validate file exists
        if (!await audioFile.exists()) {
          throw Exception('Selected audio file not found');
        }
        
        // Validate file size (max 50MB)
        final fileSize = await audioFile.length();
        if (fileSize > 50 * 1024 * 1024) {
          throw Exception('Audio file too large (max 50MB)');
        }
        
        await _addAudioTrack(audioPath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addAudioTrack(String audioPath) async {
    // Get current video path (use edited version if available)
    final inputPath = _editedVideoPath ?? widget.videoPath;
    
    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    try {
      final outputPath = await _editingService.addAudioTrack(
        inputPath,
        audioPath,
        onProgress: (progress) {
          AppLogger.debug('Add audio progress: $progress%');
        },
        onError: (error) {
          throw Exception(error);
        },
      );

      if (outputPath != null && mounted) {
        setState(() {
          _editedVideoPath = outputPath;
          _audioFilePath = audioPath;
          _audioRemoved = false; // Clear removed flag
          _isEditing = false;
        });
        
        // Reload player with new audio
        await _reloadPlayer(outputPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Audio track added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Add audio operation returned null');
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Note: Filters feature removed - not available in web version
  // Use web video editor's 3-tab structure: Trim, Audio, Text

  Future<void> _reloadPlayer(String path) async {
    try {
      // Pause and dispose current controller
      if (_controller != null) {
        await _controller!.pause();
        _controller!.removeListener(_videoListener);
        await _controller!.dispose();
      }
      
      // Initialize new controller with edited video
      final isNetwork = path.startsWith('http');
      if (isNetwork) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        _controller = VideoPlayerController.file(File(path));
      }
      
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      
      setState(() {
        _videoDuration = _controller!.value.duration;
        _currentPosition = Duration.zero;
        _isPlaying = false;
      });
      
      AppLogger.debug('✓ Video player reloaded successfully with duration: ${_videoDuration.inSeconds}s');
    } catch (e) {
      AppLogger.debug('Error reloading player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to reload video: $e';
      });
    }
  }

  /// Handle Save & Continue - applies all pending edits and navigates to preview
  Future<void> _handleSaveAndContinue() async {
    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    try {
      String currentVideoPath = _editedVideoPath ?? widget.videoPath;

      // Step 0: Apply rotation if needed (must be done first)
      if (_rotation != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applying ${_rotation}° rotation...'), duration: Duration(seconds: 1)),
        );
        
        final rotatedPath = await _editingService.rotateVideo(
          currentVideoPath,
          _rotation,
          onProgress: (progress) {},
          onError: (error) {
            setState(() {
              _isEditing = false;
              _hasError = true;
              _errorMessage = error;
            });
            throw Exception(error);
          },
        );
        
        if (rotatedPath != null) {
          currentVideoPath = rotatedPath;
          setState(() {
            _rotation = 0; // Reset rotation after applying
          });
        }
      }

      // Step 1: Apply trim if needed
      final needsTrim = _trimStart > Duration.zero || _trimEnd < _videoDuration;
      if (needsTrim && _trimStart < _trimEnd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applying trim...'), duration: Duration(seconds: 1)),
        );
        
        final trimmedPath = await _editingService.trimVideo(
          currentVideoPath,
          _trimStart,
          _trimEnd,
          onProgress: (progress) {},
          onError: (error) {
            setState(() {
              _isEditing = false;
              _hasError = true;
              _errorMessage = error;
            });
            throw Exception(error);
          },
        );
        
        if (trimmedPath != null) {
          currentVideoPath = trimmedPath;
        }
      }

      // Step 2: Apply audio changes if needed
      if (_audioRemoved && _audioFilePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removing audio...'), duration: Duration(seconds: 1)),
        );
        
        final noAudioPath = await _editingService.removeAudioTrack(
          currentVideoPath,
          onProgress: (progress) {},
          onError: (error) {
            setState(() {
              _isEditing = false;
              _hasError = true;
              _errorMessage = error;
            });
            throw Exception(error);
          },
        );
        
        if (noAudioPath != null) {
          currentVideoPath = noAudioPath;
        }
      } else if (_audioFilePath != null && !_audioRemoved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adding audio track...'), duration: Duration(seconds: 1)),
        );
        
        final withAudioPath = await _editingService.addAudioTrack(
          currentVideoPath,
          _audioFilePath!,
          onProgress: (progress) {},
          onError: (error) {
            setState(() {
              _isEditing = false;
              _hasError = true;
              _errorMessage = error;
            });
            throw Exception(error);
          },
        );
        
        if (withAudioPath != null) {
          currentVideoPath = withAudioPath;
        }
      }

      // All edits applied successfully - reload player with edited video and stay in editor
      _editedVideoPath = currentVideoPath;
      
      // Reload player with the edited video
      await _reloadPlayer(currentVideoPath);
      
      // Reset editing state since changes are now applied
      setState(() {
        _isEditing = false;
        _trimStart = Duration.zero;
        _trimEnd = _videoDuration;
        _rotation = 0;
        _audioRemoved = false;
        _audioFilePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ All edits applied! You can continue editing or export.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving video: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  Future<void> _applyRotation() async {
    if (_rotation == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rotation to apply')),
      );
      return;
    }
    
    final inputPath = _editedVideoPath ?? widget.videoPath;
    
    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    try {
      final outputPath = await _editingService.rotateVideo(
        inputPath,
        _rotation,
        onProgress: (progress) {
          AppLogger.debug('Rotate progress: $progress%');
        },
        onError: (error) {
          throw Exception(error);
        },
      );

      if (outputPath != null && mounted) {
        setState(() {
          _editedVideoPath = outputPath;
          _rotation = 0; // Reset rotation after applying
          _isEditing = false;
        });
        
        await _reloadPlayer(outputPath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Video rotated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Rotate operation returned null');
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rotate video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryMain)),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      // Limit error message to first 200 characters to avoid overflow
                      _errorMessage!.length > 200 
                          ? '${_errorMessage!.substring(0, 200)}...' 
                          : _errorMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Video Preview
              Expanded(
                child: _buildVideoPreview(),
              ),
              
              // Playback Controls
              _buildPlaybackControls(),
              
              // Bottom Toolbar (Trim, Audio, Text tabs)
              _buildBottomToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSecondary, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleBackPress,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          
          // Project title and resolution
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _projectTitle ?? 'Untitled Project',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_videoDuration != Duration.zero)
                  Text(
                    '$_resolution • ${_fps.toStringAsFixed(0)}fps • ${_formatTime(_videoDuration)}',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          
          // Undo button
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.undo, color: AppColors.textSecondary, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Undo feature coming soon')),
                );
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 4),
          
          // Redo button
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.redo, color: AppColors.textSecondary, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Redo feature coming soon')),
                );
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          
          // Export button - finishes editing and returns the video
          Flexible(
            fit: FlexFit.loose,
            child: ElevatedButton.icon(
              onPressed: _isEditing ? null : _handleExport,
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate the actual video player rectangle within the available space.
  /// Takes into account video aspect ratio and rotation.
  Rect _getVideoPlayerRect(BoxConstraints constraints) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Rect.zero;
    }

    final videoAspect = _rotation == 90 || _rotation == 270
        ? 1 / _controller!.value.aspectRatio
        : _controller!.value.aspectRatio;

    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;

    // Calculate fitted video size (similar to BoxFit.contain)
    double videoWidth, videoHeight;
    if (availableWidth / availableHeight > videoAspect) {
      // Height constrained
      videoHeight = availableHeight;
      videoWidth = videoHeight * videoAspect;
    } else {
      // Width constrained
      videoWidth = availableWidth;
      videoHeight = videoWidth / videoAspect;
    }

    // Center offset
    final offsetX = (availableWidth - videoWidth) / 2;
    final offsetY = (availableHeight - videoHeight) / 2;

    return Rect.fromLTWH(offsetX, offsetY, videoWidth, videoHeight);
  }

  Widget _buildVideoPreview() {
    return Container(
      color: Colors.black, // Keep black for video preview area
      child: LayoutBuilder(
        builder: (context, constraints) {
          final videoRect = _getVideoPlayerRect(constraints);
          if (videoRect.width <= 0 || videoRect.height <= 0) {
            return const SizedBox.shrink();
          }

          final videoWidth = videoRect.width;
          final videoHeight = videoRect.height;

          // Build video layer with transforms (rotation and front-camera flip)
          Widget videoLayer = const SizedBox.shrink();
          if (_controller != null && _controller!.value.isInitialized) {
            videoLayer = AspectRatio(
              aspectRatio: _rotation == 90 || _rotation == 270
                  ? 1 / _controller!.value.aspectRatio
                  : _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            );
            
            // Apply rotation and front-camera flip ONLY to video layer
            if (_rotation != 0 || widget.isFrontCamera) {
              videoLayer = Transform.rotate(
                angle: _rotation * 3.14159265 / 180, // degrees -> radians
                child: Transform(
                  alignment: Alignment.center,
                  transform: widget.isFrontCamera
                      ? Matrix4.rotationY(3.14159265359) // horizontal flip
                      : Matrix4.identity(),
                  child: videoLayer,
                ),
              );
            }
          }

          // Base content: video and overlays in separate layers
          // Text overlays are NOT transformed to keep text readable
          Widget content = SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: videoLayer,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: content),

              // Rotation indicator (UI only, not affected by transforms)
              if (_rotation != 0)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rotate_right,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_rotation}°',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          top: BorderSide(color: AppColors.borderSecondary, width: 1),
          bottom: BorderSide(color: AppColors.borderSecondary, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Current time
          Text(
            _formatTime(_currentPosition),
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          
          const Spacer(),
          
          // Play button (centered)
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryMain.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Total duration
          Text(
            '/${_formatTime(_videoDuration)}',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Timeline section removed - using simplified UI with just tabs

  Widget _buildBottomToolbar() {
    return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            border: Border(
              top: BorderSide(color: AppColors.borderSecondary, width: 1),
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
            children: [
          // Tab bar at top
        Container(
          decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
            border: Border(
                bottom: BorderSide(color: AppColors.borderSecondary, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
              indicatorColor: AppColors.warmBrown,
              indicatorWeight: 3,
              labelColor: AppColors.warmBrown,
            unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
                Tab(icon: Icon(Icons.content_cut, size: 20), text: 'Trim'),
                Tab(icon: Icon(Icons.music_note, size: 20), text: 'Audio'),
                Tab(icon: Icon(Icons.rotate_right, size: 20), text: 'Rotate'),
            ],
          ),
        ),
          
          // Tab content panel - flexible height with constraints
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 180,
              maxHeight: 220,
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEditPanel(),
                _buildMusicPanel(),
                _buildRotatePanel(),
              ],
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildEditPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header with duration info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.content_cut, color: AppColors.warmBrown, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Trim Video',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Duration: ${_formatTime(_trimEnd - _trimStart)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Time Selectors Row
          Row(
            children: [
          // Start Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                          Text('Start', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
              Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                              color: AppColors.warmBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                ),
                            child: Text(_formatTime(_trimStart), style: AppTypography.caption.copyWith(color: AppColors.warmBrown, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
            value: _trimStart.inSeconds.toDouble(),
            min: 0,
            max: _videoDuration.inSeconds.toDouble() > 0 ? _videoDuration.inSeconds.toDouble() : 1.0,
                          activeColor: AppColors.warmBrown,
                          inactiveColor: AppColors.warmBrown.withOpacity(0.2),
            onChanged: (value) {
              setState(() {
                _trimStart = Duration(seconds: value.toInt());
                if (_trimStart >= _trimEnd) {
                  _trimEnd = Duration(seconds: (value + 1).toInt().clamp(0, _videoDuration.inSeconds));
                }
              });
            },
          ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
          // End Time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                          Text('End', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
              Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                              color: AppColors.warmBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                ),
                            child: Text(_formatTime(_trimEnd), style: AppTypography.caption.copyWith(color: AppColors.warmBrown, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
            value: _trimEnd.inSeconds.toDouble(),
            min: 0,
            max: _videoDuration.inSeconds.toDouble() > 0 ? _videoDuration.inSeconds.toDouble() : 1.0,
                          activeColor: AppColors.warmBrown,
                          inactiveColor: AppColors.warmBrown.withOpacity(0.2),
            onChanged: (value) {
              setState(() {
                _trimEnd = Duration(seconds: value.toInt());
                if (_trimEnd <= _trimStart) {
                  _trimStart = Duration(seconds: (value - 1).toInt().clamp(0, _videoDuration.inSeconds));
                }
              });
            },
          ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Apply Trim Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isEditing ? null : _applyTrim,
              icon: Icon(_isEditing ? Icons.hourglass_empty : Icons.check_circle, size: 18),
              label: Text(_isEditing ? 'Processing...' : 'Apply Trim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.music_note, color: AppColors.warmBrown, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Audio Track',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Audio Status Card - Compact
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _audioFilePath != null
                    ? AppColors.successMain.withOpacity(0.5)
                    : _audioRemoved
                        ? AppColors.errorMain.withOpacity(0.5)
                        : AppColors.borderPrimary,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _audioFilePath != null
                        ? AppColors.successMain.withOpacity(0.1)
                        : _audioRemoved
                            ? AppColors.errorMain.withOpacity(0.1)
                            : AppColors.warmBrown.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _audioFilePath != null
                        ? Icons.volume_up
                        : _audioRemoved
                            ? Icons.volume_off
                            : Icons.audiotrack,
                    color: _audioFilePath != null
                        ? AppColors.successMain
                        : _audioRemoved
                            ? AppColors.errorMain
                            : AppColors.warmBrown,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _audioFilePath != null
                            ? 'Custom Audio Active'
                            : _audioRemoved
                                ? 'Audio Removed'
                                : 'Original Audio',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _audioFilePath != null
                            ? 'Custom track added'
                            : _audioRemoved
                                ? 'No audio in video'
                                : 'Using original track',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_audioFilePath != null || _audioRemoved)
                  IconButton(
                    onPressed: _isEditing ? null : () async {
                      setState(() {
                        _isEditing = true;
                      });
                      
                      // Reload original video
                      await _reloadPlayer(widget.videoPath);
                      
                      setState(() {
                        _audioFilePath = null;
                        _audioRemoved = false;
                        _editedVideoPath = null;
                        _isEditing = false;
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Reset to original audio'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: Icon(Icons.refresh, color: AppColors.warmBrown, size: 20),
                    tooltip: 'Reset to original',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Action Buttons - Side by Side
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isEditing || _audioRemoved ? null : _removeAudio,
                  icon: const Icon(Icons.volume_off, size: 16),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorMain,
                    side: BorderSide(color: _audioRemoved ? AppColors.borderPrimary : AppColors.errorMain),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isEditing ? null : _selectAudioFile,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRotatePanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.rotate_right, color: AppColors.warmBrown, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Rotate Video',
                style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_rotation}°',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warmBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          ),
          const SizedBox(height: 16),
          
          // Rotation Options Grid
          Row(
            children: [
              _buildRotationButton(0, 'Original'),
              const SizedBox(width: 8),
              _buildRotationButton(90, '90° CW'),
              const SizedBox(width: 8),
              _buildRotationButton(180, '180°'),
              const SizedBox(width: 8),
              _buildRotationButton(270, '90° CCW'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Apply Rotation Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _rotation != 0 && !_isEditing ? _applyRotation : null,
              icon: Icon(_isEditing ? Icons.hourglass_empty : Icons.check_circle, size: 18),
              label: Text(_isEditing ? 'Processing...' : 'Apply Rotation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationButton(int degrees, String label) {
    final isSelected = _rotation == degrees;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rotation = degrees),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.warmBrown : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.warmBrown : AppColors.borderPrimary,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.warmBrown.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                degrees == 0 ? Icons.crop_original : Icons.rotate_right,
                color: isSelected ? Colors.white : AppColors.warmBrown,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
