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
import '../providers/subscription_provider.dart';
import '../providers/creator_provider.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meeting/pip_meeting_overlay.dart';
import '../utils/subscription_paywall.dart';
import '../utils/creator_payout_paywall.dart';
import '../screens/mobile/subscribe_screen_mobile.dart';
import '../screens/bank_details_screen.dart';
import '../screens/user_login_screen.dart';
import 'mobile_navigation.dart';
import '../screens/splash_screen.dart';
import '../utils/app_logger.dart';

/// Mobile-only App Router
/// Web platform is handled by the separate deployed web frontend
/// Shows splash screen first, then login or main app based on auth state
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  /// Used for subscription paywall navigation from ApiService 402 handling.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool _paywallsWired = false;

  @override
  void initState() {
    super.initState();
    AppLogger.debug('✅ AppRouter initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wirePaywalls();
      _initializeWebSocket();
    });
  }

  void _initializeWebSocket() async {
    try {
      AppLogger.debug('✅ AppRouter: Initializing WebSocket...');
      await WebSocketService().connect();
      AppLogger.debug('✅ AppRouter: WebSocket connected');
    } catch (e, stackTrace) {
      AppLogger.debug(
          '❌ AppRouter: WebSocket connection failed (non-critical): $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
  }

  void _wirePaywalls() {
    if (_paywallsWired) return;
    _paywallsWired = true;

    SubscriptionPaywall.onRequired = (message) {
      final nav = AppRouter.navigatorKey.currentState;
      final ctx = AppRouter.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      nav?.push(
        MaterialPageRoute(builder: (_) => const SubscribeScreenMobile()),
      );
    };

    CreatorPayoutPaywall.onRequired = (message) {
      final nav = AppRouter.navigatorKey.currentState;
      final ctx = AppRouter.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      nav?.push(
        MaterialPageRoute(
          builder: (_) => const BankDetailsScreen(isFromCreator: true),
        ),
      );
    };
  }

  @override
  void dispose() {
    SubscriptionPaywall.clear();
    CreatorPayoutPaywall.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('✅ AppRouter: Building mobile navigation...');

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
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => CreatorProvider()),
      ],
      child: const _SessionBootstrap(
        child: _RootMaterialApp(),
      ),
    );
  }
}

/// Single [MaterialApp] instance — never recreate on provider updates.
class _RootMaterialApp extends StatelessWidget {
  const _RootMaterialApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Christ Media',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      navigatorKey: AppRouter.navigatorKey,
      home: const _AppFlow(),
    );
  }
}

/// Splash → login → main tabs, driven by auth state (no nested navigators).
class _AppFlow extends StatefulWidget {
  const _AppFlow();

  @override
  State<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<_AppFlow> {
  bool _splashComplete = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isAuthenticated) {
      return const MobileNavigationLayout();
    }

    if (!_splashComplete) {
      return SplashScreen(
        onComplete: () {
          if (mounted) {
            setState(() => _splashComplete = true);
          }
        },
      );
    }

    return const UserLoginScreen();
  }
}

class _SessionBootstrap extends StatefulWidget {
  final Widget child;

  const _SessionBootstrap({required this.child});

  @override
  State<_SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends State<_SessionBootstrap> {
  bool? _wasAuthenticated;
  AuthProvider? _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_authProvider == auth) return;

    _authProvider?.removeListener(_handleAuthChange);
    _authProvider = auth;
    _authProvider!.addListener(_handleAuthChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuthChange());
  }

  void _handleAuthChange() {
    final auth = _authProvider;
    if (auth == null) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final creatorProvider = context.read<CreatorProvider>();
    final isAuth = auth.isAuthenticated;

    if (_wasAuthenticated == isAuth) {
      if (isAuth) {
        creatorProvider.syncAuth(
          isAuthenticated: true,
          isAdmin: auth.isAdmin,
        );
      }
      return;
    }
    _wasAuthenticated = isAuth;

    if (isAuth) {
      subscriptionProvider.refreshMe();
      creatorProvider.syncAuth(
        isAuthenticated: true,
        isAdmin: auth.isAdmin,
      );
    } else {
      subscriptionProvider.clear();
      creatorProvider.clear();
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_handleAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
