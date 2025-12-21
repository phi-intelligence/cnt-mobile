import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/music_provider.dart';
import '../providers/community_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/search_provider.dart';
import '../providers/user_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/support_provider.dart';
import '../providers/documents_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/artist_provider.dart';
import '../providers/event_provider.dart';
import '../providers/download_provider.dart';
import '../providers/draft_provider.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meeting/pip_meeting_overlay.dart';
import 'mobile_navigation.dart';
import '../screens/splash_screen.dart';

/// Mobile-only App Router
/// Web platform is handled by the separate deployed web frontend
/// Shows splash screen first, then login or main app based on auth state
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void initState() {
    super.initState();
    print('✅ AppRouter initState');
    // Initialize WebSocket connection asynchronously after first frame
    // This prevents blocking the build method and handles errors gracefully
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeWebSocket();
    });
  }

  void _initializeWebSocket() async {
    try {
      print('✅ AppRouter: Initializing WebSocket...');
      await WebSocketService().connect();
      print('✅ AppRouter: WebSocket connected');
    } catch (e, stackTrace) {
      // Log error but don't crash the app
      // WebSocket connection is non-critical for app functionality
      print('❌ AppRouter: WebSocket connection failed (non-critical): $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('✅ AppRouter: Building mobile navigation...');
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerState()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ArtistProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => PipMeetingManager()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => DraftProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Show main app if authenticated, otherwise show splash -> login flow
          if (authProvider.isAuthenticated) {
            // All users (including admins) see the normal app navigation
            // Admin dashboard is accessible from profile or navigation menu
            return MaterialApp(
              title: 'Christ Media',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light, // Force light theme only
              home: const MobileNavigationLayout(),
            );
          } else {
            // Not authenticated - show splash screen (which transitions to login)
            return MaterialApp(
              title: 'Christ Media',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light, // Force light theme only
              home: const SplashScreen(),
            );
          }
        },
      ),
    );
  }
}
