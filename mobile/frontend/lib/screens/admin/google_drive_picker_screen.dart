import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../creation/audio_preview_screen.dart';
import '../creation/video_preview_screen.dart';
import 'google_picker_webview_screen.dart';

class GoogleDrivePickerScreen extends StatefulWidget {
  final String? fileType; // "audio", "video", "image"
  
  const GoogleDrivePickerScreen({super.key, this.fileType});

  @override
  State<GoogleDrivePickerScreen> createState() => _GoogleDrivePickerScreenState();
}

class _GoogleDrivePickerScreenState extends State<GoogleDrivePickerScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  bool _isConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try to get picker token to check if connected
      await _api.getGoogleDrivePickerToken();
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _connectGoogleDrive() async {
    try {
      final authUrl = await _api.getGoogleDriveAuthUrl();
      
      // Open URL in browser
      final uri = Uri.parse(authUrl);
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
        
        // Show dialog with instructions
        if (mounted) {
          _showConnectionDialog();
        }
      } else {
        setState(() {
          _error = 'Cannot open browser. Please check your device settings.';
        });
      }
    } catch (e) {
      String errorMessage = 'Failed to connect: $e';
      
      // Check if it's a configuration error
      if (e.toString().contains('503') || e.toString().contains('not configured')) {
        errorMessage = 'Google Drive is not configured. Please contact administrator to set up Google Drive integration.';
      }
      
      setState(() {
        _error = errorMessage;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_upload, color: AppColors.primaryMain),
            const SizedBox(width: 8),
            Text(
              'Connect Google Drive',
              style: AppTypography.heading3,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow these steps:',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildStepItem('1', 'A browser window has opened'),
            const SizedBox(height: 8),
            _buildStepItem('2', 'Sign in to your Google account'),
            const SizedBox(height: 8),
            _buildStepItem('3', 'Authorize the app to access Google Drive'),
            const SizedBox(height: 8),
            _buildStepItem('4', 'Copy the authorization code from the browser'),
            const SizedBox(height: 8),
            _buildStepItem('5', 'Return to this screen and tap "Check Connection"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
            ),
            child: const Text('Check Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryMain,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body,
          ),
        ),
      ],
    );
  }

  void _openGoogleDrivePicker() {
    // Navigate to Google Picker WebView screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GooglePickerWebViewScreen(
          fileType: widget.fileType,
          onFileSelected: (fileId, fileName, mimeType) {
            // Handle file selection
            _handleFileSelected(fileId, fileName, mimeType);
          },
        ),
      ),
    );
  }

  Future<void> _handleFileSelected(String fileId, String fileName, String mimeType) async {
    // Determine file type
    String fileType = widget.fileType ?? '';
    if (fileType.isEmpty) {
      if (mimeType.contains('audio')) {
        fileType = 'audio';
      } else if (mimeType.contains('video')) {
        fileType = 'video';
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unsupported file type'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // For video files, ask user to choose content type
    if (fileType == 'video') {
      _showVideoContentTypeSelector(fileId, fileName);
      return;
    }

    // For audio files, directly import and navigate
    _importAndNavigate(fileId, fileType, fileName, 'audio_podcast');
  }

  void _showVideoContentTypeSelector(String fileId, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Content Type',
          style: AppTypography.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.podcasts, color: AppColors.primaryMain),
              title: Text(
                'Video Podcast',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Create a video podcast',
                style: AppTypography.bodySmall,
              ),
              onTap: () {
                Navigator.pop(context);
                _importAndNavigate(fileId, 'video', fileName, 'video_podcast');
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.movie, color: AppColors.accentMain),
              title: Text(
                'Movie',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Create a movie',
                style: AppTypography.bodySmall,
              ),
              onTap: () {
                Navigator.pop(context);
                _importAndNavigate(fileId, 'video', fileName, 'movie');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importAndNavigate(
    String fileId,
    String fileType,
    String fileName,
    String contentType, // 'audio_podcast', 'video_podcast', 'movie'
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Importing file from Google Drive...',
              style: AppTypography.body,
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    try {
      // Import file from Google Drive
      final result = await _api.importGoogleDriveFile(fileId, fileType);
      
      if (!mounted) return;
      
      Navigator.pop(context); // Close loading dialog
      
      // Get the imported file path and convert to media URL
      final filePath = result['file_path'] as String;
      final mediaUrl = _api.getMediaUrl(filePath);
      final fileSize = result['file_size'] as int? ?? 0;
      final duration = result['duration'] as int? ?? 0;
      
      // Navigate to appropriate creation screen
      if (contentType == 'audio_podcast') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPreviewScreen(
              audioUri: mediaUrl,
              source: 'file',
              duration: duration,
              fileSize: fileSize,
            ),
          ),
        );
      } else if (contentType == 'video_podcast') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPreviewScreen(
              videoUri: mediaUrl,
              source: 'gallery',
              duration: duration,
              fileSize: fileSize,
            ),
          ),
        );
      } else if (contentType == 'movie') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Movie creation coming soon. File imported: $fileName'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context); // Go back to create screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileType != null
              ? 'Select ${widget.fileType == 'audio' ? 'Audio' : 'Video'} from Google Drive'
              : 'Google Drive',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConnection,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isConnected
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Connect to Google Drive',
                          style: AppTypography.heading2.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error != null && (_error!.contains('not configured') || _error!.contains('503'))
                              ? 'Google Drive integration needs to be configured by the administrator.'
                              : 'Connect your Google Drive account to browse and select files directly from your Drive.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: _error != null && (_error!.contains('not configured') || _error!.contains('503'))
                                ? Colors.orange
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (_error != null && (_error!.contains('not configured') || _error!.contains('503')))
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Setup Required',
                                        style: AppTypography.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Google Drive integration needs to be configured by the administrator. '
                                    'This feature requires Google OAuth credentials.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _error != null && (_error!.contains('not configured') || _error!.contains('503'))
                              ? null
                              : _connectGoogleDrive,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('Connect Google Drive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMain,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_done,
                            size: 64,
                            color: AppColors.primaryMain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Google Drive Connected',
                          style: AppTypography.heading2.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.fileType != null
                              ? 'Tap the button below to browse and select ${widget.fileType == 'audio' ? 'an audio' : 'a video'} file from your Google Drive'
                              : 'Tap the button below to browse and select a file from your Google Drive',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _openGoogleDrivePicker,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse Google Drive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryMain,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
