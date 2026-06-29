import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';
import '../utils/app_logger.dart';

/// Google Sign-In for CNT Media.
///
/// Android requires:
/// 1. SHA-1 + SHA-256 of your signing key in Firebase Console
/// 2. A downloaded [google-services.json] with non-empty `oauth_client`
/// 3. [serverClientId] set to the **Web** OAuth client ID (not `clientId`)
class GoogleAuthService {
  final ApiService _apiService = ApiService();

  static String? _getClientIdFromEnv() {
    const envClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (envClientId.isNotEmpty) return envClientId;
    return null;
  }

  GoogleSignIn? _googleSignInInstance;
  String? _cachedWebClientId;
  bool _isInitializing = false;

  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  Future<GoogleSignIn> _getGoogleSignIn() async {
    if (_googleSignInInstance != null) return _googleSignInInstance!;

    if (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_googleSignInInstance != null) return _googleSignInInstance!;
    }

    _isInitializing = true;

    try {
      String? webClientId = _getClientIdFromEnv();

      if (webClientId == null || webClientId.isEmpty) {
        try {
          webClientId = await _apiService.getGoogleClientId();
          _cachedWebClientId = webClientId;
        } catch (e) {
          AppLogger.warning('Could not fetch Google Client ID from backend', error: e);
        }
      } else {
        _cachedWebClientId = webClientId;
      }

      _googleSignInInstance = _createGoogleSignIn(webClientId);
      AppLogger.debug(
        'Google Sign-In initialized (${kIsWeb ? 'web' : Platform.operatingSystem})',
      );
    } finally {
      _isInitializing = false;
    }

    return _googleSignInInstance!;
  }

  GoogleSignIn _createGoogleSignIn(String? webClientId) {
    const scopes = ['email', 'profile'];

    if (kIsWeb) {
      return GoogleSignIn(
        scopes: scopes,
        clientId: webClientId,
      );
    }

    if (Platform.isIOS) {
      // iOS uses the iOS OAuth client ID (often same as web or dedicated iOS client).
      return GoogleSignIn(
        scopes: scopes,
        clientId: webClientId,
      );
    }

    // Android: NEVER pass web client ID as `clientId` — that causes ApiException 10.
    // Android OAuth client comes from google-services.json (requires SHA fingerprints in Firebase).
    // `serverClientId` is the Web client ID, required to obtain an id_token for the backend.
    return GoogleSignIn(
      scopes: scopes,
      serverClientId: webClientId,
    );
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = await _getGoogleSignIn();

      final configuredId = _cachedWebClientId ?? _getClientIdFromEnv();
      if (!kIsWeb && Platform.isAndroid && (configuredId == null || configuredId.isEmpty)) {
        throw Exception(_androidConfigErrorMessage());
      }

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.idToken == null) {
        throw Exception(
          'Failed to get ID token from Google. '
          'Ensure serverClientId is set to your Web OAuth client ID.',
        );
      }

      return auth.idToken;
    } catch (e) {
      final errorMessage = e.toString();
      AppLogger.warning('Google sign-in failed', error: e);

      if (errorMessage.contains('ApiException: 10') ||
          errorMessage.contains('sign_in_failed') && errorMessage.contains(': 10')) {
        throw Exception(_developerErrorMessage());
      }

      if (errorMessage.contains('invalid_client') ||
          errorMessage.contains('OAuth client was not found')) {
        throw Exception(_developerErrorMessage());
      }

      if (errorMessage.contains('popup_closed')) return null;

      rethrow;
    }
  }

  String _developerErrorMessage() => '''
Google Sign-In configuration error (ApiException 10 / DEVELOPER_ERROR).

On Android this almost always means:
1. SHA-1 and SHA-256 of your app signing key are NOT registered in Firebase Console
2. google-services.json has an empty oauth_client array (re-download after adding fingerprints)
3. A Web OAuth client ID was incorrectly used as Android clientId (fixed in app code)

Fix in Firebase Console (project: cnt-media-platform):
1. Project Settings → Your apps → Android (com.christtabernacle.cntmedia)
2. Add SHA-1 and SHA-256 for your debug AND release signing keys
3. Download a new google-services.json and replace android/app/google-services.json
4. Confirm oauth_client is NOT empty in the new file

Debug keystore SHA-1 (local dev):
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

Backend must expose the **Web application** OAuth client ID at /auth/google-client-id.
See dev_docs/GOOGLE_SIGNIN_SETUP.md for full steps.
''';

  String _androidConfigErrorMessage() => '''
Google Web Client ID is not configured.

Set GOOGLE_CLIENT_ID in backend .env (Web OAuth client from Google Cloud Console),
or pass --dart-define=GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
''';

  Future<void> signOut() async {
    final googleSignIn = await _getGoogleSignIn();
    await googleSignIn.signOut();
  }

  Future<bool> isSignedIn() async {
    final googleSignIn = await _getGoogleSignIn();
    return googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> getCurrentAccount() async {
    final googleSignIn = await _getGoogleSignIn();
    return googleSignIn.currentUser;
  }

  String? get clientId => _cachedWebClientId ?? _getClientIdFromEnv();
  String? get webClientId => clientId;
}
