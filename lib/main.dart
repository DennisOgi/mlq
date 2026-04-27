import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:my_leadership_quest/widgets/desktop_nav_rail.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase/firebase_initializer.dart';
import 'l10n/app_localizations.dart';
import 'package:my_leadership_quest/services/config_service.dart';
import 'package:my_leadership_quest/screens/admin/admin_login_screen.dart';
import 'package:my_leadership_quest/screens/admin/admin_dashboard_screen.dart';
import 'package:my_leadership_quest/screens/admin/admin_users_screen.dart';
import 'package:my_leadership_quest/screens/admin/challenge_form_screen.dart';
import 'package:my_leadership_quest/screens/admin/challenge_participants_screen.dart';
import 'package:my_leadership_quest/screens/admin/analytics_dashboard_screen.dart';
import 'package:my_leadership_quest/screens/leaderboard/leaderboard_screen.dart';
import 'package:my_leadership_quest/screens/leaderboard/hall_of_fame_screen.dart';
import 'package:my_leadership_quest/screens/challenges/challenge_detail_screen.dart';
import 'package:my_leadership_quest/screens/onboarding/onboarding_screen.dart';
import 'package:my_leadership_quest/screens/onboarding/pages/welcome_page.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'screens/ai_chat/ai_chat_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/parent_portal_screen.dart';
import 'screens/profile/achievements_screen.dart';
import 'screens/victory_wall/victory_wall_screen.dart';
import 'screens/splash/gif_splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/goals/goal_history_screen.dart';
import 'screens/challenges/challenges_screen.dart';
import 'screens/subscription/subscription_management_screen.dart';
import 'screens/challenges/premium_challenge_unlock_screen.dart';
import 'screens/b2b/class_code_join_screen.dart';
import 'screens/admin/school_onboarding_screen.dart';
import 'screens/admin/job_runs_screen.dart';
import 'screens/admin/reward_disbursement_screen.dart';
import 'screens/wallet/wallet_dashboard_screen.dart';
import 'services/background_service_manager.dart';
import 'services/badge_service.dart';
import 'services/cache_service.dart';
import 'services/supabase_service.dart';
import 'services/ai_coach_service.dart';
import 'services/ai_course_generator_service.dart';
import 'services/autonomous_coach_service.dart';
import 'services/unified_autonomous_coach.dart';
import 'services/push_notification_service.dart';
import 'package:my_leadership_quest/services/app_update_service.dart';
import 'constants/app_constants.dart';
import 'services/email_report_service.dart';
import 'models/notification_model.dart';
import 'services/challenge_evaluator.dart';
import 'theme/app_theme.dart';
import 'widgets/premium_bottom_nav_bar.dart';
import 'providers/school_course_provider.dart';
// Removed tutorial overlay system

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler for FCM
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch all uncaught async errors that would otherwise silently kill the app
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('🔴 Flutter Error: ${details.exception}');
      debugPrint('🔴 Stack trace: ${details.stack}');
    }
  };

  // Catch errors in async code not caught by FlutterError.onError
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('🔴 Platform Error: $error');
      debugPrint('🔴 Stack: $stack');
    }
    return true; // Prevent crash
  };

  // Background message handler is registered in mobile-specific code
  // Desktop platforms don't support Firebase Messaging

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (context) {
          final provider = GoalProvider();
          // Don't initialize here - let screens initialize when they're opened
          return provider;
        }),
        ChangeNotifierProvider(create: (context) {
          final provider = ChallengeProvider();
          // Don't initialize here - let screens initialize when they're opened
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (context) {
          // MiniCourseProvider now uses database-backed daily courses
          // Courses are loaded via ensureTodayDailyCourse() when needed
          return MiniCourseProvider();
        }),
        ChangeNotifierProvider(create: (_) => GratitudeProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (context) {
          final provider = OrganizationSettingsProvider();
          // Don't initialize here - let it load when needed
          return provider;
        }),
        // School Course Provider for premium school mini courses feature
        ChangeNotifierProvider(create: (_) => SchoolCourseProvider()),
        Provider<BadgeService>(
          create: (context) {
            final badgeService = BadgeService();
            // Initialize with the required providers
            badgeService.initialize(
              userProvider: Provider.of<UserProvider>(context, listen: false),
              goalProvider: Provider.of<GoalProvider>(context, listen: false),
              challengeProvider:
                  Provider.of<ChallengeProvider>(context, listen: false),
              miniCourseProvider:
                  Provider.of<MiniCourseProvider>(context, listen: false),
              gratitudeProvider:
                  Provider.of<GratitudeProvider>(context, listen: false),
            );
            return badgeService;
          },
        ),
        // Initialize ChallengeEvaluator after providers are available
        Provider<ChallengeEvaluator>(
          create: (context) {
            final evaluator = ChallengeEvaluator.instance;
            // Don't initialize here - let it initialize when needed
            return evaluator;
          },
        ),
      ],
      child: MaterialApp(
        title: 'My Leadership Quest',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.getThemeData(),
        // Localization configuration
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Add error builder to catch widget errors
        builder: (context, widget) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            if (kDebugMode) {
              debugPrint('🔴 Widget Error: ${errorDetails.exception}');
              debugPrint('🔴 Stack: ${errorDetails.stack}');
            }
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Something went wrong',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        kDebugMode ? errorDetails.exception.toString() : 'Please restart the app',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          };
          return widget!;
        },
        home: AppInitializer(
          buildApp: (context) => _buildRoutedHome(context),
        ),
        routes: {
          '/ai_chat': (context) => const AIChatScreen(),
          '/login': (context) => const LoginScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const HomeScreen(),
          '/goals': (context) => const GoalsScreen(),
          '/goal-history': (context) => const GoalHistoryScreen(),
          '/challenges': (context) => const ChallengesScreen(),
          '/victory_wall': (context) => const VictoryWallScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
          '/hall-of-fame': (context) => const HallOfFameScreen(),
          '/splash-preview': (context) => GifSplashScreen(
                gifAssetPath: 'assets/animations/MLQ-gif.gif',
                nextScreen: const ProfileScreen(),
                minDisplayTime: const Duration(seconds: 3),
              ),
          '/welcome-preview': (context) => WelcomePage(
                onNext: () {
                  Navigator.of(context).pushReplacementNamed('/onboarding');
                },
              ),
          '/profile': (context) => const ProfileScreen(),
          '/parent_portal': (context) => const ParentPortalScreen(),
          '/achievements': (context) => const AchievementsScreen(),
          '/admin-login': (context) => const AdminLoginScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/admin-users': (context) => const AdminUsersScreen(),
          '/challenge-form': (context) => const ChallengeFormScreen(),
          '/challenge-participants': (context) =>
              const ChallengeParticipantsScreen(
                  challengeId: '', challengeTitle: ''),
          '/analytics-dashboard': (context) => const AnalyticsDashboardScreen(),
          '/challenge-detail': (context) {
            final challengeId =
                ModalRoute.of(context)!.settings.arguments as String;
            return ChallengeDetailScreen(challengeId: challengeId);
          },
          '/premium-unlock': (context) {
            final challengeId =
                ModalRoute.of(context)!.settings.arguments as String;
            return PremiumChallengeUnlockScreen(challengeId: challengeId);
          },
          '/subscription-management': (context) =>
              const SubscriptionManagementScreen(),
          '/class-code': (context) => const ClassCodeJoinScreen(),
          '/admin-school-onboarding': (context) =>
              const SchoolOnboardingScreen(),
          '/admin-job-runs': (context) => const JobRunsScreen(),
          '/wallet': (context) => const WalletDashboardScreen(),
          '/admin-reward-disbursements': (context) => const RewardDisbursementScreen(),
        },
      ),
    );
  }
}

void _showChallengeCompletedDialog(
    BuildContext context, ChallengeCompletionEvent event) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF8F9FF),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.15),
                offset: const Offset(0, 10),
                blurRadius: 30,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Trophy icon with gradient background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                '🎉 Challenge Completed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Challenge name
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Coin reward with gradient
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFA1E44D).withOpacity(0.2),
                      const Color(0xFF7BC950).withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFA1E44D).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFA1E44D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '+${event.coinReward} coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D5016),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Button with gradient
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        offset: const Offset(0, 8),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildRoutedHome(BuildContext context) {
  return const _StableSplashRouter();
}

/// A wrapper that maintains a stable GifSplashScreen state across UserProvider notifications.
/// This prevents the GIF from restarting and the timer from resetting, which stops the ANR.
class _StableSplashRouter extends StatefulWidget {
  const _StableSplashRouter();

  @override
  State<_StableSplashRouter> createState() => _StableSplashRouterState();
}

class _StableSplashRouterState extends State<_StableSplashRouter> {
  @override
  Widget build(BuildContext context) {
    // We use a Selector or a limited Consumer so we only rebuild the routing logic
    // not the entire GifSplashScreen container.
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final isInitialized = userProvider.isInitialized;
        final isFirstTime = userProvider.isFirstTimeUser;
        final isAuthenticated = userProvider.isAuthenticated;

        Widget nextScreen;
        if (isFirstTime) {
          nextScreen = const OnboardingScreen();
        } else if (!isAuthenticated) {
          nextScreen = const LoginScreen();
        } else {
          nextScreen = const MainNavigationScreen();
        }

        // The key ensures the state is preserved if possible.
        // We pass isInitialized to the splash screen so it can decide when to proceed.
        return GifSplashScreen(
          key: const ValueKey('main_splash'),
          gifAssetPath: 'assets/animations/MLQ-gif.gif',
          nextScreen: nextScreen,
          minDisplayTime: const Duration(seconds: 2),
        );
      },
    );
  }
}


class AppInitializer extends StatefulWidget {
  final Widget Function(BuildContext) buildApp;
  const AppInitializer({super.key, required this.buildApp});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _ready = false;
  String? _error;
  bool _retrying = false;
  
  // Track service initialization status
  bool _servicesInitialized = false;
  final Map<String, bool> _serviceStatus = {
    'firebase': false,
    'supabase': false,
    'cache': false,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final startTime = DateTime.now();
    try {
      if (kDebugMode) debugPrint('[Startup] Initialization started');

      // IMMEDIATELY set ready to show UI - don't wait for services
      if (!mounted) return;
      setState(() => _ready = true);
      
      if (kDebugMode) debugPrint('[Startup] UI ready, initializing services in background');

      // Run critical + optional services sequentially in background to avoid
      // UserProvider reading Supabase before it is initialized.
      unawaited(_initializeAllServices());
      
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      if (kDebugMode) debugPrint('[Startup] UI shown in ${totalTime}ms, services loading in background');
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] Fatal Error: $e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Runs all service initialization sequentially so that critical services
  /// (Firebase, Supabase) are always fully ready before optional ones attempt
  /// to use them.  This prevents the UserProvider constructor from calling
  /// Supabase APIs before the client is initialized.
  static bool _globalInitStarted = false;

  Future<void> _initializeAllServices() async {
    if (_globalInitStarted) return;
    _globalInitStarted = true;

    // STAGGERED START: Give the UI thread (Splash GIF) 2s to settle and 
    // render its first loop before we slam the main thread with I/O and network.
    await Future.delayed(const Duration(milliseconds: 2000));
    
    await _initializeCriticalServices();
    await _initializeOptionalServices();
  }

  Future<void> _initializeCriticalServices() async {
    try {
      // Firebase (critical for auth)
      await _runStep(
        name: 'Firebase',
        action: () async {
          await FirebaseInitializer.initialize();
          if (mounted) setState(() => _serviceStatus['firebase'] = true);
        },
        timeout: const Duration(seconds: 10),
        required: false,
      );

      // Supabase (critical for data)
      await _runStep(
        name: 'Supabase',
        action: () async {
          await SupabaseService.instance.initialize();
          if (mounted) {
            setState(() => _serviceStatus['supabase'] = true);
            // NOW initialize UserProvider explicitly - now that Supabase is definitely ready
            try {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              await userProvider.initialize();
            } catch (e) {
              debugPrint('[Startup] UserProvider init failed: $e');
            }
          }
        },
        timeout: const Duration(seconds: 15),
        required: true,
      );

      // Cache (fast, local only)
      await _runStep(
        name: 'Cache',
        action: () async {
          await CacheService().initialize();
          if (mounted) setState(() => _serviceStatus['cache'] = true);
        },
        timeout: const Duration(seconds: 5),
        required: false,
      );

      if (mounted) {
        setState(() => _servicesInitialized = true);
      }

      if (kDebugMode) debugPrint('[Startup] Critical services ready');
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] Critical services error: $e');
      // Don't throw - allow app to continue with degraded functionality
    }
  }

  Future<void> _initializeOptionalServices() async {
    try {
      // Config service MUST be initialized before any callers (e.g. resetGeminiApiKey)
      final configService = ConfigService.instance;
      await _runStep(
        name: 'Config',
        action: () => configService.initialize(),
        timeout: const Duration(seconds: 5),
        required: false,
      );

      // Flutterwave config (payment setup)
      await _configureFlutterwave(configService);

      // AI services - only after ConfigService is ready to avoid null _prefs crash
      await _initializeAIServices(configService);

      // Background service (optional) - Deferred heavily to prevent ANR on start
      // 20s delay gives Supabase + UI time to fully settle first
      Future.delayed(const Duration(seconds: 20), () {
        if (!kIsWeb) {
          BackgroundServiceManager.initialize().catchError((e) {
            debugPrint('[BackgroundService] Deferred init failed: $e');
          });
        }
      });

      // Notifications (can fail on emulator - always wrapped)
      await _runStep(
        name: 'Notifications',
        action: () => PushNotificationService.instance.initialize(
          onMessageOpenedApp: _handleNotificationTap,
        ),
        timeout: const Duration(seconds: 5),
        required: false,
      );

      if (kDebugMode) debugPrint('[Startup] Background initialization complete');
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup][Background] Error: $e');
      // Don't crash - optional services
    }
  }

  Future<void> _configureFlutterwave(ConfigService config) async {
    try {
      // Use production key in release mode
      final isProduction = kReleaseMode;
      final publicKey = isProduction
          ? 'FLWPUBK-PRODUCTION-KEY-HERE'  // Replace with your production key
          : 'FLWPUBK_TEST-4f83c90e73b19c538cf08565813d7b32-X';
      
      await config.setFlutterwavePublicKey(publicKey);
      await config.setFlutterwaveIsTestMode(!isProduction);
      await config.setFlutterwaveRedirectUrl('https://mlq.app/redirect');
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] Flutterwave config failed: $e');
    }
  }

  Future<void> _initializeAIServices(ConfigService config) async {
    try {
      await config.resetGeminiApiKey();
      final apiKey = await config.getGeminiApiKey();
      
      if (apiKey.isEmpty) {
        if (kDebugMode) debugPrint('[Startup] No API key - AI disabled');
        return;
      }

      // Initialize AI services (synchronous, fast)
      AiCoachService.instance.initialize(apiKey);
      AiCourseGeneratorService.instance.initialize(apiKey);
      AutonomousCoachService.instance.initialize();
      UnifiedAutonomousCoach.instance.initialize();
      
      if (kDebugMode) debugPrint('[Startup] AI services ready');
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup] AI init failed: $e');
    }
  }

  Future<void> _runStep({
    required String name,
    required Future<void> Function() action,
    required Duration timeout,
    required bool required,
  }) async {
    final stepStart = DateTime.now();
    try {
      await action().timeout(timeout);
      final duration = DateTime.now().difference(stepStart).inMilliseconds;
      if (kDebugMode) debugPrint('[Startup]   ✓ $name (${duration}ms)');
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Startup]   ⚠️ $name timed out after ${timeout.inSeconds}s');
      if (required) rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[Startup]   ❌ $name failed: $e');
      if (required) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state with retry
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connection Issue',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your internet connection',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retrying ? null : () {
                    setState(() {
                      _error = null;
                      _retrying = true;
                    });
                    _initialize().then((_) {
                      if (mounted) {
                        setState(() => _retrying = false);
                      }
                    });
                  },
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_retrying ? 'Retrying...' : 'Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Continue offline (if supported)
                    setState(() {
                      _error = null;
                      _ready = true;
                      _servicesInitialized = true; // Allow offline mode
                    });
                  },
                  child: const Text('Continue Offline'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state (shown briefly for 1 frame before _ready=true)
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Ready - show app (services may still be loading in background)
    return widget.buildApp(context);
  }
}

extension _WeeklyReportSender on _MainNavigationScreenState {
  Future<void> _maybeSendWeeklyReport() async {
    try {
      final due = await EmailReportService.shouldSendWeeklyReport();
      if (!due) return;

      final user = await SupabaseService.instance.fetchCurrentUser();
      if (user == null) return;

      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      await EmailReportService.generateAndSendWeeklyReport(user, goalProvider);
    } catch (e) {
      debugPrint('Weekly report trigger error: $e');
    }
  }
}

void _handleNotificationTap(dynamic message) {
  try {
    // On mobile, message is RemoteMessage with .data property
    // On desktop, message is null (notifications not supported)
    if (message == null) return;

    final data = message.data as Map<String, dynamic>? ?? {};
    final type = (data['type'] ?? '').toString();

    switch (type) {
      case 'challenge':
        navigatorKey.currentState?.pushNamed('/challenges');
        break;
      case 'leaderboard':
        navigatorKey.currentState?.pushNamed('/leaderboard');
        break;
      case 'goal':
        navigatorKey.currentState?.pushNamed('/goals');
        break;
      case 'system':
      default:
        navigatorKey.currentState?.pushNamed('/home');
        break;
    }
  } catch (e) {
    // Fails silently; navigation is best-effort.
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _inAppNotifSub;
  StreamSubscription<ChallengeCompletionEvent>? _challengeCompletionSub;

  // Removed tutorial keys

  static const List<Widget> _screens = [
    HomeScreen(),
    GoalsScreen(),
    ChallengesScreen(),
    VictoryWallScreen(),
    LeaderboardScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // When navigating to Goals tab, suggest balanced goals if user is over-focusing a category
    if (index == 1) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeSuggestBalancedGoals());
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Delay ALL initialization until UI is stable (2 seconds after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for UI to fully render and stabilize
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      // Now initialize providers in the background
      _initializeProvidersAsync();
      
      // Listen for in-app notifications and show a toast/snackbar
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      // Ensure provider is initialized once
      provider.initialize();
      _inAppNotifSub = provider.inAppNotifications.listen((notification) {
        provider.showNotificationInUI(context, notification);
        _maybeShowMonthlyWinnerCelebration(notification);
      });

      // Check for app updates from Play Store
      _checkForAppUpdate();

      // Trigger weekly parent email report if due (server enforces cadence & logging)
      _maybeSendWeeklyReport();

      // Listen for challenge completion events to show a popup
      final evaluator = Provider.of<ChallengeEvaluator>(context, listen: false);
      _challengeCompletionSub = evaluator.completionStream.listen((event) {
        // Lightweight banner first
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Completed: ${event.title}  (+${event.coinReward} coins)')),
              ],
            ),
            backgroundColor: const Color(0xFF00C4FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        // Celebration dialog
        _showChallengeCompletedDialog(context, event);
      });
    });
  }
  
  // Initialize providers asynchronously in the background
  void _initializeProvidersAsync() {
    try {
      if (!mounted) return;
      
      // Get providers
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
      final orgSettingsProvider = Provider.of<OrganizationSettingsProvider>(context, listen: false);
      final evaluator = Provider.of<ChallengeEvaluator>(context, listen: false);
      final gratitudeProvider = Provider.of<GratitudeProvider>(context, listen: false);
      final miniCourseProvider = Provider.of<MiniCourseProvider>(context, listen: false);
      
      // Initialize providers without blocking (fire and forget)
      Future.microtask(() async {
        try {
          // Initialize GoalProvider
          goalProvider.setUserProvider(userProvider);
          await goalProvider.initGoals();
          
          // Initialize ChallengeProvider
          await challengeProvider.initChallenges();
          
          // Initialize OrganizationSettingsProvider
          await orgSettingsProvider.loadSettings();
          
          // Initialize ChallengeEvaluator
          evaluator.initialize(
            userProvider: userProvider,
            goalProvider: goalProvider,
            gratitudeProvider: gratitudeProvider,
            miniCourseProvider: miniCourseProvider,
            challengeProvider: challengeProvider,
          );
          
          if (kDebugMode) debugPrint('[MainNav] Providers initialized successfully');
        } catch (e) {
          if (kDebugMode) debugPrint('[MainNav] Provider initialization error: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[MainNav] Provider initialization setup error: $e');
    }
  }

  Future<void> _maybeShowMonthlyWinnerCelebration(
      NotificationModel notification) async {
    try {
      if (!mounted) return;
      if (notification.type != NotificationType.leaderboard) return;

      final related = notification.relatedId;
      if (related == null || related.isEmpty) return;
      if (!related.startsWith('monthly_winner:')) return;

      final parts = related.split(':');
      if (parts.length < 3) return;
      final monthKey = parts[1];
      final rank = int.tryParse(parts[2]);
      if (rank == null || rank < 1 || rank > 3) return;

      final prefs = await SharedPreferences.getInstance();
      final shownKey = 'shown_monthly_winner_${monthKey}_$rank';
      final alreadyShown = prefs.getBool(shownKey) ?? false;
      if (alreadyShown) return;

      await prefs.setBool(shownKey, true);
      if (!mounted) return;

      final medalColor = rank == 1
          ? const Color(0xFFFFD700)
          : rank == 2
              ? const Color(0xFFC0C0C0)
              : const Color(0xFFCD7F32);
      final rankLabel = rank == 1
          ? '#1 User of the Month'
          : rank == 2
              ? 'Top 2 User of the Month'
              : 'Top 3 User of the Month';

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            backgroundColor: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0B1220),
                      AppColors.primary.withOpacity(0.95),
                      AppColors.secondary.withOpacity(0.95),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                medalColor.withOpacity(0.9),
                                medalColor.withOpacity(0.55),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: medalColor.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            rank == 1
                                ? Icons.emoji_events_rounded
                                : Icons.military_tech_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Congratulations!',
                                style: AppTextStyles.heading3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rankLabel,
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: Colors.white.withOpacity(0.92),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: AppTextStyles.bodyBold
                                .copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification.message,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withOpacity(0.92),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 18,
                                  color: Colors.white.withOpacity(0.9)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your consistency is now part of the MLQ Hall of Fame for $monthKey.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withOpacity(0.88),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.28)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              Navigator.of(context)
                                  .pushReplacementNamed('/leaderboard');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: medalColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text(
                              'View Leaderboard',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted) return;
      try {
        final provider =
            Provider.of<NotificationProvider>(context, listen: false);
        await provider.markAsRead(notification.id);
      } catch (_) {}
    } catch (_) {
      // best-effort
    }
  }

  // Removed tutorial check/show methods

  // Analyze recent daily goals distribution and suggest balancing categories
  Future<void> _maybeSuggestBalancedGoals() async {
    try {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      // Collect last 14 days of daily goals (fallback to all if timestamps not available)
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 13));
      final counts = <String, int>{};

      for (final g in goalProvider.dailyGoals) {
        // Expect g.date and g.category (string). Use safe accessors.
        final dt = (g as dynamic).date as DateTime?;
        if (dt == null) continue;
        if (dt.isBefore(start) || dt.isAfter(now)) continue;
        final cat = ((g as dynamic).category?.toString() ?? '').toLowerCase();
        if (cat.isEmpty) continue;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }

      if (counts.isEmpty) return; // Not enough data

      // Define key categories we care about
      const keyCats = ['academic', 'health', 'social'];
      for (final c in keyCats) {
        counts.putIfAbsent(c, () => 0);
      }

      // Find dominant and weak categories
      String topCat = keyCats.first;
      String lowCat = keyCats.first;
      for (final c in keyCats) {
        if ((counts[c] ?? 0) > (counts[topCat] ?? 0)) topCat = c;
        if ((counts[c] ?? 0) < (counts[lowCat] ?? 0)) lowCat = c;
      }

      // Trigger suggestion only if imbalance is noticeable
      final diff = (counts[topCat] ?? 0) - (counts[lowCat] ?? 0);
      if (diff < 3) return; // small differences are ignored

      if (!mounted) return;
      final msg =
          'You\'ve focused a lot on ${topCat}. Try adding 1-2 ${lowCat} goals this week for balance.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
              TextButton(
                onPressed: () {
                  // Already on Goals tab; no need to navigate
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child:
                    const Text('GOT IT', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
          backgroundColor: const Color(0xFF00C4FF),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      // best-effort; ignore errors
    }
  }

  /// Check for app updates from Play Store and prompt user if available
  Future<void> _checkForAppUpdate() async {
    try {
      await AppUpdateService.instance.checkAndPromptUpdate(context);
    } catch (e) {
      debugPrint('App update check failed: $e');
    }
  }

  @override
  void dispose() {
    _inAppNotifSub?.cancel();
    _challengeCompletionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use wide layout for screens >= 900 logical pixels wide
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          body: Row(
            children: [
              if (isDesktop)
                DesktopNavRail(
                  currentIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  items: const [
                    DesktopRailItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    DesktopRailItem(
                      icon: Icons.flag_outlined,
                      activeIcon: Icons.flag_rounded,
                      label: 'Goals',
                    ),
                    DesktopRailItem(
                      icon: Icons.emoji_events_outlined,
                      activeIcon: Icons.emoji_events_rounded,
                      label: 'Challenges',
                    ),
                    DesktopRailItem(
                      icon: Icons.celebration_outlined,
                      activeIcon: Icons.celebration_rounded,
                      label: 'Victory',
                    ),
                    DesktopRailItem(
                      icon: Icons.leaderboard_outlined,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Ranks',
                    ),
                  ],
                ),
              Expanded(
                child: Stack(
                  children: [
                    // Main screen content
                    _screens[_selectedIndex],
                    // Additional overlays can go here
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : GlassBottomNavBar(
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  items: const [
                    PremiumNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    PremiumNavItem(
                      icon: Icons.flag_outlined,
                      activeIcon: Icons.flag_rounded,
                      label: 'Goals',
                    ),
                    PremiumNavItem(
                      icon: Icons.emoji_events_outlined,
                      activeIcon: Icons.emoji_events_rounded,
                      label: 'Challenges',
                    ),
                    PremiumNavItem(
                      icon: Icons.celebration_outlined,
                      activeIcon: Icons.celebration_rounded,
                      label: 'Victory',
                    ),
                    PremiumNavItem(
                      icon: Icons.leaderboard_outlined,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Ranks',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
