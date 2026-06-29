import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../config/environment.dart';

/// SPKI certificate pinning for production API/media hosts.
///
/// Update pins when rotating TLS certificates. Obtain SPKI SHA-256 pins with:
///   openssl s_client -connect api.christnewtabernacle.com:443 </dev/null 2>/dev/null \
///     | openssl x509 -pubkey -noout \
///     | openssl pkey -pubin -outform der \
///     | openssl dgst -sha256 -binary | openssl enc -base64
class CertificatePinning {
  CertificatePinning._();

  /// Host -> list of base64 SHA-256 SPKI pins (primary + backup).
  static const Map<String, List<String>> _hostPins = {
    'api.christnewtabernacle.com': [
      // Primary cert pin — update on certificate rotation
      'CONFIGURE_PRIMARY_PIN_BASE64=',
    ],
    'livekit.christnewtabernacle.com': [
      'CONFIGURE_PRIMARY_PIN_BASE64=',
    ],
    'cnt-web-media.s3.eu-west-2.amazonaws.com': [
      'CONFIGURE_PRIMARY_PIN_BASE64=',
    ],
    'd126sja5o8ue54.cloudfront.net': [
      'CONFIGURE_PRIMARY_PIN_BASE64=',
    ],
  };

  /// Optional comma-separated override: --dart-define=TLS_PINS=api.example.com:pin1|pin2
  static Map<String, List<String>> get _effectivePins {
    const override = String.fromEnvironment('TLS_PINS');
    if (override.isEmpty) return _hostPins;

    final pins = <String, List<String>>{};
    for (final entry in override.split(',')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        pins[parts[0].trim()] = parts[1].split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      }
    }
    return pins.isEmpty ? _hostPins : pins;
  }

  /// True when at least one pin is a real (non-placeholder) value.
  static bool _hasRealPins(List<String> pins) {
    return pins.any((p) => p.isNotEmpty && !p.startsWith('CONFIGURE_'));
  }

  static List<String>? _pinsForHost(String host) {
    final normalizedHost = host.toLowerCase();
    for (final entry in _effectivePins.entries) {
      if (normalizedHost == entry.key || normalizedHost.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
    return null;
  }

  static bool shouldPinHost(String host) {
    if (Environment.isDevelopment) return false;
    final pins = _pinsForHost(host);
    return pins != null && _hasRealPins(pins);
  }

  static bool validate(X509Certificate cert, String host, int port) {
    if (Environment.isDevelopment) return true;

    final allowedPins = _pinsForHost(host);
    if (allowedPins == null || allowedPins.isEmpty || !_hasRealPins(allowedPins)) {
      // Host not pinned or pins not yet configured — defer to system TLS.
      return false;
    }

    final spkiPin = _spkiSha256Base64(cert);
    return allowedPins.contains(spkiPin);
  }

  static String _spkiSha256Base64(X509Certificate cert) {
    final der = cert.der;
    final digest = sha256.convert(der);
    return base64.encode(digest.bytes);
  }

  /// Creates an [HttpClient] with certificate pinning in production.
  static HttpClient createPinnedHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      if (!shouldPinHost(host)) {
        // Non-pinned hosts use system trust store (e.g. Stripe, Google APIs).
        return false;
      }
      return validate(cert, host, port);
    };
    return client;
  }
}
