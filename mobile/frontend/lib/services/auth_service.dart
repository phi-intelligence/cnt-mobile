import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../utils/api_error_utils.dart';
import '../utils/app_logger.dart';
import '../utils/pinned_http_client.dart';

class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  static bool _isRefreshing = false;
  static Future<String?>? _refreshFuture;

  static http.Client get _http => PinnedHttpClient.instance;

  static String get baseUrl => Environment.apiBaseUrl;

  Future<Map<String, dynamic>> login(String usernameOrEmail, String password) async {
    try {
      AppLogger.debug('Attempting login');

      final response = await _http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username_or_email': usernameOrEmail,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your network connection.');
        },
      );

      AppLogger.debug('Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistAuthData(data);
        return data;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      } catch (_) {
        throw Exception('Login failed');
      }
    } catch (e) {
      AppLogger.error('Login failed', error: e);
      if (e.toString().contains('timeout')) rethrow;
      throw Exception(ApiErrorUtils.sanitizeForUser(e, fallback: 'Login failed'));
    }
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<Map<String, dynamic>?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> isAdmin() async {
    final user = await getUser();
    return user?['is_admin'] == true;
  }

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> refreshAccessToken() async {
    if (_isRefreshing) {
      return _refreshFuture;
    }

    _isRefreshing = true;
    _refreshFuture = _doRefreshToken();

    try {
      return await _refreshFuture;
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
    }
  }

  Future<String?> _doRefreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }

      final response = await _http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String;
        await _storage.write(key: _tokenKey, value: newAccessToken);

        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }

        if (data['user_id'] != null) {
          await _persistUserProfile(data);
        }

        return newAccessToken;
      }

      AppLogger.warning('Token refresh failed with status ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Token refresh exception', error: e);
      return null;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        await _http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      AppLogger.warning('Failed to revoke refresh token on server', error: e);
    }

    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          if (phone != null) 'phone': phone,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
          if (bio != null) 'bio': bio,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistAuthData(data);
        return data;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      } catch (_) {
        throw Exception('Registration failed');
      }
    } catch (e) {
      AppLogger.error('Registration failed', error: e);
      throw Exception(ApiErrorUtils.sanitizeForUser(e, fallback: 'Registration failed'));
    }
  }

  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistAuthData(data);
        return data;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Google login failed');
      } catch (_) {
        throw Exception('Google login failed');
      }
    } catch (e) {
      AppLogger.error('Google login failed', error: e);
      throw Exception(ApiErrorUtils.sanitizeForUser(e, fallback: 'Google login failed'));
    }
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/check-username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to check username availability');
    } catch (e) {
      AppLogger.error('Username check failed', error: e);
      throw Exception(ApiErrorUtils.sanitizeForUser(e));
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  Future<void> updateStoredUser(Map<String, dynamic> updates) async {
    final current = await getUser() ?? {};
    final merged = {...current, ...updates};
    await _storage.write(key: _userKey, value: jsonEncode(merged));
  }

  Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to send verification code');
      } catch (_) {
        throw Exception('Failed to send verification code');
      }
    } catch (e) {
      AppLogger.error('Send OTP failed', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String email, String otpCode) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp_code': otpCode}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Verification failed');
      } catch (_) {
        throw Exception('Verification failed');
      }
    } catch (e) {
      AppLogger.error('Verify OTP failed', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerWithOTP({
    required String email,
    required String otpCode,
    required String password,
    required String name,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/register-with-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp_code': otpCode,
          'password': password,
          'name': name,
          if (phone != null) 'phone': phone,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
          if (bio != null) 'bio': bio,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistAuthData(data);
        return data;
      }

      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      } catch (_) {
        throw Exception('Registration failed');
      }
    } catch (e) {
      AppLogger.error('Register with OTP failed', error: e);
      throw Exception(ApiErrorUtils.sanitizeForUser(e, fallback: 'Registration failed'));
    }
  }

  Future<void> _persistAuthData(Map<String, dynamic> data) async {
    await _storage.write(key: _tokenKey, value: data['access_token']);
    if (data['refresh_token'] != null) {
      await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
    }
    await _persistUserProfile(data);
  }

  Future<void> _persistUserProfile(Map<String, dynamic> data) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': data['user_id'],
        'username': data['username'],
        'email': data['email'],
        'name': data['name'],
        'is_admin': data['is_admin'],
        'avatar': data['avatar'],
      }),
    );
  }
}
