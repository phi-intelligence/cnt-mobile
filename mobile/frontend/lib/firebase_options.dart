// Generated from android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
// Project: cnt-media-platform
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web in this mobile app.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not supported.');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not supported.');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not supported.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBlA8cEmBfuEEWgbE09uXZx9GYktjBbbWk',
    appId: '1:533334002124:android:79b714cde2992f6d4d7569',
    messagingSenderId: '533334002124',
    projectId: 'cnt-media-platform',
    storageBucket: 'cnt-media-platform.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAfI0MP3SCI0ejBMro8atieQRcTIVjdFrg',
    appId: '1:533334002124:ios:5caa6b1308c682cb4d7569',
    messagingSenderId: '533334002124',
    projectId: 'cnt-media-platform',
    storageBucket: 'cnt-media-platform.firebasestorage.app',
    iosBundleId: 'com.christtabernacle.cntmedia',
  );
}
