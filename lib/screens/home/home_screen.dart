import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/badge_service.dart' as badge_service;

import '../onboarding/goal_onboarding_screen.dart';
import '../goals/daily_goal_grid_screen.dart';
import '../../constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../utils/holiday_utils.dart';
import '../../widgets/gratitude_slider.dart';
import '../gratitude/gratitude_jar_screen.dart';
import '../mini_courses/mini_course_detail_screen.dart';
import '../mini_courses/mini_courses_screen.dart';
import '../mini_courses/community_course_detail_screen.dart';
import '../mini_courses/school_course_viewer_screen.dart';
import '../../services/community_course_service.dart';
import '../../providers/school_course_provider.dart';
import '../../models/school_course_model.dart';
import '../../widgets/advanced_floating_questor_widget.dart';
import '../../widgets/trial_countdown_banner.dart';
import '../../widgets/christmas_decorations.dart';
// Removed debug-only services: push notification test and secure goal debug actions
import '../../services/challenge_evaluator.dart';
import '../../widgets/goal_completion_dialog.dart';
import '../goals/goal_history_screen.dart';
import '../wallet/wallet_dashboard_screen.dart';
import '../wallet/wallet_activation_screen.dart';
import '../profile/setup_security_questions_screen.dart';
import '../library/library_screen.dart';
import '../library/library_video_player_screen.dart';
import '../../widgets/library_watch_limit_dialog.dart';
import '../../widgets/library_thumbnail.dart';
import '../../utils/level_system.dart';
import '../../utils/app_tab_navigation.dart';
import '../../utils/course_visuals.dart';
import '../../utils/entitlements.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Tab controller for goal categories
  late TabController _goalTabController;

  // Track which completion dialogs have been shown (persisted in memory for session)
  static final Set<String> _shownCompletionDialogs = {};
  final Queue<MainGoalModel> _completionDialogQueue = Queue();
  bool _isShowingCompletionDialog = false;

  // Stream subscriptions
  StreamSubscription<MainGoalModel>? _goalCompletionSubscription;
  StreamSubscription<ChallengeCompletionEvent>?
      _challengeCompletionSubscription;
  StreamSubscription<List<MainGoalModel>>? _expiredGoalsSubscription;

  // Track shown challenge completions to avoid duplicates
  static final Set<String> _shownChallengeCompletions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize tab controller for goal categories
    _goalTabController = TabController(length: 3, vsync: this);

    // Check for badge achievements when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize the singleton evaluator with providers
      ChallengeEvaluator.instance.initialize(
        userProvider: Provider.of<UserProvider>(context, listen: false),
        goalProvider: Provider.of<GoalProvider>(context, listen: false),
        gratitudeProvider:
            Provider.of<GratitudeProvider>(context, listen: false),
        miniCourseProvider:
            Provider.of<MiniCourseProvider>(context, listen: false),
        challengeProvider:
            Provider.of<ChallengeProvider>(context, listen: false),
      );

      _checkForAchievements();
      _ensureDailyCourse();
      _initializeSchoolCourses();
      _listenForGoalCompletions();
      _listenForChallengeCompletions();
      _listenForExpiredGoals();
      _checkSecurityQuestions();
      _maybeShowTrialMessaging();
      _maybeShowLeadWalletOnboarding();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _goalTabController.dispose();
    _goalCompletionSubscription?.cancel();
    _challengeCompletionSubscription?.cancel();
    _expiredGoalsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureDailyCourse();
      // Check for expired goals when app resumes
      _checkExpiredGoalsOnResume();
    }
  }

  // Check for expired goals when app resumes from background
  Future<void> _checkExpiredGoalsOnResume() async {
    if (!mounted) return;
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    await goalProvider.checkExpiredGoals();
  }

  Future<void> _maybeShowTrialMessaging() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || Entitlements.hasPaidAccess(user)) return;

    if (Entitlements.canUseMiniCourses(user)) {
      await TrialWelcomeDialog.show(
        context,
        days: Entitlements.miniCourseFreeDays,
      );
      return;
    }

    await TrialExpiredModal.showOnce(context);
  }

  Future<void> _maybeShowLeadWalletOnboarding() async {
    if (!mounted) return;
    // Let other first-run dialogs settle first
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isAuthenticated) return;
    final user = userProvider.user;
    if (!Entitlements.hasPaidAccess(user)) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    await FeatureAnnouncements.showLeadWalletOnboarding(
      context,
      onExplore: () {
        if (!mounted) return;
        final user = Provider.of<UserProvider>(context, listen: false).user;
        if (user != null && user.isWalletActive) {
          Navigator.pushNamed(context, '/wallet');
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WalletActivationScreen(),
            ),
          );
        }
      },
    );
  }

  void _ensureDailyCourse() {
    final mini = Provider.of<MiniCourseProvider>(context, listen: false);
    // Load shared/global daily courses (3 per day)
    mini.loadTodayCourses();
  }

  void _initializeSchoolCourses() {
    final schoolProvider =
        Provider.of<SchoolCourseProvider>(context, listen: false);
    // Initialize school courses for users with a school
    schoolProvider.initialize();
  }

  // Check for any new badge achievements
  Future<void> _checkForAchievements() async {
    if (!mounted) return;
    final badgeService =
        Provider.of<badge_service.BadgeService>(context, listen: false);
    final newBadges = await badgeService.checkForAchievements();
    if (!mounted) return;

    // Show badge earned dialog if any new badges were earned
    for (var badge in newBadges) {
      if (!mounted) return;
      // Show dialog with slight delay between each one if multiple
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      badgeService.showBadgeEarnedDialog(context, badge);
    }
  }

  // Check if the user needs to set up security questions
  void _checkSecurityQuestions() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || user.hasSecurityQuestions) return;

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.user?.hasSecurityQuestions ?? false) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Action Required', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'To keep your account secure and make it easy to recover your password if you ever forget it, please set up your security questions now.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!mounted) return;
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SetupSecurityQuestionsScreen(isModal: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Set Up Now'),
            ),
          ],
        ),
      );
    });
  }

  // Listen for goal completions and show celebration dialog
  void _listenForGoalCompletions() {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);

    // Listen to the goal completion stream for real-time events
    _goalCompletionSubscription =
        goalProvider.goalCompletionStream.listen((goal) {
      if (!mounted) return;
      if (_shownCompletionDialogs.contains(goal.id)) return;

      debugPrint('🎉 Received goal completion event for: ${goal.title}');
      _shownCompletionDialogs.add(goal.id);
      _enqueueCompletionDialog(goal);
    });
  }

  // Listen for expired goals and show notification
  void _listenForExpiredGoals() {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);

    _expiredGoalsSubscription =
        goalProvider.expiredGoalsStream.listen((expiredGoals) {
      if (!mounted) return;
      if (expiredGoals.isEmpty) return;

      debugPrint('⏰ ${expiredGoals.length} goal(s) expired');
      _showExpiredGoalsNotification(expiredGoals);
    });
  }

  // Show notification for expired goals
  void _showExpiredGoalsNotification(List<MainGoalModel> expiredGoals) {
    if (!mounted) return;

    final goalCount = expiredGoals.length;
    final message = goalCount == 1
        ? 'Your goal "${expiredGoals.first.title}" has expired.'
        : '$goalCount of your goals have expired.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Goal Expired'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Text(
              'You can archive expired goals and create new ones to continue your progress.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to goal history to manage expired goals
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoalHistoryScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Manage Goals'),
          ),
        ],
      ),
    );
  }

  // Listen for challenge completions and show celebration dialog
  void _listenForChallengeCompletions() {
    _challengeCompletionSubscription =
        ChallengeEvaluator.instance.completionStream.listen((event) {
      if (!mounted) return;
      if (_shownChallengeCompletions.contains(event.challengeId)) return;

      _shownChallengeCompletions.add(event.challengeId);
      _showChallengeCompletionDialog(event);
    });
  }

  // Show challenge completion celebration dialog
  void _showChallengeCompletionDialog(ChallengeCompletionEvent event) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy icon with animation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Challenge Complete!',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Coin reward display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      color: AppColors.secondary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '+${event.coinReward} coins',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Great job! Keep up the amazing work!',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Awesome!'),
            ),
          ),
        ],
      ),
    );
  }

  void _enqueueCompletionDialog(MainGoalModel goal) {
    _completionDialogQueue.add(goal);
    _processCompletionDialogs();
  }

  Future<void> _processCompletionDialogs() async {
    if (_isShowingCompletionDialog ||
        _completionDialogQueue.isEmpty ||
        !mounted) {
      return;
    }

    _isShowingCompletionDialog = true;

    final goal = _completionDialogQueue.removeFirst();
    await _showGoalCompletionDialog(goal);

    _isShowingCompletionDialog = false;

    if (_completionDialogQueue.isNotEmpty) {
      _processCompletionDialogs();
    }
  }

  // Show goal completion celebration dialog
  Future<void> _showGoalCompletionDialog(MainGoalModel goal) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoalCompletionDialog(
        goal: goal,
        onArchive: () async {
          final goalProvider =
              Provider.of<GoalProvider>(context, listen: false);
          await goalProvider.archiveMainGoal(goal.id);

          if (context.mounted) {
            Navigator.of(context).pop();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Goal archived! You can now set a new goal.',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
                backgroundColor: AppColors.success,
                action: SnackBarAction(
                  label: 'Set New Goal',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GoalOnboardingScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        },
        onKeepActive: () {
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Goal kept active. You can archive it later from history.',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _showUpgradePrompt(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Upgrade to Premium'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock $feature and get access to:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✨ Premium Benefits:', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  Text('• Unlimited premium challenges',
                      style: AppTextStyles.body),
                  Text('• Advanced mini-courses', style: AppTextStyles.body),
                  Text('• Extra coins and rewards', style: AppTextStyles.body),
                  Text('• Priority AI coaching', style: AppTextStyles.body),
                  Text('• Detailed progress analytics',
                      style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to subscription management with proper context
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/subscription-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  // dispose moved above to unregister observer

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main scaffold with app bar and content
        Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            centerTitle: true,
            shape: AppTheme.appBarShape(context),
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 36,
                    child: Image.asset(
                      'assets/images/questor 9.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'My Leadership Quest',
                    style: AppTextStyles.heading3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            actions: const [],
          ),
          body: _buildHomeContent(),
          floatingActionButton: _buildGratitudeJarButton(),
        ),

        // Overlay the Questor widget
        const AdvancedFloatingQuestorWidget(),
      ],
    );
  }

  Widget _buildGenderPrompt() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Show illustrations for',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _genderChip('Boy', 'male'),
          const SizedBox(width: 8),
          _genderChip('Girl', 'female'),
        ],
      ),
    );
  }

  Widget _genderChip(String label, String value) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Provider.of<UserProvider>(context, listen: false)
            .updateUserProfile(gender: value);
      },
    );
  }

  Widget _homeAvatarInitial(UserModel? user) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Center(
        child: Text(
          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
          style: AppTextStyles.heading1.copyWith(color: AppColors.primary, fontSize: 26),
        ),
      ),
    );
  }

  // Build the gratitude jar floating action button
  Widget _buildGratitudeJarButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80.0),
      child: Animate(
        effects: [
          FadeEffect(duration: 400.ms),
          ScaleEffect(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.easeOutBack,
          ),
        ],
        child: FloatingActionButton(
          onPressed: () {
            if (!guardPaidAction(
              context,
              message: 'Subscribe to use the Gratitude Jar',
            )) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GratitudeJarScreen(),
              ),
            );
          },
          heroTag: 'gratitude_fab',
          backgroundColor: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/gratitude-jar.png',
              width: 78,
              height: 50,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    // Access providers that will be used throughout the UI
    final userProvider = Provider.of<UserProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);

    // Get data from providers
    final user = userProvider.user;
    // Include both active and expired goals so users can see and archive expired ones
    final mainGoals = goalProvider.mainGoals;
    final expiredGoals = goalProvider.expiredGoals;
    final allDisplayableGoals = [...mainGoals, ...expiredGoals];

    // These stats are used in the UI components below
    // Keeping the variables here for clarity and future use

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 28,
              maxWidth: 1100,
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          const MaintenanceBanner(),
          // Mini-course preview countdown for free-tier users
          Builder(
            builder: (context) {
              if (user == null || Entitlements.hasPaidAccess(user)) {
                return const SizedBox.shrink();
              }
              final daysRemaining = Entitlements.miniCourseDaysRemaining(user);
              if (daysRemaining > 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TrialCountdownBanner(daysRemaining: daysRemaining),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FeatureLockCard(
                  compact: true,
                  title: 'Mini-courses ended',
                  description:
                      'Subscribe to keep mini-courses, plus the library, challenges, LeadWallet, and Victory Wall posts. Goals and Gratitude Jar stay free.',
                  icon: Icons.lock_clock_rounded,
                ),
              );
            },
          ),
          // User profile card with stats
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              decoration: NeumorphicStyles.large.copyWith(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Main content container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: ChristmasBanner.shouldShow
                            ? [
                                const Color(0xFF1E5631), // Christmas green
                                const Color(0xFF2D7A46), // Lighter green
                              ]
                            : [
                                AppColors.primaryDark,
                                AppColors.primary,
                                AppColors.violetLight,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ChristmasBanner.shouldShow
                            ? const Color(0xFFFFD700)
                                .withOpacity(0.4) // Gold border
                            : Colors.white.withOpacity(0.10),
                        width: ChristmasBanner.shouldShow ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ChristmasBanner.shouldShow
                              ? const Color(0xFFC41E3A)
                                  .withOpacity(0.2) // Christmas red glow
                              : AppColors.plum.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // User avatar with gradient ring
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: ChristmasBanner.shouldShow
                                      ? [
                                          const Color(
                                              0xFFC41E3A), // Christmas red
                                          const Color(0xFFFFD700), // Gold
                                        ]
                                      : [
                                          AppColors.secondaryBright,
                                          AppColors.goldPressed,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ChristmasBanner.shouldShow
                                        ? const Color(0xFFFFD700)
                                            .withOpacity(0.4)
                                        : AppColors.secondary.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: user?.avatarUrl != null &&
                                      user!.avatarUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        user!.avatarUrl!,
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _homeAvatarInitial(user),
                                      ),
                                    )
                                  : _homeAvatarInitial(user),
                            ),
                            const SizedBox(width: 16),

                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    HolidayUtils.getHolidayGreeting() != null
                                        ? '${HolidayUtils.getHolidayGreeting()}, ${user?.name ?? 'Leader'}!'
                                        : 'Hello, ${user?.name ?? 'Leader'}!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.heading3.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    HolidayUtils.getHolidaySubtitle() ?? _buildMotivationalSubtitle(context),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Gamification: Daily Streak & Level Badge
                                  if (userProvider.user != null)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        MlqPill(
                                          label: '${userProvider.user!.currentStreak} Day Streak',
                                          icon: Icons.local_fire_department,
                                          background: Colors.white.withOpacity(0.14),
                                          foreground: Colors.white,
                                        ),
                                        MlqPill.gold(
                                          label: 'Lvl ${LevelSystem.getLevelForXp(userProvider.user!.xp)} · ${LevelSystem.getLevelTitleForXp(userProvider.user!.xp)}',
                                          icon: Icons.workspace_premium_rounded,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats row - Use Consumer for reactive updates with error handling
                        Consumer<UserProvider>(
                          builder: (context, userProvider, child) {
                            final currentUser = userProvider.user;
                            final isDataLoaded = currentUser != null;

                            // Show loading state if user data hasn't loaded yet
                            if (!isDataLoaded) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItemLoading(
                                      Icons.star, 'XP POINTS', AppColors.secondaryBright),
                                  _buildStatItemLoading(Icons.monetization_on,
                                      'COINS', AppColors.secondary),
                                  _buildStatItemLoading(Icons.emoji_events,
                                      'BADGES', const Color(0xFFE7D3EC)),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    // XP Points - use direct provider reference for consistent updates
                                    _buildStatItem(
                                      icon: Icons.star,
                                      value: '${currentUser.xp}',
                                      label: 'LIFETIME XP',
                                      color: AppColors.secondaryBright,
                                      isError: false,
                                      onTap: () {
                                        // Navigate to leaderboard when XP is tapped
                                        Navigator.pushNamed(context, '/leaderboard');
                                      },
                                    ),
                                    // Coins - with proper formatting
                                    _buildStatItem(
                                      icon: Icons.monetization_on,
                                      value: currentUser.coins >= 1000
                                          ? '${(currentUser.coins / 1000).toStringAsFixed(1)}K'
                                          : currentUser.coins.toStringAsFixed(1),
                                      label: 'COINS',
                                      color: AppColors.secondary,
                                      isError: false,
                                      onTap: () {
                                        // Navigate to coin history when coins are tapped
                                        Navigator.pushNamed(context, '/coin-history');
                                      },
                                    ),

                                    // Badges - get badge count from UserProvider's badges list
                                    _buildStatItem(
                                      icon: Icons.emoji_events,
                                      value: '${userProvider.badges.length}',
                                      label: 'BADGES',
                                      color: const Color(0xFFE7D3EC),
                                      isError: false,
                                      onTap: () => Navigator.pushNamed(context, '/profile'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Visual XP Progress Bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Progress to Level ${LevelSystem.getLevelForXp(currentUser.xp) + 1}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${currentUser.xp} / ${LevelSystem.getXpForNextLevel(currentUser.xp)} XP',
                                          maxLines: 1,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: LevelSystem.getProgressToNextLevel(currentUser.xp),
                                        backgroundColor: Colors.white.withOpacity(0.16),
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                      },
                    ),
                    ],
                    ),
                  ),
                  // Christmas decorations overlay
                  if (ChristmasBanner.shouldShow) ...[
                    // Top-left holly
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildHollyDecoration(),
                    ),
                    // Top-right ornament
                    Positioned(
                      top: 6,
                      right: 12,
                      child: _buildOrnament(const Color(0xFFC41E3A)),
                    ),
                    // Bottom-right snowflakes
                    Positioned(
                      bottom: 10,
                      right: 16,
                      child: _buildSnowflakes(),
                    ),
                    // Bottom-left candy cane
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Text(
                        '🎄',
                        style: TextStyle(fontSize: 18, shadows: [
                          Shadow(color: Colors.black26, blurRadius: 4),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(duration: 350.ms),

          if (user != null && (user.gender == null || user.gender!.isEmpty)) ...[
            const SizedBox(height: 12),
            _buildGenderPrompt(),
          ],

          const SizedBox(height: 20),

          _buildTodaysQuest(user).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 20),

          // Main goals section with tabs
          Container(
            decoration: NeumorphicStyles.large,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: MlqSectionHeader(
                          title: 'My Main Goals',
                          icon: Icons.flag_rounded,
                        ),
                      ),
                      // View History button
                      if (allDisplayableGoals.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoalHistoryScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            backgroundColor: AppColors.primarySoft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Icons.history,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'History',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (goalProvider.isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  else if (allDisplayableGoals.isEmpty)
                    _buildEmptyGoalsMessage()
                  else
                    _buildGoalTabs(),

                  // Add main goal button only if no goals exist yet
                  if (allDisplayableGoals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: QuestButton(
                        text: 'Set Your Main Goals',
                        icon: Icons.add,
                        type: QuestButtonType.primary,
                        isFullWidth: true,
                        onPressed: () {
                          // Launch the goal onboarding flow
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GoalOnboardingScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms),

          const SizedBox(height: 20),

          // Learn next — keep quest flow: Goals → Courses before secondary widgets
          PaidFeatureGate(
            title: 'Mini-Courses',
            description:
                'Free accounts include mini-courses for 7 days. Subscribe to keep learning.',
            icon: Icons.school_rounded,
            compact: true,
            isAllowed: Entitlements.canUseMiniCourses,
            child: Container(
            decoration: NeumorphicStyles.large,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlqSectionHeader(
                    title: 'Continue Learning',
                    icon: Icons.school_rounded,
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MiniCoursesScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primarySoft,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'See all',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMiniCoursesCarousel(),
                ],
              ),
            ),
          ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 20),

          PaidFeatureGate(
            title: 'LeadWallet',
            description:
                'LeadWallet unlocks with a paid plan. Goals and Gratitude Jar stay free.',
            icon: Icons.account_balance_wallet_rounded,
            compact: true,
            child: _buildWalletCard(user),
          ),
          const SizedBox(height: 14),

          _buildRankPreview(userProvider),
          const SizedBox(height: 20),

          PaidFeatureGate(
            title: 'Digital Library',
            description:
                'Leadership videos unlock with Monthly or Quarterly.',
            icon: Icons.video_library_rounded,
            compact: true,
            child: _buildLibraryPreviewSection(context),
          )
              .animate()
              .fadeIn(duration: 350.ms),

          const SizedBox(height: 20),

          const GratitudeSlider(),
          const SizedBox(height: 20),

          // Secondary: progress insight
          Container(
            decoration: NeumorphicStyles.large,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MlqSectionHeader(
                    title: 'Weekly Progress',
                    icon: Icons.insights_rounded,
                  ),
                  const SizedBox(height: 16),
                  const WeeklyProgressGraph(),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 48), // Extra space for floating button

          // Debug validation panel removed
                ],
            ),
          ),
        );
      },
    );
  }

  /// Picks the single most useful next action (first match wins).
  Widget _buildTodaysQuest(UserModel? user) {
    final mini = Provider.of<MiniCourseProvider>(context);
    final goals = Provider.of<GoalProvider>(context);
    final challenges = Provider.of<ChallengeProvider>(context);
    final gratitude = Provider.of<GratitudeProvider>(context);

    void openCourse(MiniCourseModel c) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MiniCourseDetailScreen(courseId: c.id),
          ),
        );

    if (Entitlements.canUseMiniCourses(user)) {
      final open = mini.todayCourses
          .where((c) =>
              c.status != MiniCourseStatus.completed && !c.quiz.isCompleted)
          .toList();
      final inProgress =
          open.where((c) => c.status == MiniCourseStatus.inProgress);
      final course = inProgress.isNotEmpty
          ? inProgress.first
          : (open.isNotEmpty ? open.first : null);
      if (course != null) {
        final started = course.status == MiniCourseStatus.inProgress;
        final total = course.lessons.length;
        final lessonNo = (course.currentLessonIndex + 1).clamp(1, total == 0 ? 1 : total);
        return MlqQuestCard(
          title: course.title,
          subtitle: started
              ? 'Lesson $lessonNo of $total · ${course.topic}'
              : '$total short lessons · ${course.topic}',
          actionLabel: started ? 'Continue' : 'Start lesson',
          icon: Icons.menu_book_rounded,
          coverAsset:
              MlqCourseVisuals.courseCover(
                course.id,
                course.topic,
                course.title,
                gender: user?.gender,
              ),
          onAction: () => openCourse(course),
        );
      }
    }

    final pendingGoals = goals.todayGoals.where((g) => !g.isCompleted).length;
    if (pendingGoals > 0) {
      return MlqQuestCard(
        title: 'Check in on your goals',
        subtitle: pendingGoals == 1
            ? '1 daily goal left for today'
            : '$pendingGoals daily goals left for today',
        actionLabel: 'Check in',
        icon: Icons.flag_rounded,
        coverAsset: MlqCourseVisuals.coverFor('goal', gender: user?.gender),
        onAction: () => AppTabNavigation.goToTab(1),
      );
    }

    final now = DateTime.now();
    final endingSoon = challenges.activeParticipatingChallenges
        .where((c) =>
            c.endDate.isAfter(now) &&
            c.endDate.difference(now) <= const Duration(hours: 48))
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    if (endingSoon.isNotEmpty) {
      final c = endingSoon.first;
      final hours = c.endDate.difference(now).inHours;
      return MlqQuestCard(
        title: c.title,
        subtitle: hours < 24
            ? 'Ends in $hours h — finish strong'
            : 'Ends tomorrow — finish strong',
        actionLabel: 'View challenge',
        icon: Icons.emoji_events_rounded,
        coverAsset:
            MlqCourseVisuals.coverFor('resilience', gender: user?.gender),
        onAction: () => AppTabNavigation.goToTab(2),
      );
    }

    final wroteToday = gratitude.entries.any((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
    if (!wroteToday) {
      return MlqQuestCard(
        title: 'Add to your Gratitude Jar',
        subtitle: 'One thing that went well today',
        actionLabel: 'Write one',
        icon: Icons.favorite_rounded,
        coverAsset: MlqCourseVisuals.coverFor('gratitude'),
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GratitudeJarScreen()),
        ),
      );
    }

    return const MlqQuestCard(
      eyebrow: 'QUEST COMPLETE',
      title: "You're all done for today",
      subtitle: 'Come back tomorrow for a new quest.',
      actionLabel: '',
      onAction: null,
      icon: Icons.check_circle_rounded,
    );
  }

  Widget _buildRankPreview(UserProvider userProvider) {
    final me = userProvider.user;
    if (me == null) return const SizedBox.shrink();
    final board = userProvider.leaderboardUsers;
    final idx = board.indexWhere((u) => u.id == me.id);
    final title = idx >= 0 ? '#${idx + 1} this month' : 'Monthly leaderboard';
    final subtitle = idx >= 0
        ? '${me.monthlyXp} XP earned this month'
        : 'See where you rank with other leaders';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: () => AppTabNavigation.goToTab(4),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    color: AppColors.goldText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGoalsMessage() {
    return const MlqEmptyState(
      title: 'No Main Goals Yet',
      message: 'Set your first main goal to start your leadership journey!',
      icon: Icons.flag_outlined,
    );
  }

  Widget _buildLibraryPreviewSection(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final uid = context.read<UserProvider>().user?.id;

    // Lazy-load library catalog when home is shown.
    if (lib.status == LibraryStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<LibraryProvider>().loadIfStale(userId: uid);
      });
    }

    final preview = lib.previewVideos;

    return Container(
      decoration: NeumorphicStyles.large,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlqSectionHeader(
              title: 'Digital Library',
              icon: Icons.video_library_rounded,
              trailing: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LibraryScreen()),
                  );
                },
                child: const Text('See all'),
              ),
            ),
            if (lib.status == LibraryStatus.loading && preview.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: MlqLoadingState(message: 'Loading videos…'),
              )
            else if (preview.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Educational videos are being curated. Check back soon!',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: preview.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final v = preview[i];
                    return GestureDetector(
                      onTap: () async {
                        final lib = context.read<LibraryProvider>();
                        if (uid != null) {
                          final status =
                              await lib.tryStartWatch(uid, v.youtubeId);
                          if (!status.allowed && context.mounted) {
                            await showLibraryWatchLimitDialog(context, status);
                            return;
                          }
                        }
                        if (!context.mounted) return;
                        lib.trackView(v.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LibraryVideoPlayerScreen(
                              video: v,
                              userId: uid,
                              ytVideoId: v.youtubeId,
                              watchAlreadyRecorded: true,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 200,
                                height: 96,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    LibraryThumbnail(video: v, fit: BoxFit.cover),
                                    Center(
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRect(
                              child: SizedBox(
                                height: 52,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 34,
                                      child: Text(
                                        v.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 16,
                                      child: Text(
                                        v.channelName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCoursesCarousel() {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final state = miniCourseProvider.dailyState;
    final todayCourses = miniCourseProvider.todayCourses;

    // Show loading state
    if (state == DailyCourseState.fetchingServer ||
        state == DailyCourseState.generating ||
        state == DailyCourseState.polling) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Loading today\'s mini-courses...',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (state == DailyCourseState.error) {
      final errorMessage =
          miniCourseProvider.lastError ?? 'Failed to load courses';
      final isMaintenance = miniCourseProvider.isMaintenance;
      final isNetworkError = !isMaintenance &&
          (errorMessage.toLowerCase().contains('internet') ||
              errorMessage.toLowerCase().contains('network') ||
              errorMessage.toLowerCase().contains('connection'));

      if (isMaintenance) {
        // Dedicated maintenance card – no retry button since the issue is server-side
        return SizedBox(
          height: 220,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.construction_rounded,
                        size: 36, color: Color(0xFFF9A825)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mini-Courses Under Maintenance',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: const Color(0xFF7B5800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            errorMessage,
                            style: AppTextStyles.caption.copyWith(
                              color: const Color(0xFF9A6F00),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        height: 220,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNetworkError ? Icons.wifi_off : Icons.error_outline,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => miniCourseProvider.loadTodayCourses(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show empty state
    if (todayCourses.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'No courses available yet',
                style:
                    AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back tomorrow for new courses!',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      );
    }

    // Get school courses if user has a school with premium
    final schoolProvider = Provider.of<SchoolCourseProvider>(context);
    final schoolCourses = schoolProvider.hasSchool && schoolProvider.hasPremium
        ? schoolProvider.publishedCourses
        : <SchoolCourse>[];

    final totalItems = schoolCourses.length + todayCourses.length;
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    Widget itemAt(int index) {
      if (index < schoolCourses.length) {
        return _buildSchoolCourseCard(
            schoolCourses[index], index, schoolProvider);
      }
      return _buildCourseCoverCard(
          todayCourses[index - schoolCourses.length],
          index - schoolCourses.length);
    }

    if (desktop && totalItems <= 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < totalItems; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: itemAt(i)),
          ],
        ],
      );
    }

    return SizedBox(
      height: desktop ? 300 : 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalItems,
        itemBuilder: (context, index) => itemAt(index),
      ),
    );
  }

  Widget _buildCourseCoverCard(MiniCourseModel course, int index) {
    final done = course.status == MiniCourseStatus.completed ||
        course.quiz.isCompleted;
    final inProgress = !done && course.status == MiniCourseStatus.inProgress;
    final gender = Provider.of<UserProvider>(context, listen: false).user?.gender;
    final cover = MlqCourseVisuals.courseCover(
      course.id,
      course.topic,
      course.title,
      gender: gender,
    );

    void open() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MiniCourseDetailScreen(courseId: course.id),
        ),
      );
    }

    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      width: desktop ? null : 220,
      margin: EdgeInsets.only(right: desktop ? 0 : 14, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: done ? null : open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MlqCoverImage(
                      asset: cover,
                      fallbackIcon: MlqCourseVisuals.iconFor(course.topic),
                    ),
                    if (done)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: MlqPill(
                          label: 'Done',
                          icon: Icons.check_rounded,
                          background: AppColors.success,
                          foreground: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.topic.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.goldText,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 14,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 18,
                            color: done ? AppColors.success : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              done
                                  ? 'Completed'
                                  : inProgress
                                      ? 'Continue'
                                      : 'Start · ${course.lessons.length} lessons',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color:
                                    done ? AppColors.success : AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 80).ms)
        .slideX(begin: 0.15, end: 0);
  }

  /// Build a branded community course card with distinct styling
  Widget _buildCommunityCourseCard(CommunityMiniCourse course, int index) {
    // Community courses use a distinct gold/amber gradient to stand out
    const communityColor = Color(0xFFFF6B00); // Vibrant orange for community

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityCourseDetailScreen(courseId: course.id),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: communityColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: communityColor.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header with community branding
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    communityColor,
                    Color(0xFFFF8C00), // Darker orange
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Community badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            course.communityName,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.topic,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Course content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    QuestButton(
                      text: course.isCompleted ? 'Completed \u2713' : 'Start',
                      type: course.isCompleted
                          ? QuestButtonType.secondary
                          : QuestButtonType.primary,
                      height: 36,
                      onPressed: course.isCompleted
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityCourseDetailScreen(
                                      courseId: course.id),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: (index * 100).ms)
        .slideX(begin: 0.2, end: 0);
  }

  /// Build a branded school course card with school logo
  Widget _buildSchoolCourseCard(
      SchoolCourse course, int index, SchoolCourseProvider schoolProvider) {
    // Use school's primary color or default to a nice blue
    final schoolColor = schoolProvider.schoolPrimaryColor != null
        ? Color(int.parse(
            schoolProvider.schoolPrimaryColor!.replaceFirst('#', '0xFF')))
        : const Color(0xFF1976D2);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SchoolCourseViewerScreen(courseId: course.id),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: schoolColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: schoolColor.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header with school branding
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    schoolColor,
                    schoolColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School badge with logo
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (schoolProvider.schoolLogo != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              schoolProvider.schoolLogo!,
                              width: 16,
                              height: 16,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.school,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 14,
                          ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            schoolProvider.schoolName ?? 'School',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.topic,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Course content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QuestButton(
                      text: 'Start',
                      type: QuestButtonType.primary,
                      height: 44,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SchoolCourseViewerScreen(courseId: course.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: (index * 100).ms)
        .slideX(begin: 0.2, end: 0);
  }

  String _buildMotivationalSubtitle(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final mini = Provider.of<MiniCourseProvider>(context, listen: false);

    // 1) Daily mini-courses ready but not started (check todayCourses)
    if (mini.dailyState == DailyCourseState.ready &&
        mini.todayCourses.isNotEmpty) {
      final hasNotStarted =
          mini.todayCourses.any((c) => c.status == MiniCourseStatus.notStarted);
      if (hasNotStarted) {
        return 'Your daily mini-courses are ready. Start now to earn XP!';
      }
    }

    // 2) Daily course generating/fetching
    if ({
      DailyCourseState.checkingCache,
      DailyCourseState.fetchingServer,
      DailyCourseState.generating,
      DailyCourseState.polling,
    }.contains(mini.dailyState)) {
      return "Preparing your daily mini-courses… They'll be ready shortly.";
    }

    // 3) Active goal nudge
    final goals = goalProvider.mainGoals;
    if (goals.isNotEmpty) {
      final topGoal = goals.first;
      final title = topGoal.title?.trim().isNotEmpty == true
          ? topGoal.title!.trim()
          : 'your main goal';
      return 'Make a little progress on "$title" today.';
    }

    // 4) Badge milestone hint
    final badgeCount = userProvider.badges.length;
    if (badgeCount % 5 == 4) {
      return 'One more badge to hit your next milestone!';
    }

    // 5) XP momentum
    final xp = userProvider.user?.xp ?? 0;
    if (xp > 0) {
      final nextMilestone = ((xp / 100).floor() + 1) * 100;
      final remaining = nextMilestone - xp;
      if (remaining <= 30) {
        return 'Only $remaining XP to reach $nextMilestone. You got this!';
      }
    }

    // 6) Time-of-day personalization
    final hour = DateTime.now().hour;
    if (hour < 12) return 'A strong start sets the tone for your day.';
    if (hour < 18) return 'Quick wins await this afternoon.';
    return 'A short activity now can close your day strong.';
  }



  // Christmas decoration widgets
  Widget _buildHollyDecoration() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Holly leaves
        Stack(
          children: [
            // Leaf 1
            Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 16,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF228B22),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Leaf 2
            Positioned(
              left: 8,
              child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  width: 16,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Berries
            Positioned(
              left: 6,
              top: 4,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC143C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC143C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrnament(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ornament hook
        Container(
          width: 6,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Ornament ball
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.9),
                color,
              ],
              center: const Alignment(-0.3, -0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnowflakes() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '❄',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            shadows: const [Shadow(color: Colors.white54, blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '❄',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
            shadows: const [Shadow(color: Colors.white54, blurRadius: 3)],
          ),
        ),
      ],
    );
  }

  void _showAddMainGoalDialog(BuildContext context) {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    String title = '';
    String? description;
    GoalCategory category = GoalCategory.academic;
    GoalTimeline timeline = GoalTimeline.monthly;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Set a Main Goal', style: AppTextStyles.heading3),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'Enter your goal',
                      ),
                      onChanged: (value) {
                        title = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Describe your goal',
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        description = value.isNotEmpty ? value : null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category selection
                    Text('Category', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCategoryOption(
                          context,
                          GoalCategory.academic,
                          category,
                          (value) {
                            setState(() {
                              category = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryOption(
                          context,
                          GoalCategory.social,
                          category,
                          (value) {
                            setState(() {
                              category = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildCategoryOption(
                          context,
                          GoalCategory.health,
                          category,
                          (value) {
                            setState(() {
                              category = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Timeline selection
                    Text('Timeline', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimelineOption(
                            'Monthly',
                            'Complete in 1 month',
                            GoalTimeline.monthly,
                            timeline,
                            (value) {
                              setState(() {
                                timeline = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimelineOption(
                            '3-Month',
                            'Complete in 3 months',
                            GoalTimeline.threeMonth,
                            timeline,
                            (value) {
                              setState(() {
                                timeline = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a goal title',
                            style: AppTextStyles.body
                                .copyWith(color: Colors.white),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    // Create and add the main goal
                    final MainGoalModel newGoal;
                    if (timeline == GoalTimeline.monthly) {
                      newGoal = MainGoalModel.createMonthlyGoal(
                        userId: userProvider.user!.id,
                        title: title,
                        category: category,
                        description: description,
                      );
                    } else {
                      newGoal = MainGoalModel.createThreeMonthGoal(
                        userId: userProvider.user!.id,
                        title: title,
                        category: category,
                        description: description,
                      );
                    }

                    goalProvider.addMainGoal(newGoal);

                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Main goal added!',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryOption(
    BuildContext context,
    GoalCategory value,
    GoalCategory groupValue,
    ValueChanged<GoalCategory> onChanged,
  ) {
    final isSelected = value == groupValue;
    final color = _getCategoryColor(value);
    final iconData = _getCategoryIcon(value);
    final name = _getCategoryName(value);

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              iconData,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineOption(
    String title,
    String subtitle,
    GoalTimeline value,
    GoalTimeline groupValue,
    ValueChanged<GoalTimeline> onChanged,
  ) {
    final isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyBold.copyWith(
                color: isSelected ? AppColors.secondary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return AppColors.academic;
      case GoalCategory.social:
        return AppColors.social;
      case GoalCategory.health:
        return AppColors.health;
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return Icons.school;
      case GoalCategory.social:
        return Icons.people;
      case GoalCategory.health:
        return Icons.fitness_center;
    }
  }

  String _getCategoryName(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return 'Academic';
      case GoalCategory.social:
        return 'Social';
      case GoalCategory.health:
        return 'Health';
    }
  }

  // Build stat item for user profile card with error handling
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isError,
    VoidCallback? onTap,
  }) {
    Widget content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Icon(
            isError ? Icons.error_outline : icon,
            color: isError ? Colors.red : color,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isError ? '--' : value,
            style: AppTextStyles.heading3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    // If onTap is provided, wrap in GestureDetector with scale animation
    return onTap != null && !isError
        ? GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 100),
              child: content,
            ),
          )
        : content;
  }

  // Build loading state for stat items
  Widget _buildStatItemLoading(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateMainGoalDialog(GoalCategory category) async {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (goalProvider.activeGoalsCount >= 3) {
      final completedOrExpired = goalProvider.completedGoals.length +
          goalProvider.expiredGoals.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completedOrExpired > 0
                ? 'You already have 3 active main goals (1 per category). Archive a completed or expired goal first.'
                : 'You already have 3 active main goals (1 per category).',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final categoryTaken = goalProvider.activeMainGoalsForDailyGoals
        .any((g) => g.category == category);
    if (categoryTaken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have an active ${_categoryDisplayName(category).toLowerCase()} goal. Archive it after it expires or is completed before creating another.',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String title = '';
    String description = '';
    GoalTimeline selectedTimeline = GoalTimeline.monthly;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Add ${_categoryDisplayName(category)} Goal',
                style: AppTextStyles.heading3,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'Enter your goal title',
                      ),
                      maxLength: 50,
                      onChanged: (value) => title = value,
                    ),
                    const SizedBox(height: 12),
                    Text('Goal Timeline', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    RadioListTile<GoalTimeline>(
                      value: GoalTimeline.monthly,
                      groupValue: selectedTimeline,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedTimeline = value;
                          });
                        }
                      },
                      title: const Text('Monthly Goal'),
                      subtitle:
                          const Text('A goal to achieve within one month'),
                    ),
                    RadioListTile<GoalTimeline>(
                      value: GoalTimeline.threeMonth,
                      groupValue: selectedTimeline,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedTimeline = value;
                          });
                        }
                      },
                      title: const Text('3-Month Goal'),
                      subtitle: const Text(
                          'A bigger goal to achieve within three months'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Goal Description (Optional)',
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Describe your goal in more detail',
                      ),
                      maxLines: 3,
                      onChanged: (value) => description = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (title.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a goal title',
                                  style: AppTextStyles.body
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          final userId = userProvider.user?.id;
                          if (userId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'You need to be signed in to create goals.',
                                  style: AppTextStyles.body
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                          });

                          final trimmedDescription = description.trim().isEmpty
                              ? null
                              : description.trim();

                          final newGoal =
                              selectedTimeline == GoalTimeline.monthly
                                  ? MainGoalModel.createMonthlyGoal(
                                      userId: userId,
                                      title: title.trim(),
                                      category: category,
                                      description: trimmedDescription,
                                    )
                                  : MainGoalModel.createThreeMonthGoal(
                                      userId: userId,
                                      title: title.trim(),
                                      category: category,
                                      description: trimmedDescription,
                                    );

                          try {
                            await goalProvider.addMainGoal(newGoal);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setState(() {
                                isSubmitting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error saving goal: $e',
                                    style: AppTextStyles.body
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Create Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _categoryDisplayName(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return 'Academic';
      case GoalCategory.social:
        return 'Social';
      case GoalCategory.health:
        return 'Health';
    }
  }

  // Build tabbed layout for main goals by category
  Widget _buildGoalTabs() {
    final goalProvider = Provider.of<GoalProvider>(context);
    // Include both active and expired goals (but not archived) so users can archive expired ones
    final mainGoals = goalProvider.mainGoals;
    final expiredGoals = goalProvider.expiredGoals;
    final allDisplayableGoals = [...mainGoals, ...expiredGoals];

    // Filter goals by category
    final academicGoals = allDisplayableGoals
        .where((goal) => goal.category == GoalCategory.academic)
        .toList();
    final socialGoals = allDisplayableGoals
        .where((goal) => goal.category == GoalCategory.social)
        .toList();
    final healthGoals = allDisplayableGoals
        .where((goal) => goal.category == GoalCategory.health)
        .toList();

    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      children: [
        if (!desktop)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: _goalTabController,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide.none,
            ),
            dividerColor: Colors.transparent,
            overlayColor: MaterialStateProperty.all(Colors.transparent),
            labelStyle: AppTextStyles.bodyBold,
            unselectedLabelStyle: AppTextStyles.body,
            padding: const EdgeInsets.all(4),
            // Increase tab width to prevent text overflow
            labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
            tabs: [
              Tab(
                child: AnimatedBuilder(
                  animation: _goalTabController,
                  builder: (context, _) {
                    final isSelected = _goalTabController.index == 0;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school,
                            size: 20,
                            color: isSelected
                                ? AppColors.academic
                                : AppColors.textSecondary),
                        const SizedBox(height: 2),
                        // Use FittedBox to ensure text fits within available space
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Academic',
                            style: (isSelected
                                    ? AppTextStyles.bodyBold
                                    : AppTextStyles.body)
                                .copyWith(
                                    color: isSelected
                                        ? AppColors.academic
                                        : AppColors.textSecondary),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Tab(
                child: AnimatedBuilder(
                  animation: _goalTabController,
                  builder: (context, _) {
                    final isSelected = _goalTabController.index == 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people,
                            size: 20,
                            color: isSelected
                                ? AppColors.social
                                : AppColors.textSecondary),
                        const SizedBox(height: 2),
                        Text(
                          'Social',
                          style: (isSelected
                                  ? AppTextStyles.bodyBold
                                  : AppTextStyles.body)
                              .copyWith(
                                  color: isSelected
                                      ? AppColors.social
                                      : AppColors.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Tab(
                child: AnimatedBuilder(
                  animation: _goalTabController,
                  builder: (context, _) {
                    final isSelected = _goalTabController.index == 2;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite,
                            size: 20,
                            color: isSelected
                                ? AppColors.health
                                : AppColors.textSecondary),
                        const SizedBox(height: 2),
                        Text(
                          'Health',
                          style: (isSelected
                                  ? AppTextStyles.bodyBold
                                  : AppTextStyles.body)
                              .copyWith(
                                  color: isSelected
                                      ? AppColors.health
                                      : AppColors.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (MediaQuery.sizeOf(context).width >= 900)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _homeGoalPane(
                  goals: academicGoals,
                  category: GoalCategory.academic,
                  emptyLabel: 'No academic goal yet',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeGoalPane(
                  goals: socialGoals,
                  category: GoalCategory.social,
                  emptyLabel: 'No social goal yet',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _homeGoalPane(
                  goals: healthGoals,
                  category: GoalCategory.health,
                  emptyLabel: 'No health goal yet',
                ),
              ),
            ],
          )
        else
          AnimatedBuilder(
            animation: _goalTabController,
            builder: (context, _) {
              final i = _goalTabController.index;
              return _homeGoalPane(
                goals: i == 0
                    ? academicGoals
                    : i == 1
                        ? socialGoals
                        : healthGoals,
                category: i == 0
                    ? GoalCategory.academic
                    : i == 1
                        ? GoalCategory.social
                        : GoalCategory.health,
                emptyLabel: i == 0
                    ? 'No academic goals yet. Add one to get started!'
                    : i == 1
                        ? 'No social goals yet. Add one to get started!'
                        : 'No health goals yet. Add one to get started!',
              );
            },
          ),
      ],
    );
  }

  Widget _homeGoalPane({
    required List<MainGoalModel> goals,
    required GoalCategory category,
    required String emptyLabel,
  }) {
    if (goals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              emptyLabel,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            QuestButton(
              text: 'Add ${_categoryDisplayName(category)} goal',
              icon: Icons.add,
              type: QuestButtonType.primary,
              onPressed: () => _showCreateMainGoalDialog(category),
            ),
          ],
        ),
      );
    }
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      children: [
        for (final goal in goals)
          desktop
              ? _homeGoalVisualCard(goal)
              : GoalCard(
                  goal: goal,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            DailyGoalGridScreen(mainGoal: goal),
                      ),
                    );
                  },
                ),
      ],
    );
  }

  Widget _homeGoalVisualCard(MainGoalModel goal) {
    final gender = Provider.of<UserProvider>(context, listen: false).user?.gender;
    final cover = MlqCourseVisuals.goalCoverFor(
      goal.category.name,
      seed: goal.id,
      gender: gender,
    );
    final color = switch (goal.category) {
      GoalCategory.academic => AppColors.academic,
      GoalCategory.social => AppColors.social,
      GoalCategory.health => AppColors.health,
    };
    final onHeader = goal.category == GoalCategory.health
        ? Colors.black
        : Colors.white;
    final progress = goal.progressPercentage.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DailyGoalGridScreen(mainGoal: goal),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MlqCoverImage(
                      asset: cover,
                      fallbackIcon: switch (goal.category) {
                        GoalCategory.academic => Icons.school_rounded,
                        GoalCategory.social => Icons.people_rounded,
                        GoalCategory.health => Icons.favorite_rounded,
                      },
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          goal.categoryName,
                          style: AppTextStyles.caption.copyWith(
                            color: onHeader,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          goal.timelineText,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      style: AppTextStyles.heading3.copyWith(height: 1.2),
                    ),
                    if (goal.description != null &&
                        goal.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        goal.description!,
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: color.withValues(alpha: 0.15),
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${goal.currentXp}/${goal.totalXpRequired} XP',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${goal.formattedStartDate} – ${goal.formattedEndDate}',
                      style: AppTextStyles.caption,
                    ),
                    if (goal.isExpired || goal.isCompleted) ...[
                      const SizedBox(height: 10),
                      Text(
                        goal.isCompleted ? 'Completed' : 'Expired',
                        style: AppTextStyles.caption.copyWith(
                          color: goal.isCompleted
                              ? AppColors.tertiary
                              : AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Removed: _buildDebugValidationPanel (debug-only UI)

  // ── LeadWallet Card UI ───────────────────────────────────────
  Widget _buildWalletCard(UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    final isActive = user.isWalletActive;
    final isPending = user.isWalletPendingConsent;
    final balance = user.walletBalance;
    final nairaFormat = NumberFormat('#,##0.00', 'en_NG');

    void openWallet() {
      if (isActive) {
        Navigator.pushNamed(context, '/wallet');
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletActivationScreen()),
        );
      }
    }

    return GestureDetector(
      onTap: openWallet,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.walletBg, AppColors.primaryDark, AppColors.walletBgMid],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.walletGold, AppColors.accent2],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.walletGold.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LeadWallet',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isActive)
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, AppColors.walletGold],
                      ).createShader(bounds),
                      child: Text(
                        '₦${nairaFormat.format(balance)}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      isPending
                          ? 'Waiting for parent approval'
                          : 'Earn real cash rewards',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                isActive ? 'Open' : (isPending ? 'Status' : 'Activate'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
