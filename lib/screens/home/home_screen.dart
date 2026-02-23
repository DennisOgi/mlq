import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/badge_service.dart' as badge_service;

import '../onboarding/goal_onboarding_screen.dart';
import '../goals/daily_goal_grid_screen.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../widgets/gratitude_slider.dart';
import '../gratitude/gratitude_jar_screen.dart';
import '../mini_courses/mini_course_detail_screen.dart';
import '../mini_courses/community_course_detail_screen.dart';
import '../mini_courses/school_course_viewer_screen.dart';
import '../../services/community_course_service.dart';
import '../../providers/school_course_provider.dart';
import '../../models/school_course_model.dart';
import '../../widgets/advanced_floating_questor_widget.dart';
import '../../widgets/trial_countdown_banner.dart';
import '../../widgets/christmas_decorations.dart';
import '../../services/subscription_service.dart';
// Removed debug-only services: push notification test and secure goal debug actions
import '../../services/challenge_evaluator.dart';
import '../../widgets/goal_completion_dialog.dart';
import '../goals/goal_history_screen.dart';

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

      // Show feature announcements for new features (only once per feature)
      _showFeatureAnnouncements();
    });
  }

  Future<void> _showFeatureAnnouncements() async {
    if (!mounted) return;
    // Show Communities feature announcement (shows only once)
    await FeatureAnnouncements.showCommunitiesAnnouncement(context);
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 72,
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFFFD700), width: 2),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
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
                  const SizedBox(width: 6),
                  Text(
                    'My Leadership Quest',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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

  // Removed: _triggerTestNotification debug method

  // Build the gratitude jar floating action button
  Widget _buildGratitudeJarButton() {
    return Padding(
      padding: const EdgeInsets.only(
          bottom: 80.0), // Move button down closer to navigation bar
      child: Animate(
        effects: [
          // Create a true bouncing effect with multiple effects
          // First bounce up quickly
          MoveEffect(
            curve: Curves.easeOut,
            duration: 300.ms,
            begin: const Offset(0, 0),
            end: const Offset(0, -15),
          ),
          // Then fall down with a slight overshoot
          MoveEffect(
            curve: Curves.elasticIn,
            duration: 500.ms,
            begin: const Offset(0, -15),
            end: const Offset(0, 2),
          ),
          // Finally settle back to original position
          MoveEffect(
            curve: Curves.bounceOut,
            duration: 200.ms,
            begin: const Offset(0, 2),
            end: const Offset(0, 0),
          ),
          // Add a slight scale effect to enhance the bounce
          ScaleEffect(
            curve: Curves.easeInOut,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.1, 0.9),
            duration: 300.ms,
          ),
          ScaleEffect(
            curve: Curves.elasticOut,
            begin: const Offset(1.1, 0.9),
            end: const Offset(1.0, 1.0),
            duration: 700.ms,
            delay: 300.ms,
          ),
        ],
        // Repeat the animation with a pause between bounces
        onPlay: (controller) => controller.repeat(period: 2500.ms),
        child: FloatingActionButton(
          onPressed: () {
            // Navigate to gratitude jar screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GratitudeJarScreen(),
              ),
            );
          },
          heroTag: 'gratitude_fab',
          backgroundColor: AppColors.accent1,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          // Maintenance notices banner
          const MaintenanceBanner(),
          // Trial countdown banner (shows only in last 3 days)
          FutureBuilder<Map<String, dynamic>>(
            future: SubscriptionService().getTrialStatus(user?.id ?? ''),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!['isOnTrial'] == true) {
                final daysRemaining = snapshot.data!['daysRemaining'] as int;
                if (daysRemaining <= 3) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TrialCountdownBanner(daysRemaining: daysRemaining),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          // User profile card with stats
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            child: Card(
              elevation: 12,
              shadowColor: ChristmasBanner.shouldShow
                  ? const Color(0xFF1E5631).withOpacity(0.4)
                  : AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
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
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.92),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ChristmasBanner.shouldShow
                            ? const Color(0xFFFFD700)
                                .withOpacity(0.4) // Gold border
                            : Colors.white.withOpacity(0.15),
                        width: ChristmasBanner.shouldShow ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ChristmasBanner.shouldShow
                              ? const Color(0xFFC41E3A)
                                  .withOpacity(0.2) // Christmas red glow
                              : AppColors.secondary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
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
                                          AppColors.secondary,
                                          AppColors.tertiary,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ChristmasBanner.shouldShow
                                        ? const Color(0xFFFFD700)
                                            .withOpacity(0.4)
                                        : AppColors.secondary.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    user?.name.isNotEmpty == true
                                        ? user!.name[0].toUpperCase()
                                        : 'U',
                                    style: AppTextStyles.heading1.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ChristmasBanner.shouldShow
                                        ? '🎄 Merry Christmas, ${user?.name ?? 'Leader'}!'
                                        : 'Hello, ${user?.name ?? 'Leader'}!',
                                    style: AppTextStyles.heading3.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ChristmasBanner.shouldShow
                                        ? _buildChristmasSubtitle()
                                        : _buildMotivationalSubtitle(context),
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
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
                                      Icons.star, 'XP POINTS', Colors.amber),
                                  _buildStatItemLoading(Icons.monetization_on,
                                      'COINS', Colors.orangeAccent),
                                  _buildStatItemLoading(Icons.emoji_events,
                                      'BADGES', Colors.purpleAccent),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // XP Points - use direct provider reference for consistent updates
                                _buildStatItem(
                                  icon: Icons.star,
                                  value: '${currentUser.xp}',
                                  label: 'LIFETIME XP',
                                  color: Colors.amber,
                                  isError: false,
                                  onTap: () {
                                    // Navigate to leaderboard when XP is tapped
                                    Navigator.pushNamed(
                                        context, '/leaderboard');
                                  },
                                ),
                                // Coins - with proper formatting
                                _buildStatItem(
                                  icon: Icons.monetization_on,
                                  value: currentUser.coins >= 1000
                                      ? '${(currentUser.coins / 1000).toStringAsFixed(1)}K'
                                      : currentUser.coins.toStringAsFixed(1),
                                  label: 'COINS',
                                  color: Colors.orangeAccent,
                                  isError: false,
                                  onTap: () {
                                    // Navigate to coin history when coins are tapped
                                    Navigator.pushNamed(
                                        context, '/coin-history');
                                  },
                                ),

                                // Badges - get badge count from UserProvider's badges list
                                _buildStatItem(
                                  icon: Icons.emoji_events,
                                  value: '${userProvider.badges.length}',
                                  label: 'BADGES',
                                  color: Colors.purpleAccent,
                                  isError: false,
                                  onTap: () {
                                    // Navigate to badges screen when tapped
                                    Navigator.pushNamed(context, '/profile');
                                  },
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
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: 24),

          // Main goals section with tabs
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            color: AppColors.secondary, // gold flag icon
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'My Main Goals',
                            style: AppTextStyles.sectionHeader.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
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
                            backgroundColor:
                                AppColors.secondary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(
                            Icons.history,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          label: Text(
                            'History',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.secondary,
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
              .fadeIn(duration: 700.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 24),

          // Weekly progress graph card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: AppColors.tertiary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Progress',
                        style: AppTextStyles.sectionHeader.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const WeeklyProgressGraph(),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 400.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 24),

          // Gratitude slider
          const GratitudeSlider(),
          const SizedBox(height: 24),

          // Mini-courses section card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        color: AppColors.social,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mini-Courses',
                        style: AppTextStyles.sectionHeader.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMiniCoursesCarousel(),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 900.ms, delay: 600.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 48), // Extra space for floating button

          // Debug validation panel removed
        ],
      ),
    );
  }

  Widget _buildEmptyGoalsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Show icon for empty state
          const Icon(
            Icons.flag_outlined,
            size: 100,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Main Goals Yet',
            style:
                AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Set your first main goal to start your leadership journey!',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMiniCoursesCarousel() {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final state = miniCourseProvider.dailyState;
    final todayCourses = miniCourseProvider.todayCourses;
    final communityCourses = miniCourseProvider.communityCourses;

    // Get the color and icon based on the course topic
    Color getCourseColor(String topic) {
      // Leadership topics with varied colors
      if (topic.contains('Leadership'))
        return const Color(0xFF6A1B9A); // Deep Purple
      if (topic.contains('Personal Growth'))
        return const Color(0xFF00897B); // Teal
      if (topic.contains('Confidence'))
        return const Color(0xFFE65100); // Deep Orange
      if (topic.contains('Communication'))
        return const Color(0xFF1565C0); // Blue
      if (topic.contains('Motivation')) return const Color(0xFFC62828); // Red
      if (topic.contains('Emotional Intelligence'))
        return const Color(0xFFAD1457); // Pink
      if (topic.contains('Self-Discipline'))
        return const Color(0xFF4527A0); // Deep Purple
      if (topic.contains('Mindset')) return const Color(0xFF00695C); // Teal
      if (topic.contains('Productivity'))
        return const Color(0xFFEF6C00); // Orange
      if (topic.contains('Creativity')) return const Color(0xFFD81B60); // Pink
      if (topic.contains('Goal Setting'))
        return const Color(0xFF283593); // Indigo
      if (topic.contains('Decision Making'))
        return const Color(0xFF2E7D32); // Green
      if (topic.contains('Resilience'))
        return const Color(0xFF6A1B9A); // Purple
      if (topic.contains('Problem Solving'))
        return const Color(0xFF0277BD); // Light Blue
      if (topic.contains('Influence')) return const Color(0xFF5D4037); // Brown
      if (topic.contains('Time Management'))
        return const Color(0xFF00838F); // Cyan
      if (topic.contains('Conflict Resolution'))
        return const Color(0xFF7B1FA2); // Purple
      if (topic.contains('Teamwork')) return const Color(0xFF00695C); // Teal
      return AppColors.primary; // Default
    }

    IconData getCourseIcon(String topic) {
      // Leadership topic icons
      if (topic.contains('Leadership')) return Icons.people;
      if (topic.contains('Personal Growth')) return Icons.trending_up;
      if (topic.contains('Confidence')) return Icons.stars;
      if (topic.contains('Communication')) return Icons.chat_bubble;
      if (topic.contains('Motivation')) return Icons.bolt;
      if (topic.contains('Emotional Intelligence')) return Icons.favorite;
      if (topic.contains('Self-Discipline')) return Icons.self_improvement;
      if (topic.contains('Mindset')) return Icons.psychology;
      if (topic.contains('Productivity')) return Icons.speed;
      if (topic.contains('Creativity')) return Icons.brush;
      if (topic.contains('Goal Setting')) return Icons.flag;
      if (topic.contains('Decision Making')) return Icons.how_to_vote;
      if (topic.contains('Resilience')) return Icons.shield;
      if (topic.contains('Problem Solving')) return Icons.lightbulb;
      if (topic.contains('Influence')) return Icons.campaign;
      if (topic.contains('Time Management')) return Icons.schedule;
      if (topic.contains('Conflict Resolution')) return Icons.handshake;
      if (topic.contains('Teamwork')) return Icons.group_work;
      return Icons.school; // Default
    }

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
      final isNetworkError = errorMessage.toLowerCase().contains('internet') ||
          errorMessage.toLowerCase().contains('network') ||
          errorMessage.toLowerCase().contains('connection');

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

    // Calculate total items: school courses + community courses + global courses
    final totalItems =
        schoolCourses.length + communityCourses.length + todayCourses.length;

    // Show courses carousel
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // First show school courses (branded with school logo)
          if (index < schoolCourses.length) {
            return _buildSchoolCourseCard(
                schoolCourses[index], index, schoolProvider);
          }

          // Then show community courses (branded)
          final communityIndex = index - schoolCourses.length;
          if (communityIndex < communityCourses.length) {
            return _buildCommunityCourseCard(
                communityCourses[communityIndex], communityIndex);
          }

          // Global course
          final globalIndex =
              index - schoolCourses.length - communityCourses.length;
          final course = todayCourses[globalIndex];
          final courseColor = getCourseColor(course.topic);
          final courseIcon = getCourseIcon(course.topic);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MiniCourseDetailScreen(courseId: course.id),
                ),
              );
            },
            child: Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course header with gradient
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          courseColor,
                          courseColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            courseIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            course.topic,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Course content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                style: AppTextStyles.bodyBold.copyWith(
                                  fontSize: 14,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          QuestButton(
                            text: (course.status == MiniCourseStatus.completed)
                                ? 'Completed ✓'
                                : 'Start Course',
                            type: (course.status == MiniCourseStatus.completed)
                                ? QuestButtonType.secondary
                                : QuestButtonType.primary,
                            height: 44,
                            onPressed: (course.status ==
                                    MiniCourseStatus.completed)
                                ? null // Disable button if completed
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MiniCourseDetailScreen(
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
        },
      ),
    );
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

  String _buildChristmasSubtitle() {
    final now = DateTime.now();
    final christmas = DateTime(now.year, 12, 25);
    final newYear = DateTime(now.year + (now.month == 12 ? 1 : 0), 1, 1);

    // Christmas Day
    if (now.month == 12 && now.day == 25) {
      return '🎁 Merry Christmas! Enjoy this special day!';
    }

    // New Year's Day
    if (now.month == 1 && now.day == 1) {
      return '🎆 Happy New Year! A fresh start awaits!';
    }

    // Days until Christmas (before Dec 25)
    if (now.month == 12 && now.day < 25) {
      final daysUntil = christmas.difference(now).inDays;
      if (daysUntil == 1) {
        return '🎅 Christmas Eve! The magic is almost here!';
      }
      return '🎄 $daysUntil days until Christmas! Keep spreading joy!';
    }

    // After Christmas, before New Year
    if (now.month == 12 && now.day > 25) {
      final daysUntil = newYear.difference(now).inDays;
      return '✨ $daysUntil days until the New Year! Finish strong!';
    }

    // January (New Year period)
    if (now.month == 1 && now.day <= 12) {
      return '🌟 New year, new goals! Make this year amazing!';
    }

    return 'Wishing you a wonderful holiday season! 🎄';
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

                    // Add coins for setting a goal (0.5 coins)
                    userProvider.addCoins(0.5);

                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Main goal added! (+0.5 coins)',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have 3 active main goals.',
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
                            await userProvider.addCoins(0.5);
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

    return Column(
      children: [
        // Tab Bar
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

        // Tab content
        SizedBox(
          height: 330, // Increased height to accommodate all content
          child: TabBarView(
            controller: _goalTabController,
            physics:
                const AlwaysScrollableScrollPhysics(), // Make TabBarView scrollable
            children: [
              // Academic goals tab
              academicGoals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No academic goals yet. Add one to get started!',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            QuestButton(
                              text: 'Add Academic Main Goal',
                              icon: Icons.add,
                              type: QuestButtonType.primary,
                              onPressed: () => _showCreateMainGoalDialog(
                                  GoalCategory.academic),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics:
                          const ClampingScrollPhysics(), // Allow scrolling to propagate to parent
                      child: Column(
                        children: academicGoals
                            .map((goal) => GoalCard(
                                  goal: goal,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DailyGoalGridScreen(
                                          mainGoal: goal,
                                        ),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    // Show edit goal dialog
                                  },
                                ))
                            .toList(),
                      ),
                    ),

              // Social goals tab
              socialGoals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No social goals yet. Add one to get started!',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            QuestButton(
                              text: 'Add Social Main Goal',
                              icon: Icons.add,
                              type: QuestButtonType.primary,
                              onPressed: () => _showCreateMainGoalDialog(
                                  GoalCategory.social),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics:
                          const ClampingScrollPhysics(), // Allow scrolling to propagate to parent
                      child: Column(
                        children: socialGoals
                            .map((goal) => GoalCard(
                                  goal: goal,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DailyGoalGridScreen(
                                          mainGoal: goal,
                                        ),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    // Show edit goal dialog
                                  },
                                ))
                            .toList(),
                      ),
                    ),

              // Health goals tab
              healthGoals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No health goals yet. Add one to get started!',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            QuestButton(
                              text: 'Add Health Main Goal',
                              icon: Icons.add,
                              type: QuestButtonType.primary,
                              onPressed: () => _showCreateMainGoalDialog(
                                  GoalCategory.health),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics:
                          const ClampingScrollPhysics(), // Allow scrolling to propagate to parent
                      child: Column(
                        children: healthGoals
                            .map((goal) => GoalCard(
                                  goal: goal,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DailyGoalGridScreen(
                                          mainGoal: goal,
                                        ),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    // Show edit goal dialog
                                  },
                                ))
                            .toList(),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // Removed: _buildDebugValidationPanel (debug-only UI)
}
