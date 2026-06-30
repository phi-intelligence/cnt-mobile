import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    // TODO(security): Replace with real SPKI pin for api.christnewtabernacle.com
    // before enabling production pinning (see openssl command in class doc).
    'api.christnewtabernacle.com': [
      'CONFIGURE_PRIMARY_PIN_BASE64=',
    ],
    // TODO(security): Replace with real SPKI pin for LiveKit host.
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

  /// Pinning gate: active in production when real pins exist for the host.
  static bool shouldPinHost(String host) {
    if (Environment.isDevelopment) return false;
    final pins = _pinsForHost(host);
    return pins != null && _hasRealPins(pins);
  }

  static bool validate(X509Certificate cert, String host, int port) {
    if (Environment.isDevelopment) return true;

    final allowedPins = _pinsForHost(host);
    if (allowedPins == null || allowedPins.isEmpty || !_hasRealPins(allowedPins)) {
      return false;
    }

    final spkiPin = _spkiSha256Base64(cert);
    if (spkiPin.isEmpty) return false;
    return allowedPins.contains(spkiPin);
  }

  static String _spkiSha256Base64(X509Certificate cert) {
    final spkiDer = _extractSpkiDer(cert.der);
    if (spkiDer == null) return '';
    final digest = sha256.convert(spkiDer);
    return base64.encode(digest.bytes);
  }

  /// Extract SubjectPublicKeyInfo DER from an X.509 certificate DER blob.
  static Uint8List? _extractSpkiDer(List<int> certDer) {
    final bytes = Uint8List.fromList(certDer);
    final tbsContent = _tbsCertificateContent(bytes);
    if (tbsContent == null) return null;

    var offset = 0;
    final fields = <Uint8List>[];
    while (offset < tbsContent.length) {
      final tlv = _readTlv(tbsContent, offset);
      if (tlv == null) break;
      fields.add(tbsContent.sublist(offset, offset + tlv.totalLength));
      offset += tlv.totalLength;
    }

    if (fields.isEmpty) return null;
    final hasExplicitVersion = fields.first[0] == 0xA0;
    final spkiIndex = hasExplicitVersion ? 6 : 5;
    if (fields.length <= spkiIndex) return null;
    return fields[spkiIndex];
  }

  static Uint8List? _tbsCertificateContent(Uint8List certDer) {
    final certificate = _readTlv(certDer, 0);
    if (certificate == null || certificate.tag != 0x30) return null;

    final tbs = _readTlv(certDer, certificate.valueOffset);
    if (tbs == null || tbs.tag != 0x30) return null;

    return certDer.sublist(tbs.valueOffset, tbs.valueOffset + tbs.valueLength);
  }

  static _Tlv? _readTlv(Uint8List data, int offset) {
    if (offset >= data.length) return null;

    final tag = data[offset];
    var pos = offset + 1;
    if (pos >= data.length) return null;

    final lengthInfo = _readDerLength(data, pos);
    final valueOffset = lengthInfo.nextOffset;
    final valueLength = lengthInfo.length;
    if (valueOffset + valueLength > data.length) return null;

    return _Tlv(
      tag: tag,
      totalLength: valueOffset + valueLength - offset,
      valueOffset: valueOffset,
      valueLength: valueLength,
    );
  }

  static _DerLength _readDerLength(Uint8List data, int offset) {
    final firstByte = data[offset];
    if (firstByte & 0x80 == 0) {
      return _DerLength(length: firstByte, nextOffset: offset + 1);
    }

    final numBytes = firstByte & 0x7F;
    var length = 0;
    var pos = offset + 1;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | data[pos++];
    }
    return _DerLength(length: length, nextOffset: pos);
  }

  /// Creates an [HttpClient] with certificate pinning in production.
  static HttpClient createPinnedHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      if (!shouldPinHost(host)) {
        return false;
      }
      return validate(cert, host, port);
    };
    return client;
  }
}

class _Tlv {
  final int tag;
  final int totalLength;
  final int valueOffset;
  final int valueLength;

  const _Tlv({
    required this.tag,
    required this.totalLength,
    required this.valueOffset,
    required this.valueLength,
  });
}

class _DerLength {
  final int length;
  final int nextOffset;

  const _DerLength({required this.length, required this.nextOffset});
}
