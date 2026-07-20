import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/environment.dart';
import 'certificate_pinning.dart';

/// Shared HTTP client with optional TLS pinning in production.
class PinnedHttpClient {
  PinnedHttpClient._();

  static http.Client? _instance;

  static http.Client get instance {
    _instance ??= _create();
    return _instance!;
  }

  static http.Client _create() {
    if (Environment.isDevelopment) {
      return http.Client();
    }
    return IOClient(CertificatePinning.createPinnedHttpClient());
  }

  static void reset() {
    _instance?.close();
    _instance = null;
  }
}
