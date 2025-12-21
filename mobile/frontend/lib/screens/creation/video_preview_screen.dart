import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/bank_details_helper.dart';
import '../../services/api_service.dart';
import '../../widgets/shared/pill_text_field.dart';
import '../../providers/draft_provider.dart';
import '../editing/video_editor_screen.dart';

/// Video Preview Screen
/// Shows recorded/uploaded video with playback and controls
class VideoPreviewScreen extends StatefulWidget {
  final String videoUri;
  final String source; // 'camera' or 'gallery'
  final int duration;
  final int fileSize;
  final bool isFrontCamera;
  final int? draftId;
  final String? initialTitle;
  final String? initialDescription;

  const VideoPreviewScreen({
    super.key,
    required this.videoUri,
    required this.source,
    this.duration = 0,
    this.fileSize = 0,
    this.isFrontCamera = false,
    this.draftId,
    this.initialTitle,
    this.initialDescription,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoading = false;
  String? _editedVideoPath; // Track edited video path
  
  bool _hasUnsavedChanges = false;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    // Mark as unsaved if this is NEW content (no draftId = new recording/upload)
    // This ensures users are warned before losing newly created content
    _hasUnsavedChanges = widget.draftId == null;
    
    _titleController = TextEditingController(
      text: widget.initialTitle ?? 'My Video Podcast',
    );
    _descriptionController = TextEditingController(
      text: widget.initialDescription ??
          'A wonderful video podcast about faith and spirituality',
    );
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Check if URI is a network URL or local file path
      final isNetworkUrl = widget.videoUri.startsWith('http://') || 
                          widget.videoUri.startsWith('https://');
      
      if (isNetworkUrl) {
        // Use network URL controller
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUri),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        // Verify local file exists before initializing player
        final file = File(widget.videoUri);
        if (!await file.exists()) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Video file not found at path: ${widget.videoUri}';
            _isInitializing = false;
          });
          return;
        }
        _controller = VideoPlayerController.file(file);
      }
      
      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('Error initializing video player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: ${e.toString()}';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _handleBack() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
    Navigator.pop(context);
    }
  }

  void _handlePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || !mounted) {
      return true;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save draft?'),
        content: const Text(
          'You have unsaved changes. Would you like to save this as a draft before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );

    if (action == 'save') {
      final success = await _saveDraft();
      return success;
    } else if (action == 'discard') {
      return true;
    }
    return false;
  }

  Future<bool> _saveDraft() async {
    try {
      final draftProvider = context.read<DraftProvider>();
      final apiService = ApiService();

      final videoPath = _editedVideoPath ?? widget.videoUri;

      // Upload to S3 if local path
      String? s3Url;
      if (!videoPath.startsWith('http://') && !videoPath.startsWith('https://')) {
        // Local file - upload to S3
        s3Url = await apiService.uploadDraftVideo(filePath: videoPath);
      } else {
        // Already S3 URL
        s3Url = videoPath;
      }

      final draft = ContentDraft(
        id: widget.draftId,
        userId: 0,
        draftType: DraftType.videoPodcast,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        originalMediaUrl: s3Url,
        duration: _controller != null && _controller!.value.isInitialized
            ? _controller!.value.duration.inSeconds
            : (widget.duration > 0 ? widget.duration : null),
        status: DraftStatus.editing,
      );

      if (widget.draftId != null) {
        await draftProvider.updateDraft(draft);
      } else {
        await draftProvider.createDraft(draft);
      }

      // Refresh drafts list
      await draftProvider.fetchDrafts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved')),
        );
      }
      _hasUnsavedChanges = false;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
      return false;
    }
  }

  void _handleEdit() async {
    // Navigate to VideoEditorScreen - pass edited path if exists
    final currentPath = _editedVideoPath ?? widget.videoUri;
    final editedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => VideoEditorScreen(
          videoPath: currentPath,
          isFrontCamera: widget.isFrontCamera,
        ),
      ),
    );

    if (editedPath != null && mounted) {
      // Update video path with edited version and reload player
      setState(() {
        _editedVideoPath = editedPath;
        _isInitializing = true;
        _hasError = false;
        _hasUnsavedChanges = true; // Mark as unsaved when video is edited
      });
      
      // Dispose old controller
      await _controller?.pause();
      await _controller?.dispose();
      _controller = null;
      
      // Reload player with edited video
      await _reloadPlayerWithEditedVideo(editedPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Video edited successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  Future<void> _reloadPlayerWithEditedVideo(String videoPath) async {
    try {
      // Check if path is network URL or local file
      final isNetworkUrl = videoPath.startsWith('http://') || 
                          videoPath.startsWith('https://');
      
      if (isNetworkUrl) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoPath),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        final file = File(videoPath);
        if (!await file.exists()) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Edited video file not found';
            _isInitializing = false;
          });
          return;
        }
        _controller = VideoPlayerController.file(file);
      }
      
      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load edited video: $e';
        _isInitializing = false;
      });
    }
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublish() async {
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a title for your video'),
          backgroundColor: AppColors.errorMain,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Check bank details before publishing (optional - will show info message)
    final canProceed = await checkBankDetailsAndNavigate(context);
    if (!canProceed || !mounted) {
      return; // User cancelled
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final api = ApiService();
      
      // Step 1: Upload the video file (use edited version if available)
      final videoToUpload = _editedVideoPath ?? widget.videoUri;
      _showUploadProgress('Uploading video...');
      final uploadResult = await api.uploadFile(videoToUpload, 'video');
      
      if (!mounted) return;
      
      final videoUrl = uploadResult['file_path'] ?? uploadResult['url'];
      if (videoUrl == null) {
        throw Exception('Failed to get video URL from upload');
      }
      
      // Step 2: Create the podcast - use description field directly
      _showUploadProgress('Creating video podcast...');
      final description = _descriptionController.text.trim();
      
      final podcastResult = await api.createPodcast(
        title: _titleController.text.trim(),
        description: description.isNotEmpty ? description : null,
        videoUrl: videoUrl,
        useDefaultThumbnail: true,
        categoryId: 1, // Default to Sermons category
      );
      
      if (!mounted) return;
      
      // Dismiss the upload progress SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      setState(() {
        _isLoading = false;
      });
      
      // Check if bank details warning was returned
      final bankDetailsMissing = podcastResult['bank_details_missing'] == true;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              const Text('Published!'),
            ],
          ),
          content: Text(
            bankDetailsMissing 
              ? 'Your video podcast has been published! Add bank details to receive payments.'
              : 'Your video podcast has been published and shared with the community!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warmBrown,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      
      // Dismiss the upload progress SnackBar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.errorMain,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  
  void _showUploadProgress(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 Bytes';
    if (bytes < 1024) return '$bytes Bytes';
    
    final k = 1024;
    final sizes = ['Bytes', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    
    // Calculate the correct unit index
    while (size >= k && i < sizes.length - 1) {
      size /= k;
      i++;
    }
    
    // Clamp index to valid range
    i = i.clamp(0, sizes.length - 1);
    
    return '${size.toStringAsFixed(2)} ${sizes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.warmBrown),
          onPressed: _handleBack,
        ),
        title: Text(
          'Video Preview',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.warmBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.errorMain),
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Player
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isInitializing)
                        const Center(child: CircularProgressIndicator(color: AppColors.warmBrown))
                      else if (_hasError)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(height: 16),
                              Text('Error loading video', style: TextStyle(color: Colors.white, fontSize: 18)),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(_errorMessage!, style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                                ),
                            ],
                          ),
                        )
                      else if (_controller != null && _controller!.value.isInitialized)
                        GestureDetector(
                          onTap: _handlePlayPause,
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Apply horizontal flip for front camera videos
                                Transform(
                                  alignment: Alignment.center,
                                  transform: widget.isFrontCamera 
                                      ? Matrix4.rotationY(3.14159265359) // Flip horizontally (π radians)
                                      : Matrix4.identity(),
                                  child: VideoPlayer(_controller!),
                                ),
                                if (!_controller!.value.isPlaying)
                                  Container(
                                    color: Colors.black.withOpacity(0.3),
                                    child: Center(
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: AppColors.warmBrown.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Center(child: CircularProgressIndicator(color: AppColors.warmBrown)),
                    ],
                  ),
                ),
              ),
            ),

            // Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
              child: Row(
                children: [
                  Text(
                    _controller != null && _controller!.value.isInitialized
                        ? _formatTime(_controller!.value.position.inSeconds)
                        : _formatTime(0),
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        value: _controller != null && _controller!.value.isInitialized
                            ? _controller!.value.position.inSeconds.toDouble()
                            : 0.0,
                        min: 0,
                        max: _controller != null && _controller!.value.isInitialized
                            ? _controller!.value.duration.inSeconds.toDouble()
                            : widget.duration.toDouble(),
                        activeColor: AppColors.warmBrown,
                        inactiveColor: AppColors.warmBrown.withOpacity(0.2),
                        onChanged: (value) {
                          if (_controller != null && _controller!.value.isInitialized) {
                            _controller!.seekTo(Duration(seconds: value.toInt()));
                          }
                        },
                      ),
                    ),
                  ),
                  Text(
                    _controller != null && _controller!.value.isInitialized
                        ? _formatTime(_controller!.value.duration.inSeconds)
                        : _formatTime(widget.duration),
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Metadata Form
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.medium),
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderPrimary),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warmBrown.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warmBrown.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.video_library, color: AppColors.warmBrown, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Video Details',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      
                      // Title input
                      TextField(
                        controller: _titleController,
                        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter title',
                          hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
                          prefixIcon: Icon(Icons.title, color: AppColors.warmBrown),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderPrimary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderPrimary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      
                      // Description / Caption input (combined field)
                      TextField(
                        controller: _descriptionController,
                        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter description / caption',
                          hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 48),
                            child: Icon(Icons.description, color: AppColors.warmBrown),
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderPrimary),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderPrimary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      
                      // File info row
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: AppColors.warmBrown),
                            const SizedBox(width: 6),
                            Text(_formatTime(widget.duration), style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(width: 16),
                            Icon(Icons.storage, size: 16, color: AppColors.warmBrown),
                            const SizedBox(width: 6),
                            Text(_formatFileSize(widget.fileSize), style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons (Edit, Save Draft, Publish)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium, vertical: AppSpacing.small),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                border: Border(top: BorderSide(color: AppColors.borderPrimary.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: _editedVideoPath != null ? Icons.check_circle : Icons.edit,
                      label: _editedVideoPath != null ? 'Edited' : 'Edit',
                      onPressed: _handleEdit,
                      isEdited: _editedVideoPath != null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.save,
                      label: 'Save Draft',
                      onPressed: () {
                        _saveDraft();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildActionButton(
                      icon: Icons.publish,
                      label: _isLoading ? 'Publishing...' : 'Publish',
                      onPressed: _isLoading ? null : _handlePublish,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isPrimary = false,
    bool isEdited = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.warmBrown : (isEdited ? Colors.green.shade50 : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppColors.warmBrown : (isEdited ? Colors.green : AppColors.borderPrimary),
            width: 1,
          ),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: AppColors.warmBrown.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isPrimary ? Colors.white : (isEdited ? Colors.green : AppColors.warmBrown), 
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: isPrimary ? Colors.white : (isEdited ? Colors.green : AppColors.warmBrown),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
