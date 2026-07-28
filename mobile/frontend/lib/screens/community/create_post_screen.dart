import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/community_provider.dart';
import '../../providers/draft_provider.dart';
import '../../providers/creator_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

/// Instagram-style Create Post Screen
/// Redesigned with app theme and improved UX
class CreatePostScreen extends StatefulWidget {
  final int? draftId;
  
  const CreatePostScreen({super.key, this.draftId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();
  String _postType = 'image'; // 'image' or 'text'
  String? _userName;
  String? _userAvatar;
  bool _hasUnsavedChanges = false;
  int? _draftId;
  bool _isLoadingDraft = false;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    _captionController.addListener(_onFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<CreatorProvider>().ensureReadyOrRedirect(context);
    });
    _loadUserInfo();
    if (_draftId != null) {
      _loadDraft();
    }
  }

  Future<void> _loadUserInfo() async {
    final authService = AuthService();
    final user = await authService.getUser();
    if (user != null && mounted) {
      setState(() {
        _userName = user['username'] ?? user['name'] ?? 'User';
        _userAvatar = user['avatar_url'];
      });
    }
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _loadDraft() async {
    if (_draftId == null) return;
    
    setState(() => _isLoadingDraft = true);
    try {
      final draftProvider = context.read<DraftProvider>();
      final draft = await draftProvider.getDraft(_draftId!);
      
      if (draft != null && mounted) {
        // Load text content
        if (draft.description != null) {
          _captionController.text = draft.description!;
        } else if (draft.content != null) {
          _captionController.text = draft.content!;
        }
        
        // Load image if exists
        File? loadedImage;
        if (draft.originalMediaUrl != null) {
          final imageUrl = draft.originalMediaUrl!;
          // Check if it's a local file path or network URL
          if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
            // Network URL - set uploadedImageUrl so it can be used
            _uploadedImageUrl = imageUrl;
            _postType = 'image';
          } else {
            // Local file path
            final file = File(imageUrl);
            if (await file.exists()) {
              loadedImage = file;
              _postType = 'image';
            }
          }
        } else {
          // No image, check if it's a text post
          if (draft.content != null && draft.originalMediaUrl == null) {
            _postType = 'text';
          }
        }
        
        // Update state with loaded data
        if (mounted) {
          setState(() {
            _selectedImage = loadedImage;
            _hasUnsavedChanges = false; // Reset since we just loaded
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading draft: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDraft = false);
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
              backgroundColor: AppColors.warmBrown,
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
      
      // Determine title from caption (first line or "Untitled Post")
      String? title;
      final captionText = _captionController.text.trim();
      if (captionText.isNotEmpty) {
        final firstLine = captionText.split('\n').first;
        title = firstLine.isNotEmpty ? firstLine : 'Untitled Post';
      } else {
        title = 'Untitled Post';
      }
      
      // Determine media URL - upload to S3 if local file
      String? mediaUrl;
      if (_selectedImage != null) {
        // Upload local image to S3
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading image to S3...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        mediaUrl = await apiService.uploadDraftImage(filePath: _selectedImage!.path);
      } else if (_uploadedImageUrl != null) {
        // Already uploaded to S3
        mediaUrl = _uploadedImageUrl;
      }
      
      final draft = ContentDraft(
        id: _draftId,
        userId: 0, // Backend uses current user from token
        draftType: DraftType.communityPost,
        title: title,
        description: captionText.isNotEmpty ? captionText : null,
        content: captionText.isNotEmpty ? captionText : null,
        originalMediaUrl: mediaUrl,
        status: DraftStatus.editing,
      );

      ContentDraft? savedDraft;
      if (_draftId != null) {
        savedDraft = await draftProvider.updateDraft(draft);
      } else {
        savedDraft = await draftProvider.createDraft(draft);
      }

      if (savedDraft != null && mounted) {
        setState(() {
          _draftId = savedDraft!.id;
          _hasUnsavedChanges = false;
        });
        
        // Refresh drafts list
        await draftProvider.fetchDrafts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            backgroundColor: AppColors.successMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        );
        return true;
      }
      return false;
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _uploadedImageUrl = null;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                _buildSourceOption(
                  icon: Icons.photo_library,
                  label: 'Choose from Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(source: ImageSource.gallery);
                  },
                ),
                const SizedBox(height: AppSpacing.small),
                _buildSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Take a Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(source: ImageSource.camera);
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warmBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.warmBrown),
      ),
      title: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
      _hasUnsavedChanges = true;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    setState(() => _isUploadingImage = true);
    try {
      final apiService = ApiService();
      final bytes = await _selectedImage!.readAsBytes();
      final fileName = _selectedImage!.path.split('/').last;

      final response = await apiService.uploadImage(
        fileName: fileName,
        bytes: bytes,
      );

      setState(() => _isUploadingImage = false);
      return response['file_path'] as String?;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    // Validate based on post type
    if (_postType == 'image') {
      if (_selectedImage == null && _captionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please add a photo or write a caption'),
            backgroundColor: AppColors.warningMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    } else {
      if (_captionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please write something to post'),
            backgroundColor: AppColors.warningMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;

      if (_postType == 'image') {
        imageUrl = _uploadedImageUrl;
        if (_selectedImage != null && imageUrl == null) {
          imageUrl = await _uploadImage();
          if (imageUrl == null) {
            setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      await context.read<CommunityProvider>().createPost(
            title: _captionController.text.trim().isEmpty
                ? (_postType == 'image' ? 'Photo' : 'Quote')
                : _captionController.text.trim().split('\n').first,
            content: _captionController.text.trim(),
            category: 'General',
            imageUrl: imageUrl,
            postType: _postType,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post submitted! It will be reviewed by an admin.'),
          backgroundColor: AppColors.successMain,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      // Reset unsaved changes after successful submission
      setState(() {
        _hasUnsavedChanges = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to publish post: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDraft) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.warmBrown),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'New Post',
            style: AppTypography.heading3.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
          // Save Draft button
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.warmBrown),
            tooltip: 'Save Draft',
            onPressed: _isLoadingDraft ? null : () async {
              await _saveDraft();
            },
          ),
          // Share button
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.small),
            child: TextButton(
              onPressed: (_isSubmitting || _isUploadingImage) ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: (_isSubmitting || _isUploadingImage)
                    ? AppColors.warmBrown.withOpacity(0.5)
                    : AppColors.warmBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: (_isSubmitting || _isUploadingImage)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Share',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          ],
        ),
        body: Column(
        children: [
          // Post type selector (pill style)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.warmBrown.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildPostTypeTab(
                    icon: Icons.image,
                    label: 'Photo',
                    isSelected: _postType == 'image',
                    onTap: () => setState(() => _postType = 'image'),
                  ),
                  _buildPostTypeTab(
                    icon: Icons.format_quote,
                    label: 'Text',
                    isSelected: _postType == 'text',
                    onTap: () {
                      setState(() {
                        _postType = 'text';
                        _selectedImage = null;
                        _uploadedImageUrl = null;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Content area
          Expanded(
            child: _postType == 'image'
                ? _buildImagePostContent()
                : _buildTextPostContent(),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildPostTypeTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.warmBrown : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePostContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          // User header
          _buildUserHeader(),

          const SizedBox(height: AppSpacing.medium),

          // Caption input
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warmBrown.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.medium),

          // Image picker / preview
          GestureDetector(
            onTap: _selectedImage == null ? _showImageSourcePicker : null,
            child: Container(
              width: double.infinity,
              height: _selectedImage != null ? 300 : 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedImage != null
                      ? AppColors.warmBrown.withOpacity(0.3)
                      : AppColors.warmBrown.withOpacity(0.15),
                  width: _selectedImage != null ? 2 : 1,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                          // Gradient overlay
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Remove button
                          Positioned(
                            top: AppSpacing.small,
                            right: AppSpacing.small,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Change photo button
                          Positioned(
                            top: AppSpacing.small,
                            left: AppSpacing.small,
                            child: GestureDetector(
                              onTap: _showImageSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.swap_horiz,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Change',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warmBrown.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: AppColors.warmBrown,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                        Text(
                          'Tap to add a photo',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.warmBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share a moment with the community',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPostContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          // User header
          _buildUserHeader(),

          const SizedBox(height: AppSpacing.medium),

          // Large text input with styled container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.large),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.warmBrown.withOpacity(0.15),
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
            child: Column(
              children: [
                Icon(
                  Icons.format_quote,
                  size: 32,
                  color: AppColors.warmBrown.withOpacity(0.5),
                ),
                const SizedBox(height: AppSpacing.small),
                TextField(
                  controller: _captionController,
                  maxLines: null,
                  minLines: 8,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?\n\nShare a thought, quote, or reflection...",
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.medium),

          // Tips section
          Container(
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.warmBrown,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    'Tip: Share inspiring Bible verses, daily reflections, or uplifting quotes.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warmBrown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warmBrown.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Profile avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.warmBrown,
            backgroundImage: _userAvatar != null ? NetworkImage(_userAvatar!) : null,
            child: _userAvatar == null
                ? Text(
                    (_userName?.isNotEmpty == true ? _userName![0] : 'U').toUpperCase(),
                    style: AppTypography.heading4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'User',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Everyone can see this',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
