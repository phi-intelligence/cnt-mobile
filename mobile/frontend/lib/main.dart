import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'config/environment.dart';
import 'navigation/app_router.dart';
import 'services/push_notification_service.dart';
import 'utils/app_logger.dart';
import 'utils/security_hardening.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Environment.initialize();

  if (!kDebugMode && await SecurityHardening.isDeviceCompromised()) {
    AppLogger.warning('Device integrity check failed');
  }

  await Firebase.initializeApp();

  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  if (stripePublishableKey.isNotEmpty && stripePublishableKey.length > 20) {
    Stripe.publishableKey = stripePublishableKey;
    AppLogger.debug('Stripe initialized');
  }

  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();
  await pushNotificationService.subscribeToTopic('live_streams');
  await pushNotificationService.subscribeToTopic('announcements');

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
