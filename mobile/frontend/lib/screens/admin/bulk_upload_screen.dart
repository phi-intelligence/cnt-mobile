import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../services/api_service.dart';
import '../../services/video_editing_service.dart';
import '../../services/audio_editing_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared/pill_text_field.dart';

/// Content type enum for bulk upload
enum BulkContentType {
  video,
  audio,
  document,
  image,
  unknown,
}

/// Model for a file to be uploaded
class BulkUploadFile {
  final String name;
  final String path;
  final int size;
  final BulkContentType contentType;
  String title;
  String? description;
  double uploadProgress;
  String? uploadedUrl;
  String? thumbnailUrl;
  String? error;
  bool isUploading;
  bool isCompleted;
  
  // Metadata extracted from file
  Duration? duration;
  int? width;
  int? height;
  String? format;
  int? bitrate;
  String? category;

  BulkUploadFile({
    required this.name,
    required this.path,
    required this.size,
    required this.contentType,
    String? title,
    this.description,
    this.uploadProgress = 0.0,
    this.uploadedUrl,
    this.thumbnailUrl,
    this.error,
    this.isUploading = false,
    this.isCompleted = false,
    this.duration,
    this.width,
    this.height,
    this.format,
    this.bitrate,
    this.category,
  }) : title = title ?? _extractTitle(name);

  static String _extractTitle(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot > 0) {
      // Clean up filename: remove underscores, dashes, and capitalize
      return filename
          .substring(0, lastDot)
          .replaceAll(RegExp(r'[_-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .split(' ')
          .map((word) => word.isNotEmpty 
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '')
          .join(' ');
    }
    return filename;
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    if (minutes > 60) {
      final hours = minutes ~/ 60;
      return '${hours}h ${minutes % 60}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  String get contentTypeLabel {
    switch (contentType) {
      case BulkContentType.video:
        return 'Video';
      case BulkContentType.audio:
        return 'Audio';
      case BulkContentType.document:
        return 'Document';
      case BulkContentType.image:
        return 'Image';
      case BulkContentType.unknown:
        return 'File';
    }
  }

  IconData get contentTypeIcon {
    switch (contentType) {
      case BulkContentType.video:
        return Icons.videocam;
      case BulkContentType.audio:
        return Icons.music_note;
      case BulkContentType.document:
        return Icons.description;
      case BulkContentType.image:
        return Icons.image;
      case BulkContentType.unknown:
        return Icons.insert_drive_file;
    }
  }

  Color get contentTypeColor {
    switch (contentType) {
      case BulkContentType.video:
        return const Color(0xFF6366F1);
      case BulkContentType.audio:
        return AppColors.warmBrown;
      case BulkContentType.document:
        return const Color(0xFF10B981);
      case BulkContentType.image:
        return const Color(0xFFF59E0B);
      case BulkContentType.unknown:
        return Colors.grey;
    }
  }
}

/// Bulk Upload Screen - Modern card-based wizard design
/// Multi-step upload process supporting all content types
class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final List<BulkUploadFile> _files = [];
  bool _autoGenerateThumbnails = true;
  bool _isUploading = false;
  bool _isExtractingMetadata = false;
  int _completedUploads = 0;
  int _failedUploads = 0;

  // File extensions by category
  static const Map<String, List<String>> _extensionsByType = {
    'video': ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v'],
    'audio': ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac', 'wma'],
    'document': ['pdf', 'doc', 'docx', 'txt', 'rtf', 'epub'],
    'image': ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'],
  };

  List<String> get _allAllowedExtensions {
    return _extensionsByType.values.expand((e) => e).toList();
  }

  BulkContentType _getContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    for (final entry in _extensionsByType.entries) {
      if (entry.value.contains(ext)) {
        switch (entry.key) {
          case 'video':
            return BulkContentType.video;
          case 'audio':
            return BulkContentType.audio;
          case 'document':
            return BulkContentType.document;
          case 'image':
            return BulkContentType.image;
        }
      }
    }
    return BulkContentType.unknown;
  }

  static const int _maxFiles = 50;

  final List<_StepInfo> _steps = const [
    _StepInfo(icon: Icons.folder_open, label: 'Select'),
    _StepInfo(icon: Icons.edit_note, label: 'Details'),
    _StepInfo(icon: Icons.cloud_upload, label: 'Upload'),
  ];

  // Categories for content
  final List<String> _categories = [
    'Sermons',
    'Bible Study',
    'Worship',
    'Testimonies',
    'Youth',
    'Children',
    'Teachings',
    'Events',
    'Other',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _steps.length && !_isUploading) {
      setState(() => _currentStep = step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _files.isEmpty) {
      _showSnackBar('Please select at least one file');
      return;
    }
    if (_currentStep < _steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else if (!_isUploading) {
      _startUpload();
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_isUploading) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allAllowedExtensions,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final remainingSlots = _maxFiles - _files.length;
        
        if (remainingSlots <= 0) {
          _showSnackBar('Maximum $_maxFiles files allowed. Remove some files first.', isError: true);
          return;
        }
        
        final filesToAdd = result.files.take(remainingSlots).toList();
        final skippedCount = result.files.length - filesToAdd.length;
        
        setState(() {
          for (final file in filesToAdd) {
            if (file.path == null) continue;
            if (_files.any((f) => f.name == file.name)) continue;

            _files.add(BulkUploadFile(
              name: file.name,
              path: file.path!,
              size: file.size,
              contentType: _getContentType(file.name),
            ));
          }
        });
        
        // Extract metadata for media files
        _extractMetadata();
        
        if (skippedCount > 0) {
          _showSnackBar(
            'Added ${filesToAdd.length} files. $skippedCount files skipped (max $_maxFiles).',
          );
        }
      }
    } catch (e) {
      _showSnackBar('Failed to pick files: $e', isError: true);
    }
  }

  Future<void> _extractMetadata() async {
    if (kIsWeb) return;
    
    setState(() => _isExtractingMetadata = true);
    
    final videoService = VideoEditingService();
    final audioService = AudioEditingService();
    
    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];
      if (file.duration != null) continue; // Already extracted
      
      // Extract metadata for video files using FFprobe
      if (file.contentType == BulkContentType.video) {
        try {
          final metadata = await videoService.getVideoMetadata(file.path);
          
          if (metadata != null) {
            setState(() {
              _files[i].duration = metadata['duration'] as Duration?;
              _files[i].width = metadata['width'] as int?;
              _files[i].height = metadata['height'] as int?;
              _files[i].format = metadata['format'] as String?;
              _files[i].bitrate = metadata['bitrate'] != null 
                  ? int.tryParse(metadata['bitrate'].toString()) 
                  : null;
            });
          }
        } catch (e) {
          // Metadata extraction failed, continue without it
          debugPrint('Failed to extract video metadata for ${file.name}: $e');
        }
      }
      
      // Extract metadata for audio files using FFprobe
      else if (file.contentType == BulkContentType.audio) {
        try {
          final metadata = await audioService.getAudioMetadata(file.path);
          
          if (metadata != null) {
            setState(() {
              _files[i].duration = metadata['duration'] as Duration?;
              _files[i].format = metadata['format'] as String?;
              _files[i].bitrate = metadata['bitrate'] != null 
                  ? int.tryParse(metadata['bitrate'].toString()) 
                  : null;
            });
          }
        } catch (e) {
          // Metadata extraction failed, continue without it
          debugPrint('Failed to extract audio metadata for ${file.name}: $e');
        }
      }
    }
    
    setState(() => _isExtractingMetadata = false);
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? AppColors.successMain
            : isError
                ? AppColors.errorMain
                : AppColors.warmBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _startUpload() async {
    if (_files.isEmpty) return;

    setState(() {
      _isUploading = true;
      _completedUploads = 0;
      _failedUploads = 0;
    });

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];
      if (file.isCompleted || file.path.isEmpty) continue;

      setState(() {
        _files[i].isUploading = true;
        _files[i].error = null;
        _files[i].uploadProgress = 0.1;
      });

      try {
        setState(() => _files[i].uploadProgress = 0.3);
        
        // Determine file type for upload
        String fileType;
        switch (file.contentType) {
          case BulkContentType.video:
            fileType = 'video';
            break;
          case BulkContentType.audio:
            fileType = 'audio';
            break;
          case BulkContentType.document:
            fileType = 'document';
            break;
          case BulkContentType.image:
            fileType = 'image';
            break;
          default:
            fileType = 'file';
        }
        
        final uploadResult = await _api.uploadFile(file.path, fileType);
        final mediaUrl = uploadResult['file_path'] ?? uploadResult['url'];
        
        if (mediaUrl == null || mediaUrl.isEmpty) {
          throw Exception('Upload failed - no URL returned');
        }
        
        setState(() => _files[i].uploadProgress = 0.6);

        // Create content based on type
        if (file.contentType == BulkContentType.video ||
            file.contentType == BulkContentType.audio) {
          final podcastData = {
            'title': file.title,
            'description': file.description ?? _generateDescription(file),
            'type': fileType,
            if (file.contentType == BulkContentType.video) 'video_url': mediaUrl,
            if (file.contentType == BulkContentType.audio) 'audio_url': mediaUrl,
            'use_default_thumbnail': _autoGenerateThumbnails,
            'thumbnail_timestamp': 30,
            if (file.duration != null) 'duration': file.duration!.inSeconds,
            if (file.category != null) 'category': file.category,
          };
          
          setState(() => _files[i].uploadProgress = 0.8);
          
          await _api.createBulkPodcasts([podcastData]);
        } else if (file.contentType == BulkContentType.document) {
          // Create document/bible document
          setState(() => _files[i].uploadProgress = 0.8);
          
          await _api.createDocument(
            title: file.title,
            description: file.description ?? _generateDescription(file),
            filePath: mediaUrl,
            category: file.category ?? 'Documents',
          );
        } else if (file.contentType == BulkContentType.image) {
          // Create post with image
          setState(() => _files[i].uploadProgress = 0.8);
          
          await _api.createPost(
            title: file.title,
            content: file.description ?? _generateDescription(file),
            imageUrl: mediaUrl,
            category: file.category ?? 'General',
          );
        }
        
        setState(() {
          _files[i].uploadedUrl = mediaUrl;
          _files[i].uploadProgress = 1.0;
          _files[i].isCompleted = true;
          _files[i].isUploading = false;
          _completedUploads++;
        });
      } catch (e) {
        setState(() {
          _files[i].error = e.toString();
          _files[i].isUploading = false;
          _failedUploads++;
        });
      }
    }

    setState(() {
      _isUploading = false;
    });

    if (mounted) {
      _showSnackBar(
        'Upload complete: $_completedUploads succeeded, $_failedUploads failed',
        isSuccess: _failedUploads == 0,
        isError: _failedUploads > 0 && _completedUploads == 0,
      );
    }
  }

  String _generateDescription(BulkUploadFile file) {
    final parts = <String>[];
    
    if (file.duration != null) {
      parts.add('Duration: ${file.formattedDuration}');
    }
    
    if (file.width != null && file.height != null) {
      parts.add('Resolution: ${file.width}x${file.height}');
    }
    
    if (parts.isEmpty) {
      return 'Uploaded via bulk upload';
    }
    
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: AppColors.warmBrown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bulk Upload',
          style: AppTypography.heading3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                _buildFileSelectionStep(),
                _buildEditDetailsStep(),
                _buildUploadStep(),
              ],
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: const Color(0xFFF5F0E8),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isCompleted && !_isUploading ? () => _goToStep(index) : null,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isActive || isCompleted
                                ? AppColors.warmBrown
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive || isCompleted
                                  ? AppColors.warmBrown
                                  : AppColors.warmBrown.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.warmBrown.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check : _steps[index].icon,
                            color: isActive || isCompleted
                                ? Colors.white
                                : AppColors.warmBrown.withOpacity(0.5),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _steps[index].label,
                          style: AppTypography.caption.copyWith(
                            color: isActive
                                ? AppColors.warmBrown
                                : AppColors.textSecondary,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: index < _currentStep
                            ? AppColors.warmBrown
                            : AppColors.warmBrown.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0 && !_isUploading)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warmBrown,
                    side: BorderSide(color: AppColors.warmBrown),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            
            const SizedBox(width: 16),
            
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isUploading || _isExtractingMetadata ? null : _nextStep,
                icon: Icon(
                  _currentStep == _steps.length - 1
                      ? Icons.cloud_upload
                      : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  _isExtractingMetadata
                      ? 'Analyzing...'
                      : _currentStep == 0
                          ? 'Continue'
                          : _currentStep == 1
                              ? 'Review'
                              : _isUploading
                                  ? 'Uploading...'
                                  : 'Start Upload',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmBrown,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.warmBrown.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionStep() {
    // Group files by type
    final videoCount = _files.where((f) => f.contentType == BulkContentType.video).length;
    final audioCount = _files.where((f) => f.contentType == BulkContentType.audio).length;
    final docCount = _files.where((f) => f.contentType == BulkContentType.document).length;
    final imageCount = _files.where((f) => f.contentType == BulkContentType.image).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warmBrown,
                  AppColors.warmBrown.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_upload, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Upload All Content Types',
                  style: AppTypography.heading4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Videos, Audio, Documents, Images',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Content type summary
          if (_files.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (videoCount > 0) _buildTypeBadge('Videos', videoCount, BulkContentType.video),
                if (audioCount > 0) _buildTypeBadge('Audio', audioCount, BulkContentType.audio),
                if (docCount > 0) _buildTypeBadge('Documents', docCount, BulkContentType.document),
                if (imageCount > 0) _buildTypeBadge('Images', imageCount, BulkContentType.image),
              ],
            ),
            const SizedBox(height: 20),
          ],
          
          // File picker area
          InkWell(
            onTap: _pickFiles,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warmBrown.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      size: 32,
                      color: AppColors.warmBrown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to select files',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Videos, Audio, PDFs, Images • Max $_maxFiles files',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Loading indicator for metadata extraction
          if (_isExtractingMetadata)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.warmBrown),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analyzing files and extracting metadata...',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warmBrown,
                    ),
                  ),
                ],
              ),
            ),

          // Selected files list
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Selected Files (${_files.length})',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _files.clear()),
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorMain),
                  label: Text(
                    'Clear All',
                    style: TextStyle(color: AppColors.errorMain),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_files.length, (index) {
              final file = _files[index];
              return _buildFileCard(file, index);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String label, int count, BulkContentType type) {
    final color = BulkUploadFile(
      name: '',
      path: '',
      size: 0,
      contentType: type,
    ).contentTypeColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            BulkUploadFile(name: '', path: '', size: 0, contentType: type).contentTypeIcon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BulkUploadFile file, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                file.contentTypeColor,
                file.contentTypeColor.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            file.contentTypeIcon,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              file.formattedSize,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (file.duration != null) ...[
              const SizedBox(width: 8),
              Text(
                '• ${file.formattedDuration}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: file.contentTypeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                file.contentTypeLabel,
                style: AppTypography.caption.copyWith(
                  color: file.contentTypeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
          onPressed: () => _removeFile(index),
        ),
      ),
    );
  }

  Widget _buildEditDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto-generate thumbnails option (only for video/audio)
          if (_files.any((f) => f.contentType == BulkContentType.video || f.contentType == BulkContentType.audio))
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SwitchListTile(
                title: Text(
                  'Auto-generate thumbnails',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Generate thumbnail from video at 30 seconds',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _autoGenerateThumbnails,
                activeColor: AppColors.warmBrown,
                onChanged: (value) {
                  setState(() => _autoGenerateThumbnails = value);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          const SizedBox(height: 20),
          
          Text(
            'Edit File Details',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // File details editor
          ...List.generate(_files.length, (index) {
            final file = _files[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          file.contentTypeColor,
                          file.contentTypeColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      file.contentTypeIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    file.title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        file.name,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (file.duration != null) ...[
                        Text(
                          ' • ${file.formattedDuration}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warmBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  initiallyExpanded: index == 0,
                  children: [
                    PillTextFieldOutlined(
                      initialValue: file.title,
                      labelText: 'Title',
                      hintText: 'Enter title',
                      prefixIcon: Icons.title,
                      onChanged: (value) {
                        _files[index].title = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    PillTextFieldOutlined(
                      initialValue: file.description ?? '',
                      labelText: 'Description (optional)',
                      hintText: 'Enter description',
                      prefixIcon: Icons.description,
                      maxLines: 2,
                      onChanged: (value) {
                        _files[index].description = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: file.category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category, color: AppColors.warmBrown),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.warmBrown.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.warmBrown.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: AppColors.warmBrown),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _categories.map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _files[index].category = value;
                        });
                      },
                    ),
                    // Show metadata if available
                    if (file.duration != null || file.width != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _generateDescription(file),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUploadStep() {
    final totalProgress = _files.isEmpty
        ? 0.0
        : _files.map((f) => f.uploadProgress).reduce((a, b) => a + b) / _files.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Overall progress card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warmBrown,
                  AppColors.warmBrown.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: totalProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      '${(totalProgress * 100).toInt()}%',
                      style: AppTypography.heading4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isUploading
                      ? 'Uploading...'
                      : _completedUploads == _files.length
                          ? 'All Complete!'
                          : 'Ready to Upload',
                  style: AppTypography.heading4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_completedUploads of ${_files.length} files uploaded',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Individual file progress
          ...List.generate(_files.length, (index) {
            final file = _files[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: file.isCompleted
                              ? AppColors.successMain.withOpacity(0.1)
                              : file.error != null
                                  ? AppColors.errorMain.withOpacity(0.1)
                                  : file.contentTypeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          file.isCompleted
                              ? Icons.check_circle
                              : file.error != null
                                  ? Icons.error
                                  : file.isUploading
                                      ? Icons.cloud_upload
                                      : file.contentTypeIcon,
                          color: file.isCompleted
                              ? AppColors.successMain
                              : file.error != null
                                  ? AppColors.errorMain
                                  : file.contentTypeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.title,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  file.formattedSize,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: file.contentTypeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    file.contentTypeLabel,
                                    style: AppTypography.caption.copyWith(
                                      color: file.contentTypeColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: file.isCompleted
                              ? AppColors.successMain.withOpacity(0.1)
                              : file.error != null
                                  ? AppColors.errorMain.withOpacity(0.1)
                                  : AppColors.warmBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          file.isCompleted
                              ? 'Done'
                              : file.error != null
                                  ? 'Failed'
                                  : '${(file.uploadProgress * 100).toInt()}%',
                          style: AppTypography.caption.copyWith(
                            color: file.isCompleted
                                ? AppColors.successMain
                                : file.error != null
                                    ? AppColors.errorMain
                                    : AppColors.warmBrown,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: file.uploadProgress,
                      backgroundColor: const Color(0xFFF5F0E8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        file.isCompleted
                            ? AppColors.successMain
                            : file.error != null
                                ? AppColors.errorMain
                                : file.contentTypeColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  if (file.error != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.warning_amber, size: 14, color: AppColors.errorMain),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            file.error!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.errorMain,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepInfo {
  final IconData icon;
  final String label;

  const _StepInfo({required this.icon, required this.label});
}
