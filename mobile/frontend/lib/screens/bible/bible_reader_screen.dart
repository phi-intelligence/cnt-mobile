import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/document_asset.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../utils/media_utils.dart';

/// Bible Reading Settings stored in SharedPreferences
class BibleReadingSettings {
  static const String _keyZoomLevel = 'bible_zoom_level';
  static const String _keyTheme = 'bible_theme';
  static const String _keyLastPage = 'bible_last_page_';
  
  static Future<double> getZoomLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyZoomLevel) ?? 1.0;
  }
  
  static Future<void> setZoomLevel(double zoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyZoomLevel, zoom);
  }
  
  static Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTheme) ?? 'light';
  }
  
  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme);
  }
  
  static Future<int> getLastPage(int documentId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyLastPage$documentId') ?? 1;
  }
  
  static Future<void> setLastPage(int documentId, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyLastPage$documentId', page);
  }
}

/// Enhanced Bible Reader Screen with reading settings
/// Features:
/// - Zoom controls
/// - Theme options (light, dark, sepia)
/// - Page navigation
/// - Reading progress persistence
/// - Bookmarking (page)
class BibleReaderScreen extends StatefulWidget {
  final DocumentAsset document;

  const BibleReaderScreen({
    super.key,
    required this.document,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  String _theme = 'light'; // light, dark, sepia
  bool _showSettings = false;
  List<int> _bookmarks = [];
  
  // Theme colors
  Color get _backgroundColor {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF1A1A1A);
      case 'sepia':
        return const Color(0xFFF5E6C8);
      default:
        return AppColors.backgroundPrimary;
    }
  }
  
  Color get _textColor {
    switch (_theme) {
      case 'dark':
        return Colors.white;
      case 'sepia':
        return const Color(0xFF5B4636);
      default:
        return AppColors.textPrimary;
    }
  }
  
  Color get _appBarColor {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF2D2D2D);
      case 'sepia':
        return const Color(0xFFD4B896);
      default:
        return AppColors.warmBrown;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDocument();
    _loadBookmarks();
  }
  
  Future<void> _loadSettings() async {
    final zoom = await BibleReadingSettings.getZoomLevel();
    final theme = await BibleReadingSettings.getTheme();
    final lastPage = await BibleReadingSettings.getLastPage(widget.document.id ?? 0);
    
    if (mounted) {
      setState(() {
        _zoomLevel = zoom;
        _theme = theme;
        _currentPage = lastPage;
      });
    }
  }
  
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkKey = 'bible_bookmarks_${widget.document.id}';
    final bookmarkList = prefs.getStringList(bookmarkKey) ?? [];
    setState(() {
      _bookmarks = bookmarkList.map((s) => int.tryParse(s) ?? 0).where((p) => p > 0).toList();
    });
  }
  
  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkKey = 'bible_bookmarks_${widget.document.id}';
    
    setState(() {
      if (_bookmarks.contains(_currentPage)) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
    
    await prefs.setStringList(bookmarkKey, _bookmarks.map((p) => p.toString()).toList());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarks.contains(_currentPage) 
            ? 'Page $_currentPage bookmarked' 
            : 'Bookmark removed'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadDocument() async {
    try {
      final url = resolveMediaUrl(widget.document.filePath);
      if (url == null) {
        throw Exception('Document URL is not available.');
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download document (HTTP ${response.statusCode}).');
      }

      final pdfDocFuture = PdfDocument.openData(response.bodyBytes);
      _pdfController = PdfControllerPinch(
        document: pdfDocFuture,
        initialPage: _currentPage,
      );
      
      final pdfDoc = await pdfDocFuture;
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalPages = pdfDoc.pagesCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    // Save last page for reading progress
    BibleReadingSettings.setLastPage(widget.document.id ?? 0, page);
  }
  
  void _setZoom(double zoom) {
    setState(() {
      _zoomLevel = zoom.clamp(0.5, 3.0);
    });
    BibleReadingSettings.setZoomLevel(_zoomLevel);
  }
  
  void _setTheme(String theme) {
    setState(() {
      _theme = theme;
    });
    BibleReadingSettings.setTheme(theme);
  }
  
  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages && _pdfController != null) {
      _pdfController!.jumpToPage(page);
    }
  }
  
  void _showPageNavigator() {
    final controller = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text('Go to Page', style: TextStyle(color: _textColor)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 - $_totalPages',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null) {
              _goToPage(page);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null) {
                _goToPage(page);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmBrown,
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }
  
  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bookmarks',
              style: AppTypography.heading3.copyWith(color: _textColor),
            ),
            const SizedBox(height: 16),
            if (_bookmarks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.bookmark_border, size: 48, color: _textColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No bookmarks yet',
                        style: AppTypography.body.copyWith(color: _textColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the bookmark icon to save pages',
                        style: AppTypography.caption.copyWith(color: _textColor.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_bookmarks.length, (index) {
                final page = _bookmarks[index];
                return ListTile(
                  leading: Icon(Icons.bookmark, color: AppColors.warmBrown),
                  title: Text('Page $page', style: TextStyle(color: _textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _goToPage(page);
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: _textColor.withOpacity(0.5)),
                    onPressed: () async {
                      setState(() {
                        _bookmarks.remove(page);
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setStringList(
                        'bible_bookmarks_${widget.document.id}',
                        _bookmarks.map((p) => p.toString()).toList(),
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (_bookmarks.isNotEmpty) {
                          _showBookmarksSheet();
                        }
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _theme == 'dark' ? Colors.white : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.title ?? 'Bible',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
          ],
        ),
        actions: [
          // Bookmark toggle
          IconButton(
            icon: Icon(
              _bookmarks.contains(_currentPage) ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: _toggleBookmark,
            tooltip: 'Bookmark this page',
          ),
          // View bookmarks
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
            onPressed: _showBookmarksSheet,
            tooltip: 'View bookmarks',
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            tooltip: 'Reading settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          _buildBody(),
          
          // Settings Panel
          if (_showSettings)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildSettingsPanel(),
            ),
          
          // Bottom Navigation Bar
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsPanel() {
    return Container(
      margin: EdgeInsets.all(AppSpacing.medium),
      padding: EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: _theme == 'dark' ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading Settings',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: _textColor),
                onPressed: () => setState(() => _showSettings = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Theme Selection
          Text(
            'Theme',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildThemeButton('light', 'Light', Colors.white, Colors.black),
              const SizedBox(width: 8),
              _buildThemeButton('sepia', 'Sepia', const Color(0xFFF5E6C8), const Color(0xFF5B4636)),
              const SizedBox(width: 8),
              _buildThemeButton('dark', 'Dark', const Color(0xFF1A1A1A), Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          
          // Zoom Level
          Text(
            'Zoom: ${(_zoomLevel * 100).toInt()}%',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: _textColor),
                onPressed: () => _setZoom(_zoomLevel - 0.25),
              ),
              Expanded(
                child: Slider(
                  value: _zoomLevel,
                  min: 0.5,
                  max: 3.0,
                  divisions: 10,
                  activeColor: AppColors.warmBrown,
                  onChanged: _setZoom,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: _textColor),
                onPressed: () => _setZoom(_zoomLevel + 0.25),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeButton(String theme, String label, Color bgColor, Color textColor) {
    final isSelected = _theme == theme;
    return Expanded(
      child: InkWell(
        onTap: () => _setTheme(theme),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.warmBrown : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: _theme == 'dark' ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous page
            IconButton(
              icon: Icon(Icons.chevron_left, color: _textColor, size: 32),
              onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            ),
            
            // Page indicator - tappable for navigation
            InkWell(
              onTap: _showPageNavigator,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            // Progress bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LinearProgressIndicator(
                  value: _totalPages > 0 ? _currentPage / _totalPages : 0,
                  backgroundColor: _textColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmBrown),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            
            // Next page
            IconButton(
              icon: Icon(Icons.chevron_right, color: _textColor, size: 32),
              onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.warmBrown),
            const SizedBox(height: 16),
            Text(
              'Loading Bible...',
              style: AppTypography.body.copyWith(color: _textColor),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null || _pdfController == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.errorMain),
              const SizedBox(height: 16),
              Text(
                'Unable to open Bible document',
                style: AppTypography.heading4.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred.',
                style: AppTypography.bodySmall.copyWith(
                  color: _textColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadDocument();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmBrown,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 60), // Space for bottom bar
      child: PdfViewPinch(
        controller: _pdfController!,
        onPageChanged: _onPageChanged,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => Center(
            child: CircularProgressIndicator(color: AppColors.warmBrown),
          ),
          pageLoaderBuilder: (_) => Center(
            child: CircularProgressIndicator(color: AppColors.warmBrown),
          ),
          errorBuilder: (_, error) => Center(
            child: Text(
              error.toString(),
              style: TextStyle(color: AppColors.errorMain),
            ),
          ),
        ),
      ),
    );
  }
}

