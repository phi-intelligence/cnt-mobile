import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/api_service.dart';
import '../../utils/app_logger.dart';

/// Google Drive file picker with hardened WebView settings.
class GooglePickerWebViewScreen extends StatefulWidget {
  final String? fileType;
  final void Function(String fileId, String fileName, String mimeType) onFileSelected;

  const GooglePickerWebViewScreen({
    super.key,
    this.fileType,
    required this.onFileSelected,
  });

  @override
  State<GooglePickerWebViewScreen> createState() =>
      _GooglePickerWebViewScreenState();
}

class _GooglePickerWebViewScreenState extends State<GooglePickerWebViewScreen> {
  WebViewController? _controller;
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _accessToken;
  String? _clientId;

  static const _allowedHosts = {
    'accounts.google.com',
    'apis.google.com',
    'www.googleapis.com',
    'docs.google.com',
    'drive.google.com',
    'ssl.gstatic.com',
    'www.gstatic.com',
  };

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      final tokenData = await _api.getGoogleDrivePickerToken();
      _accessToken = tokenData['access_token'] as String?;
      _clientId = tokenData['client_id'] as String?;
    } catch (e) {
      AppLogger.error('Failed to load Google Drive picker token', error: e);
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            if (uri.scheme != 'https') return NavigationDecision.prevent;
            final host = uri.host.toLowerCase();
            final allowed = _allowedHosts.any(
              (h) => host == h || host.endsWith('.$h'),
            );
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) async {
            setState(() => _isLoading = false);
            await _injectPickerToken();
          },
          onWebResourceError: (error) {
            AppLogger.warning('WebView error: ${error.description}');
            setState(() => _isLoading = false);
          },
        ),
      )
      ..addJavaScriptChannel(
        'FilePicker',
        onMessageReceived: (JavaScriptMessage message) {
          _handlePickerMessage(message.message);
        },
      )
      ..loadHtmlString(_buildPickerShellHtml());
  }

  @override
  void dispose() {
    _clearPickerToken();
    super.dispose();
  }

  Future<void> _clearPickerToken() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(
        'window.__pickerToken = null; window.__pickerClientId = null;',
      );
    } catch (e) {
      AppLogger.debug('Failed to clear picker token', error: e);
    }
  }

  Future<void> _injectPickerToken() async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    final controller = _controller;
    if (controller == null) return;

    final viewType = widget.fileType == 'video'
        ? 'google.picker.ViewId.VIDEOS'
        : 'google.picker.ViewId.DOCS';

    final tokenJson = jsonEncode(_accessToken);
    final clientJson = jsonEncode(_clientId ?? '');

    await controller.runJavaScript('''
      window.__pickerToken = $tokenJson;
      window.__pickerClientId = $clientJson;
      window.__pickerViewType = $viewType;
      if (typeof window.initSecurePicker === 'function') {
        window.initSecurePicker();
      }
    ''');
  }

  void _handlePickerMessage(String raw) {
    final parts = raw.split('|');
    if (parts.length != 3) {
      AppLogger.warning('Invalid picker message format');
      return;
    }

    final fileId = parts[0].trim();
    final fileName = parts[1].trim();
    final mimeType = parts[2].trim();

    if (fileId.isEmpty || fileId.length > 128) return;
    if (fileName.isEmpty || fileName.length > 512) return;
    if (mimeType.length > 128) return;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(fileId)) return;

    widget.onFileSelected(fileId, fileName, mimeType);
    _clearPickerToken();
    if (mounted) Navigator.pop(context);
  }

  String _buildPickerShellHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy"
        content="default-src 'self' https://apis.google.com https://www.gstatic.com https://ssl.gstatic.com; script-src https://apis.google.com; style-src 'unsafe-inline';">
  <script src="https://apis.google.com/js/api.js"></script>
  <style>
    body { margin: 0; padding: 20px; font-family: Arial, sans-serif; background: #f5f5f5; text-align: center; }
    #status { margin-top: 20px; color: #666; }
  </style>
</head>
<body>
  <h2>Google Drive File Picker</h2>
  <div id="status">Initializing secure picker...</div>
  <script>
    let pickerApiLoaded = false;

    function onApiLoad() {
      gapi.load('picker', { callback: onPickerApiLoad });
    }

    function onPickerApiLoad() {
      pickerApiLoaded = true;
      if (window.__pickerToken) initSecurePicker();
    }

    function initSecurePicker() {
      if (!pickerApiLoaded) return;
      const token = window.__pickerToken;
      if (!token) {
        document.getElementById('status').innerHTML = 'Error: token not available';
        return;
      }
      const viewType = window.__pickerViewType || google.picker.ViewId.DOCS;
      const picker = new google.picker.PickerBuilder()
        .addView(viewType)
        .setOAuthToken(token)
        .setCallback(pickerCallback)
        .build();
      picker.setVisible(true);
      document.getElementById('status').innerHTML = '';
      window.__pickerToken = null;
    }
    window.initSecurePicker = initSecurePicker;

    function pickerCallback(data) {
      if (data.action === google.picker.Action.PICKED) {
        const file = data.docs[0];
        FilePicker.postMessage(file.id + '|' + file.name + '|' + (file.mimeType || ''));
      }
    }

    window.onload = onApiLoad;
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileType != null
              ? 'Select ${widget.fileType == 'audio' ? 'Audio' : 'Video'} File'
              : 'Select File from Google Drive',
        ),
      ),
      body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_isLoading && _controller != null)
            const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
