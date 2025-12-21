import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Screen that opens Google Picker API in a WebView
/// This allows users to directly select files from Google Drive
class GooglePickerWebViewScreen extends StatefulWidget {
  final String? fileType; // "audio", "video"
  final Function(String fileId, String fileName, String mimeType) onFileSelected;

  const GooglePickerWebViewScreen({
    super.key,
    this.fileType,
    required this.onFileSelected,
  });

  @override
  State<GooglePickerWebViewScreen> createState() => _GooglePickerWebViewScreenState();
}

class _GooglePickerWebViewScreenState extends State<GooglePickerWebViewScreen> {
  late final WebViewController _controller;
  final ApiService _api = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final htmlContent = await _buildPickerHtml();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FilePicker',
        onMessageReceived: (JavaScriptMessage message) {
          // Handle file selection from JavaScript
          try {
            final data = message.message;
            // Parse the message (format: "fileId|fileName|mimeType")
            final parts = data.split('|');
            if (parts.length == 3) {
              widget.onFileSelected(parts[0], parts[1], parts[2]);
              Navigator.pop(context);
            }
          } catch (e) {
            print('Error parsing file selection: $e');
          }
        },
      )
      ..loadHtmlString(htmlContent);
  }

  Future<String> _buildPickerHtml() async {
    // Get OAuth token from backend
    String accessToken = '';
    String clientId = '';
    
    try {
      final tokenData = await _api.getGoogleDrivePickerToken();
      accessToken = tokenData['access_token'] as String;
      clientId = tokenData['client_id'] as String;
    } catch (e) {
      // If token not available, show error
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 40px 20px;
      font-family: Arial, sans-serif;
      text-align: center;
    }
  </style>
</head>
<body>
  <h2>Error</h2>
  <p>Failed to get Google Drive access token. Please connect to Google Drive first.</p>
</body>
</html>
      ''';
    }

    // Determine view type based on file type
    String viewType = 'google.picker.ViewId.DOCS';
    if (widget.fileType == 'audio') {
      viewType = 'google.picker.ViewId.DOCS';
    } else if (widget.fileType == 'video') {
      viewType = 'google.picker.ViewId.VIDEOS';
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://apis.google.com/js/api.js"></script>
  <style>
    body {
      margin: 0;
      padding: 20px;
      font-family: Arial, sans-serif;
      background: #f5f5f5;
    }
    #picker-container {
      text-align: center;
      padding: 40px 20px;
    }
    button {
      background: #4285f4;
      color: white;
      border: none;
      padding: 12px 24px;
      font-size: 16px;
      border-radius: 4px;
      cursor: pointer;
    }
    button:hover {
      background: #357ae8;
    }
    #status {
      margin-top: 20px;
      color: #666;
    }
  </style>
</head>
<body>
  <div id="picker-container">
    <h2>Google Drive File Picker</h2>
    <button onclick="loadPicker()">Select File from Google Drive</button>
    <div id="status"></div>
  </div>

  <script>
    let pickerApiLoaded = false;
    const oauthToken = '$accessToken';
    const clientId = '$clientId';

    function onApiLoad() {
      gapi.load('picker', {'callback': onPickerApiLoad});
    }

    function onPickerApiLoad() {
      pickerApiLoaded = true;
      // Auto-open picker when ready
      loadPicker();
    }

    function loadPicker() {
      if (!pickerApiLoaded) {
        document.getElementById('status').innerHTML = 'Loading picker...';
        setTimeout(loadPicker, 100);
        return;
      }

      if (!oauthToken) {
        document.getElementById('status').innerHTML = 'Error: No access token available';
        return;
      }

      // Create picker
      const picker = new google.picker.PickerBuilder()
        .addView(${viewType})
        .setOAuthToken(oauthToken)
        .setCallback(pickerCallback)
        .build();
      
      picker.setVisible(true);
    }

    function pickerCallback(data) {
      if (data.action === google.picker.Action.PICKED) {
        const file = data.docs[0];
        // Send file info to Flutter
        FilePicker.postMessage(file.id + '|' + file.name + '|' + (file.mimeType || ''));
      } else if (data.action === google.picker.Action.CANCEL) {
        document.getElementById('status').innerHTML = 'Selection cancelled';
        // Close after a delay
        setTimeout(() => {
          window.close();
        }, 1000);
      }
    }

    // Load the API
    window.onload = function() {
      onApiLoad();
    };
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

