import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/audio_editing_service.dart';
import 'package:just_audio/just_audio.dart';

/// Audio Editor Screen - Redesigned with tabs
/// Features: Trim, Merge
class AudioEditorScreen extends StatefulWidget {
  final String audioPath;
  final String? title;

  const AudioEditorScreen({
    super.key,
    required this.audioPath,
    this.title,
  });

  @override
  State<AudioEditorScreen> createState() => _AudioEditorScreenState();
}

class _AudioEditorScreenState extends State<AudioEditorScreen> with SingleTickerProviderStateMixin {
  AudioPlayer? _player;
  final AudioEditingService _editingService = AudioEditingService();
  late TabController _tabController;
  
  bool _isInitializing = true;
  bool _isEditing = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  
  Duration _audioDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  
  List<String> _filesToMerge = [];
  String? _editedAudioPath;
  
  // Track if there are unsaved changes
  bool get _hasUnsavedChanges {
    final hasTrimChanges = _trimStart > Duration.zero || _trimEnd < _audioDuration;
    final hasMergeFiles = _filesToMerge.isNotEmpty;
    return hasTrimChanges || hasMergeFiles;
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
          'You have unsaved edits. Would you like to discard them?',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel, stay
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Discard
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Handle back button press
  Future<void> _handleBackPress() async {
    final shouldLeave = await _showDiscardChangesDialog();
    if (shouldLeave && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _player = AudioPlayer();
      
      final isNetwork = widget.audioPath.startsWith('http');
      
      if (isNetwork) {
        await _player!.setUrl(widget.audioPath);
      } else {
        await _player!.setFilePath(widget.audioPath);
      }
      
      _audioDuration = _player!.duration ?? Duration.zero;
      
      // Listen to position updates
      _player!.positionStream.listen((position) {
        if (mounted) {
          setState(() => _currentPosition = position);
        }
      });
      
      // Listen to playing state
      _player!.playingStream.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
        }
      });
      
      setState(() {
        _isInitializing = false;
        _trimEnd = _audioDuration;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _togglePlayPause() {
    if (_player == null) return;
    if (_isPlaying) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  Future<void> _applyTrim() async {
    if (_trimStart >= _trimEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be less than end time')),
      );
      return;
    }

    // Calculate trim duration for warning
    final trimDuration = _trimEnd - _trimStart;
    final isLargeFile = _audioDuration.inMinutes > 10;
    
    // Debug: Print duration info
    debugPrint('🎵 Audio Duration: ${_audioDuration.inMinutes} minutes (${_formatDuration(_audioDuration)})');
    debugPrint('🎵 Is Large File (>10 min): $isLargeFile');
    
    // Show warning ONLY for large files (> 10 minutes)
    if (isLargeFile) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warningMain, size: 28),
              const SizedBox(width: 12),
              const Text('Large Audio File'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This audio file is ${_formatDuration(_audioDuration)} long.',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Processing may take several minutes. The app may appear unresponsive during this time.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warningMain, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please do not close the app or lock your screen.',
                        style: AppTypography.caption.copyWith(color: AppColors.warningMain),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      
      if (shouldProceed != true) return;
    }

    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    // Show processing dialog
    _showProcessingDialog(trimDuration);

    String? outputPath;
    String? errorMsg;
    
    try {
      outputPath = await _editingService.trimAudio(
        widget.audioPath,
        _trimStart,
        _trimEnd,
        onProgress: (progress) {},
        onError: (error) {
          errorMsg = error;
        },
      );
    } catch (e) {
      errorMsg = e.toString();
    }

    // Close processing dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (outputPath != null) {
      setState(() {
        _editedAudioPath = outputPath;
        _isEditing = false;
      });
      await _reloadPlayer(outputPath); // This resets trim markers automatically
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Audio trimmed! You can continue editing or export.'), backgroundColor: AppColors.successMain),
        );
      }
    } else {
      setState(() {
        _isEditing = false;
        _hasError = errorMsg != null;
        _errorMessage = errorMsg;
      });
      if (mounted && errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trim failed: $errorMsg'), backgroundColor: AppColors.errorMain),
        );
      }
    }
  }

  void _showProcessingDialog(Duration trimDuration) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon with CircularProgressIndicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmBrown),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.content_cut, size: 32, color: AppColors.warmBrown),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Processing Audio',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trimming ${_formatDuration(trimDuration)} of audio...',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warningMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warningMain, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'This may take a while for large files',
                          style: AppTypography.caption.copyWith(color: AppColors.warningMain),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please wait, do not close the app...',
                  style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectAudioFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _filesToMerge = result.files.map((file) => file.path!).whereType<String>().toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_filesToMerge.length} file(s) selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting files: $e'), backgroundColor: AppColors.errorMain),
      );
    }
  }

  Future<void> _mergeAudioFiles() async {
    if (_filesToMerge.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one audio file to merge')),
      );
      return;
    }

    final inputFiles = [_editedAudioPath ?? widget.audioPath, ..._filesToMerge];

    setState(() {
      _isEditing = true;
      _hasError = false;
    });

    // Show processing dialog for merging
    _showMergeProcessingDialog(inputFiles.length);

    String? outputPath;
    String? errorMsg;
    
    try {
      outputPath = await _editingService.mergeAudioFiles(
        inputFiles,
        onProgress: (progress) {},
        onError: (error) {
          errorMsg = error;
        },
      );
    } catch (e) {
      errorMsg = e.toString();
    }

    // Close processing dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (outputPath != null) {
      setState(() {
        _editedAudioPath = outputPath;
        _isEditing = false;
        _filesToMerge = [];
      });
      await _reloadPlayer(outputPath); // This resets trim markers automatically
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Audio merged! You can continue editing or export.'), backgroundColor: AppColors.successMain),
        );
      }
    } else {
      setState(() {
        _isEditing = false;
        _hasError = errorMsg != null;
        _errorMessage = errorMsg;
      });
      if (mounted && errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $errorMsg'), backgroundColor: AppColors.errorMain),
        );
      }
    }
  }

  void _showMergeProcessingDialog(int fileCount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon with CircularProgressIndicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmBrown),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.merge_type, size: 32, color: AppColors.warmBrown),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Merging Audio',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Combining $fileCount audio files...',
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.infoMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices, color: AppColors.infoMain, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Processing locally on device',
                          style: AppTypography.caption.copyWith(color: AppColors.infoMain),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please wait...',
                  style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reloadPlayer(String path) async {
    await _player?.dispose();
    _player = AudioPlayer();
    await _player!.setFilePath(path);
    _audioDuration = _player!.duration ?? Duration.zero;
    
    _player!.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });
    
    _player!.playingStream.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });
    
    setState(() {
      _trimStart = Duration.zero;
      _trimEnd = _audioDuration;
    });
  }

  void _handleExport() {
    final pathToReturn = _editedAudioPath ?? widget.audioPath;
    Navigator.pop(context, pathToReturn);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator(color: AppColors.warmBrown)),
      );
    }

    if (_hasError) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
        body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.errorMain),
                      const SizedBox(height: 16),
              Text('Error loading audio', style: AppTypography.heading4.copyWith(color: AppColors.textPrimary)),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage!, style: AppTypography.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        ),
                    ],
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
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Audio Player Section
              _buildAudioPlayer(),
              
              // Playback Controls
              _buildPlaybackControls(),
              
              // Bottom Tabs
              _buildBottomTabs(),
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
        border: Border(bottom: BorderSide(color: AppColors.borderPrimary.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.warmBrown),
            onPressed: _handleBackPress,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? 'Audio Editor',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.warmBrown,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDuration(_audioDuration),
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isEditing ? null : _handleExport,
            icon: Icon(_isEditing ? Icons.hourglass_empty : Icons.done_all, size: 16),
            label: Text(_isEditing ? 'Processing...' : 'Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderPrimary),
          boxShadow: [
            BoxShadow(
              color: AppColors.warmBrown.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
            // Waveform Placeholder
            Container(
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(30, (index) {
                    final height = 20 + (index % 5) * 10.0;
                    final isActive = _currentPosition.inMilliseconds > 0 &&
                        index / 30 <= _currentPosition.inMilliseconds / (_audioDuration.inMilliseconds == 0 ? 1 : _audioDuration.inMilliseconds);
                    return Container(
                      width: 4,
                      height: height,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.warmBrown : AppColors.warmBrown.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Audio Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.audiotrack, size: 48, color: AppColors.warmBrown),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title ?? 'Audio File',
              style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (_editedAudioPath != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                                  ),
                child: Text(
                  'Edited',
                  style: AppTypography.caption.copyWith(color: AppColors.successMain, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          top: BorderSide(color: AppColors.borderPrimary.withOpacity(0.3)),
          bottom: BorderSide(color: AppColors.borderPrimary.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Progress Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _currentPosition.inMilliseconds.toDouble().clamp(0, _audioDuration.inMilliseconds.toDouble()),
              min: 0,
              max: _audioDuration.inMilliseconds.toDouble() > 0 ? _audioDuration.inMilliseconds.toDouble() : 1.0,
              activeColor: AppColors.warmBrown,
              inactiveColor: AppColors.warmBrown.withOpacity(0.2),
              onChanged: (value) {
                _player?.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Row(
            children: [
              Text(_formatDuration(_currentPosition), style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              // Play/Pause Button
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warmBrown.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const Spacer(),
              Text(_formatDuration(_audioDuration), style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
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
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              border: Border(bottom: BorderSide(color: AppColors.borderPrimary.withOpacity(0.3))),
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
                Tab(icon: Icon(Icons.merge_type, size: 20), text: 'Merge'),
              ],
            ),
          ),
          
          // Tab Content
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 240),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrimPanel(),
                _buildMergePanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with duration
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
              Text('Trim Audio', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Duration: ${_formatDuration(_trimEnd - _trimStart)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Time Selectors
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
                            child: Text(_formatDuration(_trimStart), style: AppTypography.caption.copyWith(color: AppColors.warmBrown, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                        child: Slider(
                              value: _trimStart.inSeconds.toDouble().clamp(0, _audioDuration.inSeconds.toDouble().clamp(1, double.infinity)),
                              min: 0,
                          max: _audioDuration.inSeconds.toDouble() > 0 ? _audioDuration.inSeconds.toDouble() : 1.0,
                          activeColor: AppColors.warmBrown,
                          inactiveColor: AppColors.warmBrown.withOpacity(0.2),
                              onChanged: (value) {
                                setState(() {
                                  _trimStart = Duration(seconds: value.toInt());
                                  if (_trimStart >= _trimEnd) {
                                _trimEnd = Duration(seconds: (value + 1).toInt().clamp(0, _audioDuration.inSeconds));
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
                            child: Text(_formatDuration(_trimEnd), style: AppTypography.caption.copyWith(color: AppColors.warmBrown, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                        child: Slider(
                              value: _trimEnd.inSeconds.toDouble().clamp(0, _audioDuration.inSeconds.toDouble().clamp(1, double.infinity)),
                              min: 0,
                          max: _audioDuration.inSeconds.toDouble() > 0 ? _audioDuration.inSeconds.toDouble() : 1.0,
                          activeColor: AppColors.warmBrown,
                          inactiveColor: AppColors.warmBrown.withOpacity(0.2),
                              onChanged: (value) {
                                setState(() {
                                  _trimEnd = Duration(seconds: value.toInt());
                                  if (_trimEnd <= _trimStart) {
                                _trimStart = Duration(seconds: (value - 1).toInt().clamp(0, _audioDuration.inSeconds));
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

  Widget _buildMergePanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.merge_type, color: AppColors.warmBrown, size: 18),
              ),
              const SizedBox(width: 8),
              Text('Merge Audio', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Selected Files Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _filesToMerge.isNotEmpty 
                        ? AppColors.successMain.withOpacity(0.1)
                        : AppColors.warmBrown.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _filesToMerge.isNotEmpty ? Icons.check_circle : Icons.queue_music,
                    color: _filesToMerge.isNotEmpty ? AppColors.successMain : AppColors.warmBrown,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                        _filesToMerge.isNotEmpty ? '${_filesToMerge.length} file(s) selected' : 'No files selected',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Select audio files to merge with current audio',
                        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                        ),
                    ],
                  ),
                ),
                if (_filesToMerge.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => _filesToMerge = []),
                    icon: Icon(Icons.clear, color: AppColors.errorMain, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                child: OutlinedButton.icon(
                                onPressed: _selectAudioFiles,
                  icon: const Icon(Icons.add, size: 16),
                                label: const Text('Select Files'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warmBrown,
                    side: BorderSide(color: AppColors.warmBrown),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                  onPressed: _isEditing || _filesToMerge.isEmpty ? null : _mergeAudioFiles,
                  icon: Icon(_isEditing ? Icons.hourglass_empty : Icons.merge_type, size: 16),
                                  label: Text(_isEditing ? 'Merging...' : 'Merge'),
                                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmBrown,
                                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.warmBrown.withOpacity(0.3),
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

}
