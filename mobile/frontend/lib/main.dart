import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'config/environment.dart';
import 'navigation/app_router.dart';
import 'services/firebase_bootstrap.dart';
import 'services/push_notification_service.dart';
import 'utils/app_logger.dart';
import 'utils/security_hardening.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Environment.initialize();

  if (!kDebugMode && !Environment.isDevelopment) {
    if (await SecurityHardening.isDeviceCompromised()) {
      SecurityHardening.blockSensitiveFeatures();
      AppLogger.warning('Device integrity check failed — payments and admin disabled');
    }
  }

  if (await FirebaseBootstrap.initialize()) {
    try {
      final pushNotificationService = PushNotificationService();
      await pushNotificationService.initialize();
      await pushNotificationService.subscribeToTopic('live_streams');
      await pushNotificationService.subscribeToTopic('announcements');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Push notifications init failed (app will continue)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  } else {
    AppLogger.warning('Firebase unavailable — push notifications disabled');
  }

  AppLogger.debug('CNT Mobile App starting (env: ${Environment.environment})');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRouter();
  }
}
