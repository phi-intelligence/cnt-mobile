import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/bank_details_helper.dart';
import '../../widgets/shared/pill_text_field.dart';
import '../../services/api_service.dart';
import '../../providers/draft_provider.dart';
import '../editing/audio_editor_screen.dart';

/// Audio Preview Screen
/// Shows recorded/uploaded audio with playback and metadata form
/// Uses white/brown theme consistent with the rest of the app
class AudioPreviewScreen extends StatefulWidget {
  final String audioUri;
  final String source; // 'recording' or 'file'
  final int duration;
  final int fileSize;
  final int? draftId;
  final String? initialTitle;
  final String? initialDescription;

  const AudioPreviewScreen({
    super.key,
    required this.audioUri,
    required this.source,
    this.duration = 0,
    this.fileSize = 0,
    this.draftId,
    this.initialTitle,
    this.initialDescription,
  });

  @override
  State<AudioPreviewScreen> createState() => _AudioPreviewScreenState();
}

class _AudioPreviewScreenState extends State<AudioPreviewScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoading = false;
  String? _editedAudioPath; // Track edited audio path
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _hasUnsavedChanges = false;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    // Mark as unsaved if this is NEW content (no draftId = new recording/upload)
    // This ensures users are warned before losing newly created content
    _hasUnsavedChanges = widget.draftId == null;
    
    _titleController = TextEditingController(
      text: widget.initialTitle ?? 'My Audio Podcast',
    );
    _descriptionController = TextEditingController(
      text: widget.initialDescription ??
          'A wonderful audio podcast about faith and spirituality',
    );
    _tagsController = TextEditingController(
      text: 'podcast, faith, spirituality',
    );
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _initializePlayer();
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });
    _audioPlayer.playingStream.listen((playing) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      final uri = widget.audioUri;
      final isNetwork =
          uri.startsWith('http://') || uri.startsWith('https://');
      if (isNetwork) {
        await _audioPlayer.setUrl(uri);
      } else {
        await _audioPlayer.setFilePath(uri);
      }
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
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

  Future<void> _handlePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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

      // Prefer edited audio path if available
      final audioPath = _editedAudioPath ?? widget.audioUri;

      // Upload to S3 if local path
      String? s3Url;
      if (!audioPath.startsWith('http://') && !audioPath.startsWith('https://')) {
        // Local file - upload to S3
        s3Url = await apiService.uploadDraftAudio(filePath: audioPath);
      } else {
        // Already S3 URL
        s3Url = audioPath;
      }

      final draft = ContentDraft(
        id: widget.draftId,
        userId: 0, // backend uses current user from token
        draftType: DraftType.audioPodcast,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        originalMediaUrl: s3Url,
        duration: _duration != Duration.zero
            ? _duration.inSeconds
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
          const SnackBar(
            content: Text('Draft saved'),
          ),
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
    // Navigate to AudioEditorScreen - pass edited path if exists
    final currentPath = _editedAudioPath ?? widget.audioUri;
    final editedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => AudioEditorScreen(
          audioPath: currentPath,
          title: _titleController.text.isNotEmpty ? _titleController.text : null,
        ),
      ),
    );

    if (editedPath != null && mounted) {
      // Update audio path with edited version
      setState(() {
        _editedAudioPath = editedPath;
        _hasUnsavedChanges = true; // Mark as unsaved when audio is edited
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Audio edited successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handlePublish() async {
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a title for your podcast'),
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
      
      // Step 1: Upload the audio file (use edited version if available)
      final audioToUpload = _editedAudioPath ?? widget.audioUri;
      _showUploadProgress('Uploading audio...');
      final uploadResult = await api.uploadFile(audioToUpload, 'audio');
      
      if (!mounted) return;
      
      final audioUrl = uploadResult['file_path'] ?? uploadResult['url'];
      if (audioUrl == null) {
        throw Exception('Failed to get audio URL from upload');
      }
      
      // Step 2: Create the podcast - use description field directly
      _showUploadProgress('Creating podcast...');
      final description = _descriptionController.text.trim();
      
      final podcastResult = await api.createPodcast(
        title: _titleController.text.trim(),
        description: description.isNotEmpty ? description : null,
        audioUrl: audioUrl,
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bankDetailsMissing 
              ? 'Audio podcast published! Add bank details to receive payments.'
              : 'Audio podcast published successfully!'
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      // Navigate to home
      Navigator.of(context).popUntil((route) => route.isFirst);
      
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
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    
    final k = 1024;
    final sizes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= k && i < sizes.length - 1) {
      size /= k;
      i++;
    }
    
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
          'Audio Preview',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.warmBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.large),
            child: Column(
              children: [
                // Hero Section with Audio Player
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warmBrown.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Audio Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.audiotrack,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Audio Podcast',
                        style: AppTypography.heading3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _duration != Duration.zero
                            ? '${_formatTime(_duration.inSeconds)} • ${_formatFileSize(widget.fileSize)}'
                            : '${_formatTime(widget.duration)} • ${_formatFileSize(widget.fileSize)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_isInitializing)
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      else if (_hasError)
                        Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading audio',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        // Play Button
                        GestureDetector(
                          onTap: _handlePlayPause,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: StreamBuilder<bool>(
                              stream: _audioPlayer.playingStream,
                              builder: (context, snapshot) {
                                final isPlaying = snapshot.data ?? false;
                                return Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 32,
                                  color: AppColors.warmBrown,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Progress Bar
                        StreamBuilder<Duration>(
                          stream: _audioPlayer.positionStream,
                          builder: (context, positionSnapshot) {
                            final position = positionSnapshot.data ?? Duration.zero;
                            return StreamBuilder<Duration?>(
                              stream: _audioPlayer.durationStream,
                              builder: (context, durationSnapshot) {
                                final duration = durationSnapshot.data ?? _duration;
                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        overlayShape: const RoundSliderOverlayShape(
                                          overlayRadius: 14,
                                        ),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white.withOpacity(0.2),
                                      ),
                                      child: Slider(
                                        value: duration != Duration.zero
                                            ? position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble())
                                            : 0.0,
                                        min: 0,
                                        max: duration != Duration.zero
                                            ? duration.inSeconds.toDouble()
                                            : widget.duration.toDouble(),
                                        onChanged: (value) {
                                          _audioPlayer.seek(Duration(seconds: value.toInt()));
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTime(position.inSeconds),
                                            style: AppTypography.caption.copyWith(
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                          Text(
                                            _formatTime((duration != Duration.zero ? duration : Duration(seconds: widget.duration)).inSeconds),
                                            style: AppTypography.caption.copyWith(
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Edit Audio button (single button, full width)
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit Audio',
                    onPressed: _handleEdit,
                  ),
                ),

                const SizedBox(height: 24),

                // Metadata Form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Podcast Details',
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Title
                      PillTextFieldOutlined(
                        controller: _titleController,
                        labelText: 'Title',
                        hintText: 'Enter podcast title',
                        prefixIcon: Icons.title,
                      ),
                      const SizedBox(height: 16),
                      
                      // Description (serves as caption/description)
                      PillTextFieldOutlined(
                        controller: _descriptionController,
                        labelText: 'Description / Caption',
                        hintText: 'Enter podcast description or caption',
                        prefixIcon: Icons.description,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      
                      // Tags
                      PillTextFieldOutlined(
                        controller: _tagsController,
                        labelText: 'Tags',
                        hintText: 'Enter tags (comma separated)',
                        prefixIcon: Icons.tag,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Publish Button - Pill shaped
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handlePublish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warmBrown,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.warmBrown.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.publish, size: 20),
                    label: Text(
                      _isLoading ? 'Publishing...' : 'Publish Podcast',
                      style: AppTypography.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Save Draft button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _saveDraft();
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Draft'),
                  ),
                ),

                const SizedBox(height: AppSpacing.extraLarge),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.warmBrown.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppColors.warmBrown,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warmBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
