import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared/pill_text_field.dart';

/// Bible Document Upload Screen - Admin only
/// Allows uploading PDF Bible versions with metadata
class BibleUploadScreen extends StatefulWidget {
  const BibleUploadScreen({super.key});

  @override
  State<BibleUploadScreen> createState() => _BibleUploadScreenState();
}

class _BibleUploadScreenState extends State<BibleUploadScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _versionNameController = TextEditingController();
  final _abbreviationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  @override
  void dispose() {
    _versionNameController.dispose();
    _abbreviationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          
          // Auto-fill version name from filename if empty
          if (_versionNameController.text.isEmpty) {
            // Extract name from filename (remove extension and common patterns)
            String name = file.name.replaceAll('.pdf', '');
            name = name.replaceAll(RegExp(r'[_-]'), ' ');
            _versionNameController.text = name;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick file: $e', isError: true);
    }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFilePath == null) {
      _showSnackBar('Please select a Bible PDF file', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    try {
      // Step 1: Upload the PDF file
      setState(() => _uploadProgress = 0.2);
      final uploadResult = await _api.uploadFile(_selectedFilePath!, 'document');
      final fileUrl = uploadResult['file_path'] ?? uploadResult['url'];
      
      if (fileUrl == null || fileUrl.isEmpty) {
        throw Exception('Upload failed - no URL returned');
      }
      
      setState(() => _uploadProgress = 0.6);

      // Step 2: Create the document entry with Bible metadata
      // Include abbreviation in title for easy identification
      final fullTitle = '${_versionNameController.text.trim()} (${_abbreviationController.text.trim()})';
      final description = _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : 'Bible Version: ${_abbreviationController.text.trim()}';
      
      await _api.createDocument(
        title: fullTitle,
        description: description,
        filePath: fileUrl,
        category: 'Bible',
      );
      
      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        _showSnackBar('Bible document uploaded successfully!', isSuccess: true);
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
          'Upload Bible Document',
          style: AppTypography.heading3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  border: Border.all(color: AppColors.warmBrown.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: AppColors.warmBrown, size: 32),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bible Document Upload',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload a PDF Bible version that users can read in the Bible reader.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.extraLarge),

              // File picker
              Text(
                'Select PDF File',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedFilePath != null 
                          ? AppColors.successMain 
                          : AppColors.warmBrown.withOpacity(0.3),
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
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _selectedFilePath != null 
                              ? AppColors.successMain.withOpacity(0.1)
                              : AppColors.warmBrown.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedFilePath != null 
                              ? Icons.check_circle 
                              : Icons.upload_file,
                          size: 28,
                          color: _selectedFilePath != null 
                              ? AppColors.successMain 
                              : AppColors.warmBrown,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedFileName != null) ...[
                        Text(
                          _selectedFileName!,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(_selectedFileSize ?? 0),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Tap to select a PDF file',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF format only',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.extraLarge),

              // Version Name
              Text(
                'Version Name *',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              PillTextFieldOutlined(
                controller: _versionNameController,
                labelText: '',
                hintText: 'e.g., King James Version',
                prefixIcon: Icons.book,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a version name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.large),

              // Abbreviation
              Text(
                'Abbreviation *',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              PillTextFieldOutlined(
                controller: _abbreviationController,
                labelText: '',
                hintText: 'e.g., KJV, NIV, ESV',
                prefixIcon: Icons.short_text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an abbreviation';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.large),

              // Description
              Text(
                'Description (optional)',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              PillTextFieldOutlined(
                controller: _descriptionController,
                labelText: '',
                hintText: 'Add a description of this Bible version...',
                prefixIcon: Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: AppSpacing.extraLarge),

              // Upload progress
              if (_isUploading) ...[
                Container(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.warmBrown,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.warmBrown,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.warmBrown.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmBrown),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
              ],

              // Error message
              if (_error != null) ...[
                Container(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: AppColors.errorMain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.errorMain.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.errorMain),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.errorMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
              ],

              // Upload button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _upload,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Bible Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmBrown,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.warmBrown.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

