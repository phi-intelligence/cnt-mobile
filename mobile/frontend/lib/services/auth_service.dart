import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/environment.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  
  // Flag to prevent concurrent refresh attempts
  static bool _isRefreshing = false;
  static Future<String?>? _refreshFuture;
  
  /// Get API base URL from centralized Environment configuration
  /// Production: https://api.christnewtabernacle.com/api/v1
  /// Development: http://localhost:8002/api/v1 (or 10.0.2.2 on Android emulator)
  static String get baseUrl => Environment.apiBaseUrl;
  
  /// Login with username or email and password
  Future<Map<String, dynamic>> login(String usernameOrEmail, String password) async {
    try {
      print('🔐 Attempting login to: $baseUrl/auth/login');
      print('👤 Username/Email: $usernameOrEmail');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username_or_email': usernameOrEmail,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your network connection and ensure the backend is running at $baseUrl');
        },
      );
      
      print('📡 Login response status: ${response.statusCode}');
      print('📄 Login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store access token, refresh token, and user data
        await _storage.write(key: _tokenKey, value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        await _storage.write(key: _userKey, value: jsonEncode({
          'id': data['user_id'],
          'username': data['username'],
          'email': data['email'],
          'name': data['name'],
          'is_admin': data['is_admin'],
          'avatar': data['avatar'], // Include avatar URL from backend
        }));
        
        print('✅ Token and user data stored successfully');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Login failed with status ${response.statusCode}: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Login failed');
        } catch (_) {
          throw Exception('Login failed: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('💥 Login exception: $e');
      if (e.toString().contains('timeout')) {
        throw e; // Re-throw timeout as-is
      }
      throw Exception('Login error: $e');
    }
  }
  
  /// Get stored authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
  
  /// Get stored user data
  Future<Map<String, dynamic>?> getUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }
  
  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  /// Check if user is admin
  Future<bool> isAdmin() async {
    final user = await getUser();
    return user?['is_admin'] == true;
  }
  
  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }
  
  /// Refresh access token using the refresh token
  /// Returns new access token on success, null on failure
  Future<String?> refreshAccessToken() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) {
      print('🔄 Refresh already in progress, waiting...');
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
        print('❌ No refresh token available');
        return null;
      }
      
      print('🔄 Attempting to refresh access token...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store new access token
        final newAccessToken = data['access_token'];
        await _storage.write(key: _tokenKey, value: newAccessToken);
        
        // Store new refresh token if rotated
        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        
        // Update user data if provided
        if (data['user_id'] != null) {
          await _storage.write(key: _userKey, value: jsonEncode({
            'id': data['user_id'],
            'username': data['username'],
            'email': data['email'],
            'name': data['name'],
            'is_admin': data['is_admin'],
            'avatar': data['avatar'],
          }));
        }
        
        print('✅ Access token refreshed successfully');
        return newAccessToken;
      } else {
        print('❌ Token refresh failed with status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Token refresh exception: $e');
      return null;
    }
  }
  
  /// Logout - clears all stored credentials
  Future<void> logout() async {
    // Try to revoke refresh token on server (best effort)
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      print('⚠️ Failed to revoke refresh token on server: $e');
    }
    
    // Always clear local storage
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
  
  /// Register a new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    try {
      print('📝 Attempting registration to: $baseUrl/auth/register');
      
      final response = await http.post(
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
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your network connection.');
        },
      );
      
      print('📡 Registration response status: ${response.statusCode}');
      print('📄 Registration response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store access token, refresh token, and user data
        await _storage.write(key: _tokenKey, value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        await _storage.write(key: _userKey, value: jsonEncode({
          'id': data['user_id'],
          'username': data['username'],
          'email': data['email'],
          'name': data['name'],
          'is_admin': data['is_admin'],
          'avatar': data['avatar'], // Include avatar URL from backend
        }));
        
        print('✅ Registration successful and token stored');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Registration failed with status ${response.statusCode}: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Registration failed');
        } catch (_) {
          throw Exception('Registration failed: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('💥 Registration exception: $e');
      throw Exception('Registration error: $e');
    }
  }
  
  /// Login with Google
  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      print('🔐 Attempting Google login to: $baseUrl/auth/google-login');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your network connection.');
        },
      );
      
      print('📡 Google login response status: ${response.statusCode}');
      print('📄 Google login response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store access token, refresh token, and user data (including avatar from Google)
        await _storage.write(key: _tokenKey, value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        await _storage.write(key: _userKey, value: jsonEncode({
          'id': data['user_id'],
          'username': data['username'],
          'email': data['email'],
          'name': data['name'],
          'is_admin': data['is_admin'],
          'avatar': data['avatar'], // Include avatar URL (Google profile pic uploaded to S3)
        }));
        
        print('✅ Google login successful and token stored');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Google login failed with status ${response.statusCode}: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Google login failed');
        } catch (_) {
          throw Exception('Google login failed: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('💥 Google login exception: $e');
      throw Exception('Google login error: $e');
    }
  }
  
  /// Check if username is available
  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check-username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to check username availability');
      }
    } catch (e) {
      print('💥 Username check exception: $e');
      throw Exception('Username check error: $e');
    }
  }
  
  /// Get authorization header
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      print('🔑 Auth token retrieved: ${token.substring(0, 20)}...');
      return {'Authorization': 'Bearer $token'};
    }
    print('⚠️ No auth token found');
    return {};
  }

  Future<void> updateStoredUser(Map<String, dynamic> updates) async {
    final current = await getUser() ?? {};
    final merged = {...current, ...updates};
    await _storage.write(key: _userKey, value: jsonEncode(merged));
  }

  /// Send OTP to email for verification
  Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      print('📧 Sending OTP to: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      print('📡 Send OTP response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ OTP sent successfully');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Send OTP failed: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Failed to send verification code');
        } catch (_) {
          throw Exception('Failed to send verification code');
        }
      }
    } catch (e) {
      print('💥 Send OTP exception: $e');
      rethrow;
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOTP(String email, String otpCode) async {
    try {
      print('🔐 Verifying OTP for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp_code': otpCode,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Verify OTP response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ OTP verification result: ${data['verified']}');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Verify OTP failed: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Verification failed');
        } catch (_) {
          throw Exception('Verification failed');
        }
      }
    } catch (e) {
      print('💥 Verify OTP exception: $e');
      rethrow;
    }
  }

  /// Register with OTP verification
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
      print('📝 Registering with OTP to: $baseUrl/auth/register-with-otp');

      final response = await http.post(
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
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your network connection.');
        },
      );

      print('📡 Register with OTP response status: ${response.statusCode}');
      print('📄 Register with OTP response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Store access token, refresh token, and user data
        await _storage.write(key: _tokenKey, value: data['access_token']);
        if (data['refresh_token'] != null) {
          await _storage.write(key: _refreshTokenKey, value: data['refresh_token']);
        }
        await _storage.write(key: _userKey, value: jsonEncode({
          'id': data['user_id'],
          'username': data['username'],
          'email': data['email'],
          'name': data['name'],
          'is_admin': data['is_admin'],
          'avatar': data['avatar'],
        }));

        print('✅ Registration with OTP successful and token stored');
        return data;
      } else {
        final errorBody = response.body;
        print('❌ Registration with OTP failed: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          throw Exception(error['detail'] ?? 'Registration failed');
        } catch (_) {
          throw Exception('Registration failed: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('💥 Register with OTP exception: $e');
      throw Exception('Registration error: $e');
    }
  }
}

