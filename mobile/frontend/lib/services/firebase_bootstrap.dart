import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../utils/app_logger.dart';

/// Central Firebase init — required for FCM and Google Sign-In on Android release builds.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        return true;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      AppLogger.debug('Firebase initialized (${DefaultFirebaseOptions.currentPlatform.projectId})');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Firebase initialization failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
