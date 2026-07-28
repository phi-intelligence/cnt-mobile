import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/app_logger.dart';

/// Persists auth tokens and session data on mobile.
///
/// Mirrors cnt-web's [WebStorageService] pattern (direct platform storage):
/// - **Android:** native SharedPreferences via MethodChannel (reliable in release)
/// - **iOS:** FlutterSecureStorage
class TokenStorageService {
  TokenStorageService._();

  static final TokenStorageService instance = TokenStorageService._();

  static const _channel = MethodChannel('com.christtabernacle.cntmedia/token_storage');

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool get _useNativeAndroid => !kIsWeb && Platform.isAndroid;

  Future<void> write({required String key, required String? value}) async {
    if (_useNativeAndroid) {
      await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
      return;
    }

    if (value == null) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<String?> read({required String key}) async {
    if (_useNativeAndroid) {
      return await _channel.invokeMethod<String>('read', {'key': key});
    }
    return _secureStorage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await write(key: key, value: null);
  }

  Future<void> clearAuthData() async {
    for (final key in ['auth_token', 'refresh_token', 'user_data']) {
      try {
        await delete(key: key);
      } catch (e) {
        AppLogger.warning('Failed to clear $key', error: e);
      }
    }
  }
}
