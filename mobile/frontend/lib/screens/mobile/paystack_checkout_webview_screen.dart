import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_colors.dart';
import '../../utils/app_logger.dart';

/// In-app Paystack checkout. Intercepts callback paths and returns
/// the payment `reference` (or `trxref`) to the caller.
class PaystackCheckoutWebViewScreen extends StatefulWidget {
  final String authorizationUrl;

  /// Path fragment that marks a successful return URL
  /// (e.g. `/subscription/callback` or `/donation/callback`).
  final String callbackPathContains;

  const PaystackCheckoutWebViewScreen({
    super.key,
    required this.authorizationUrl,
    this.callbackPathContains = '/subscription/callback',
  });

  @override
  State<PaystackCheckoutWebViewScreen> createState() =>
      _PaystackCheckoutWebViewScreenState();
}

class _PaystackCheckoutWebViewScreenState
    extends State<PaystackCheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _handledCallback = false;

  static const _paystackHosts = {
    'checkout.paystack.com',
    'paystack.com',
    'www.paystack.com',
    'standard.paystack.co',
    'api.paystack.co',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            if (_isCallbackUrl(uri)) {
              _completeWithReference(uri);
              return NavigationDecision.prevent;
            }

            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }

            // Allow http/https for Paystack + configured callback hosts.
            if (uri.scheme != 'https' && uri.scheme != 'http') {
              return NavigationDecision.prevent;
            }

            final host = uri.host.toLowerCase();
            final allowed = _paystackHosts.any(
              (h) => host == h || host.endsWith('.$h'),
            );
            // Also allow navigating toward callback hosts (localhost / ngrok / app).
            if (allowed || host.isNotEmpty) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null && _isCallbackUrl(uri)) {
              _completeWithReference(uri);
              return;
            }
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null && _isCallbackUrl(uri)) {
              _completeWithReference(uri);
              return;
            }
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            AppLogger.warning('Paystack WebView error: ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  bool _isCallbackUrl(Uri uri) {
    return uri.path.contains(widget.callbackPathContains) ||
        uri.path.contains('/donation/callback') ||
        uri.path.contains('/subscription/callback');
  }

  void _completeWithReference(Uri uri) {
    if (_handledCallback || !mounted) return;
    _handledCallback = true;

    final reference =
        uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
    AppLogger.debug('Paystack callback intercepted');
    Navigator.of(context).pop(reference);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Complete payment'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            ),
        ],
      ),
    );
  }
}
