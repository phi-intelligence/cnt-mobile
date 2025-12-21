import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  
  Map<String, dynamic>? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _user?['is_admin'] == true;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  AuthProvider() {
    // Set up the session expired callback for API service
    ApiService.onSessionExpired = _handleSessionExpired;
    // Start auth check in background - don't block UI
    checkAuthStatus();
  }
  
  /// Called when API service detects an expired session (401 after refresh attempt fails)
  void _handleSessionExpired() {
    print('🔒 Session expired - logging out user');
    // Clear local state without making network calls
    _user = null;
    _isAuthenticated = false;
    _error = 'Session expired. Please log in again.';
    // Clear stored credentials
    _authService.logout();
    notifyListeners();
  }
  
  Future<void> checkAuthStatus() async {
    // Don't set loading to true initially - show login screen immediately
    // Only check auth in background
    
    try {
      // Quick check - if no token exists, immediately show login screen
      final token = await _authService.getToken()
          .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
      
      if (token == null || token.isEmpty) {
        // No token - user not authenticated
        _user = null;
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Token exists - get user data (non-blocking)
      _isLoading = true;
      notifyListeners();
      
      final authenticated = await _authService.isAuthenticated()
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      if (authenticated) {
        _user = await _authService.getUser()
            .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
        _isAuthenticated = _user != null;
      } else {
        _user = null;
        _isAuthenticated = false;
      }
      _error = null;
    } catch (e) {
      print('Auth check error: $e');
      _error = 'Failed to check auth status: $e';
      _isAuthenticated = false;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await _authService.login(usernameOrEmail, password);
      _user = {
        'id': data['user_id'],
        'username': data['username'],
        'email': data['email'],
        'name': data['name'],
        'is_admin': data['is_admin'],
      };
      _isAuthenticated = true;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
      _error = null;
    } catch (e) {
      _error = 'Logout error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, String>> getAuthHeaders() async {
    return await _authService.getAuthHeaders();
  }
  
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _authService.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
        dateOfBirth: dateOfBirth,
        bio: bio,
      );
      _user = {
        'id': data['user_id'],
        'username': data['username'],
        'email': data['email'],
        'name': data['name'],
        'is_admin': data['is_admin'],
      };
      _isAuthenticated = true;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerWithOTP({
    required String email,
    required String otpCode,
    required String password,
    required String name,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _authService.registerWithOTP(
        email: email,
        otpCode: otpCode,
        password: password,
        name: name,
        phone: phone,
        dateOfBirth: dateOfBirth,
        bio: bio,
      );
      _user = {
        'id': data['user_id'],
        'username': data['username'],
        'email': data['email'],
        'name': data['name'],
        'is_admin': data['is_admin'],
      };
      _isAuthenticated = true;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> googleLogin() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get Google ID token
      final idToken = await _googleAuthService.signInWithGoogle();
      
      if (idToken == null) {
        _error = 'Google sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Send to backend
      final data = await _authService.googleLogin(idToken);
      _user = {
        'id': data['user_id'],
        'username': data['username'],
        'email': data['email'],
        'name': data['name'],
        'is_admin': data['is_admin'],
      };
      _isAuthenticated = true;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      return await _authService.checkUsername(username);
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  Future<void> updateCachedUser(Map<String, dynamic> updates) async {
    Map<String, dynamic>? baseUser = _user;
    if (baseUser == null) {
      baseUser = await _authService.getUser();
    }

    _user = {
      ...?baseUser,
      ...updates,
    };

    await _authService.updateStoredUser(_user!);
    notifyListeners();
  }
}

