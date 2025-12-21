import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'config/environment.dart';
import 'navigation/app_router.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment configuration from .env file
  await Environment.initialize();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Stripe
  // TODO: Set STRIPE_PUBLISHABLE_KEY in .env file
  // For now, using a placeholder that will be updated from backend
  // The actual key will be validated when creating payment intent
  const stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51placeholder', // Placeholder
  );
  if (stripePublishableKey.isNotEmpty && stripePublishableKey.length > 20) {
    Stripe.publishableKey = stripePublishableKey;
    if (kDebugMode) {
      debugPrint('   Stripe initialized');
    }
  }
  
  // Initialize push notification service
  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();
  
  // Subscribe to general topics
  await pushNotificationService.subscribeToTopic('live_streams');
  await pushNotificationService.subscribeToTopic('announcements');
  
  if (kDebugMode) {
    debugPrint('🚀 CNT Mobile App Starting...');
    debugPrint('   Environment: ${Environment.environment}');
    debugPrint('   Firebase initialized');
    debugPrint('   Push notifications enabled');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRouter();
  }
}
