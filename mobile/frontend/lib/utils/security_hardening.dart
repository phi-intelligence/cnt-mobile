import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/environment.dart';

/// Client-side security hardening utilities.
class SecurityHardening {
  SecurityHardening._();

  static const _channel = MethodChannel('com.christtabernacle.cntmedia/security');

  /// Apply FLAG_SECURE to prevent screenshots on sensitive screens.
  static Future<void> enableScreenProtection() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('enableScreenProtection');
    } catch (_) {
      // Platform channel may not be available in tests.
    }
  }

  static Future<void> disableScreenProtection() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('disableScreenProtection');
    } catch (_) {}
  }

  /// Best-effort root/jailbreak/emulator detection. Not a sole security control.
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb || Environment.isDevelopment) return false;

    if (Platform.isAndroid) {
      final paths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
      ];
      for (final path in paths) {
        if (await File(path).exists()) return true;
      }
    }

    if (Platform.isIOS) {
      final paths = [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
      ];
      for (final path in paths) {
        if (await File(path).exists()) return true;
      }
    }

    return false;
  }
}

/// Wraps sensitive screens (payment, OTP) with screenshot protection.
class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecurityHardening.enableScreenProtection();
  }

  @override
  void dispose() {
    SecurityHardening.disableScreenProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
