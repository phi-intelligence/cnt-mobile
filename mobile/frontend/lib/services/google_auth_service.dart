import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api_service.dart';

class GoogleAuthService {
  final ApiService _apiService = ApiService();
  
  // Get client ID from multiple sources (priority order):
  // 1. Environment variable (--dart-define)
  // 2. Backend API
  // 3. Meta tag in index.html (for web)
  static String? _getClientIdFromEnv() {
    const envClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (envClientId.isNotEmpty) {
      return envClientId;
    }
    return null;
  }

  // Lazy initialization of GoogleSignIn
  GoogleSignIn? _googleSignInInstance;
  String? _cachedClientId;
  bool _isInitializing = false;
  
  // Singleton instance
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();
  
  Future<GoogleSignIn> _getGoogleSignIn() async {
    if (_googleSignInInstance != null) {
      return _googleSignInInstance!;
    }
    
    if (_isInitializing) {
      // Wait a bit if already initializing
      await Future.delayed(const Duration(milliseconds: 100));
      if (_googleSignInInstance != null) {
        return _googleSignInInstance!;
      }
    }
    
    _isInitializing = true;
    
    try {
      String? clientId = _getClientIdFromEnv();
      
      // If not in environment, try to fetch from backend
      if (clientId == null || clientId.isEmpty) {
        try {
          clientId = await _apiService.getGoogleClientId();
          _cachedClientId = clientId;
        } catch (e) {
          print('⚠️  Could not fetch Google Client ID from backend: $e');
        }
      }
      
      // Initialize GoogleSignIn with clientId if available
      if (clientId != null && clientId.isNotEmpty) {
        _googleSignInInstance = GoogleSignIn(
          scopes: ['email', 'profile'],
          clientId: clientId,
        );
        print('✅ Google Sign-In initialized with Client ID from ${_getClientIdFromEnv() != null ? 'environment' : 'backend'}');
      } else {
        // Fallback: will try to read from meta tag on web
        _googleSignInInstance = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        print('⚠️  Google Sign-In initialized without Client ID. Make sure it\'s set in index.html meta tag or backend config.');
      }
    } finally {
      _isInitializing = false;
    }
    
    return _googleSignInInstance!;
  }
  
  /// Sign in with Google and return ID token
  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = await _getGoogleSignIn();
      
      // Check if client ID is configured
      if (clientId == null || clientId!.isEmpty) {
        throw Exception(
          'Google Client ID not configured. Please:\n'
          '1. Add GOOGLE_CLIENT_ID to backend .env file, OR\n'
          '2. Pass --dart-define=GOOGLE_CLIENT_ID=your-client-id, OR\n'
          '3. Set it in web/index.html meta tag.\n'
          'See GOOGLE_SIGNIN_SETUP.md for details.'
        );
      }
      
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      
      if (account == null) {
        // User cancelled the sign-in
        return null;
      }
      
      // Get authentication details
      final GoogleSignInAuthentication auth = await account.authentication;
      
      if (auth.idToken == null) {
        throw Exception('Failed to get ID token from Google. Please check your OAuth configuration.');
      }
      
      // Return ID token
      return auth.idToken;
    } catch (e) {
      final errorMessage = e.toString();
      print('❌ Error signing in with Google: $errorMessage');
      
      // Provide helpful error messages
      if (errorMessage.contains('invalid_client') || errorMessage.contains('OAuth client was not found')) {
        throw Exception(
          'Google OAuth Client ID is invalid or not found.\n\n'
          'Please:\n'
          '1. Create a Google OAuth Client ID in Google Cloud Console\n'
          '2. Configure it in backend .env: GOOGLE_CLIENT_ID=your-client-id\n'
          '3. Make sure Authorized JavaScript origins include: http://localhost:8080\n'
          'See GOOGLE_SIGNIN_SETUP.md for complete setup instructions.'
        );
      }
      
      if (errorMessage.contains('popup_closed')) {
        // User cancelled - return null instead of throwing
        return null;
      }
      
      rethrow;
    }
  }
  
  /// Sign out from Google
  Future<void> signOut() async {
    final googleSignIn = await _getGoogleSignIn();
    await googleSignIn.signOut();
  }
  
  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    final googleSignIn = await _getGoogleSignIn();
    return await googleSignIn.isSignedIn();
  }
  
  /// Get current Google account
  Future<GoogleSignInAccount?> getCurrentAccount() async {
    final googleSignIn = await _getGoogleSignIn();
    return await googleSignIn.currentUser;
  }
  
  /// Get the configured Google Client ID
  String? get clientId => _cachedClientId ?? _getClientIdFromEnv();
}

