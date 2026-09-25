import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/gratitude_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/mini_course_provider.dart';
import './supabase_service.dart';
import './badge_seen_store.dart';

// Extension methods to handle missing properties in models
extension UserModelExtension on UserModel {
  int get currentStreak => 0; // Default implementation
}

// Note: ChallengeModel doesn't have isCompleted property
// Challenges are tracked separately in user_challenge_participations table
class BadgeService {
  // Singleton pattern
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  // Initialize properties
  UserProvider? userProvider;
  GoalProvider? goalProvider;
  ChallengeProvider? challengeProvider;
  MiniCourseProvider? miniCourseProvider;
  GratitudeProvider? gratitudeProvider;

  // Supabase client
  final SupabaseClient _client = SupabaseService().client;

  // Initialize providers
  void initialize({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
    required MiniCourseProvider miniCourseProvider,
    GratitudeProvider? gratitudeProvider,
  }) {
    this.userProvider = userProvider;
    this.goalProvider = goalProvider;
    this.challengeProvider = challengeProvider;
    this.miniCourseProvider = miniCourseProvider;
    this.gratitudeProvider = gratitudeProvider;
  }

  // Check for all possible badge achievements.
  // Awards are server-only via run_my_badge_checks (client INSERT revoked).
  Future<List<BadgeModel>> checkForAchievements() async {
    if (userProvider == null) {
      debugPrint('BadgeService not initialized: userProvider is null');
      return [];
    }

    final beforeIds =
        userProvider!.badges.map((b) => b.id).whereType<String>().toSet();
    final hydratingSession = beforeIds.isEmpty;

    try {
      final result = await _client.rpc('run_my_badge_checks');
      debugPrint('🏆 run_my_badge_checks: $result');
    } catch (e) {
      debugPrint('❌ run_my_badge_checks failed: $e');
    }

    try {
      await userProvider!.loadUserBadges();
    } catch (e) {
      debugPrint('Badge reload failed: $e');
    }

    // Fresh browser / first login this session: existing awards are not new.
    if (hydratingSession) {
      debugPrint(
        '🏆 Skipping badge popups after hydrate '
        '(${userProvider!.badges.length} existing)',
      );
      return [];
    }

    final newlyEarnedBadges = userProvider!.badges
        .where((b) => b.id != null && !beforeIds.contains(b.id))
        .toList();

    debugPrint('🏆 Newly earned badges for popup: ${newlyEarnedBadges.length}');
    return newlyEarnedBadges;
  }

  // Legacy helper — awards are server-side now. Returns false (no client insert).
  Future<bool> saveBadgeToDatabase(BadgeModel badge) async {
    debugPrint(
        '⚠️ saveBadgeToDatabase is deprecated; awards go through run_my_badge_checks');
    return false;
  }

  // Check if user has completed 5 main goals
  Future<List<BadgeModel>> _checkGoalNinjaBadge() async {
    // Add null check for goalProvider
    if (goalProvider?.mainGoals == null) {
      debugPrint('🏆 BadgeService: goalProvider or mainGoals is null');
      return [];
    }

    final completedGoals =
        goalProvider!.mainGoals.where((goal) => goal.isCompleted).length;
    debugPrint('🏆 Goal Ninja check: $completedGoals/5 main goals completed');

    // Check database instead of SharedPreferences
    final userId = userProvider?.user?.id;
    if (userId == null) {
      debugPrint('🏆 BadgeService: user ID is null');
      return [];
    }

    // Check if badge already awarded in database
    try {
      final badgeDef = await _client
          .from('badges')
          .select('id')
          .eq('name', 'Goal Ninja')
          .maybeSingle();

      if (badgeDef != null) {
        final existingBadge = await _client
            .from('user_badges')
            .select()
            .eq('user_id', userId)
            .eq('badge_id', badgeDef['id'])
            .maybeSingle();

        if (existingBadge != null) {
          debugPrint('🏆 Goal Ninja already awarded');
          return [];
        }
      }
    } catch (e) {
      debugPrint('🏆 Error checking existing badge: $e');
    }

    if (completedGoals >= 5) {
      debugPrint('✅ Goal Ninja badge earned!');
      return [
        BadgeModel(
          id: 'goal_ninja_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          type: BadgeType.goalNinja,
          earnedDate: DateTime.now(),
          description: 'Completed 5 main goals',
        )
      ];
    }
    return [];
  }

  Future<List<BadgeModel>> _checkGratitudeStreakMilestones() async {
    if (gratitudeProvider == null) return [];
    final List<BadgeModel> earned = [];
    final streak = _computeGratitudeStreakDays(gratitudeProvider!);
    final List<Map<String, dynamic>> milestones = [
      {'days': 1, 'name': 'Seed of Thanks'},
      {'days': 3, 'name': 'Gratitude Leaf'},
      {'days': 7, 'name': 'Blossom of Joy'},
      {'days': 14, 'name': 'Ray of Appreciation'},
      {'days': 30, 'name': 'Tree of Thanks'},
      {'days': 60, 'name': 'Flame of Gratitude'},
      {'days': 100, 'name': 'World of Thanks'},
      {'days': 180, 'name': 'Peaceful Heart'},
      {'days': 365, 'name': 'Eternal Gratitude'},
    ];
    for (final m in milestones) {
      final int d = m['days'];
      final String badgeName = m['name'];
      // Check database for existing badge
      final userId = userProvider?.user?.id;
      if (userId == null) continue;

      final hasBadge = await _hasUserBadge(userId, badgeName);

      if (streak >= d && !hasBadge) {
        final display = await _awardByName(badgeName,
            fallbackType: BadgeType.streakMaster,
            description: 'Completed a $d-day gratitude streak');
        if (display != null) {
          earned.add(display);
        }
      }
    }
    return earned;
  }

  Future<List<BadgeModel>> _checkGoalsCompletedMilestones() async {
    final List<BadgeModel> earned = [];
    int completed = 0;
    try {
      final uid = userProvider?.user?.id;
      if (uid == null) return earned;

      // Query DB directly to get accurate counts — NOT from local in-memory list.
      // The local list is fetched with no date filter and can contain thousands of
      // historical goals (including duplicates from the AI generation bug), which
      // would cause users to falsely earn milestone badges.
      final dailyRows = await _client
          .from('goal_completions') // source of truth for completed daily goals
          .select('id')
          .eq('user_id', uid);
      completed += (dailyRows as List).length;

      // Count completed main goals from the DB
      final mainRows = await _client
          .from('main_goals')
          .select('id')
          .eq('user_id', uid)
          .eq('status', 'completed');
      completed += (mainRows as List).length;

      debugPrint(
          'BadgeService._checkGoalsCompletedMilestones: DB count = $completed');
    } catch (e) {
      debugPrint('BadgeService._checkGoalsCompletedMilestones: DB query failed ($e), falling back to 0');
      return earned; // Fail safe: award no badges if we can't get accurate count
    }

    final List<Map<String, dynamic>> milestones = [
      {'count': 1, 'name': 'Starter Vision'},
      {'count': 3, 'name': 'Sharpshooter'},
      {'count': 5, 'name': 'Step Climber'},
      {'count': 10, 'name': 'Achiever Medal'},
      {'count': 25, 'name': 'Goal Voyager'},
      {'count': 50, 'name': 'Peak Reacher'},
      {'count': 100, 'name': 'Master Planner'},
      {'count': 250, 'name': 'Visionary Eagle'},
      {'count': 500, 'name': 'Legacy Builder'},
      {'count': 1000, 'name': 'Infinite Dreamer'},
    ];

    final userId = userProvider?.user?.id;
    if (userId == null) return earned;

    // Award EVERY unearned milestone the user qualifies for (ascending), not
    // just the highest. This fixes retroactive catch-up where a user with many
    // completions previously only received the top tier and skipped the rest.
    for (final m in milestones) {
      final int c = m['count'];
      final String badgeName = m['name'];

      // Milestones are ascending; once the count falls short, nothing higher qualifies.
      if (completed < c) break;

      final hasBadge = await _hasUserBadge(userId, badgeName);
      if (!hasBadge) {
        final display = await _awardByName(badgeName,
            fallbackType: BadgeType.goalNinja,
            description: 'Completed $c goals');
        if (display != null) {
          earned.add(display);
        }
      }
    }
    return earned;
  }

  Future<List<BadgeModel>> _checkMiniCoursesCompletedMilestones() async {
    final List<BadgeModel> earned = [];
    try {
      final uid = userProvider?.user?.id;
      if (uid == null) return earned;

      // Count completed courses from server for bulletproof retroactive detection
      final rows = await _client
          .from('user_course_progress')
          .select('id')
          .eq('user_id', uid)
          .eq('completed', true)
          .gte('score', 70);
      final completedCourses = (rows as List).length;

      final List<Map<String, dynamic>> milestones = [
        {'count': 1, 'name': 'Apprentice Learner'},
        {'count': 3, 'name': 'Curious Mind'},
        {'count': 5, 'name': 'Scholar Cap'},
        {'count': 10, 'name': 'Knowledge Seeker'},
        {'count': 25, 'name': 'Critical Thinker'},
        {'count': 50, 'name': 'Wisdom Keeper'},
        {'count': 100, 'name': 'Sage of Learning'},
        {'count': 250, 'name': 'Mind Innovator'},
        {'count': 500, 'name': 'Knowledge Dragon'},
        {'count': 1000, 'name': 'Eternal Master'},
      ];

      // Award EVERY unearned mini-course milestone the user qualifies for.
      for (final m in milestones) {
        final int c = m['count'];
        final String badgeName = m['name'];

        // Ascending list: stop once the count no longer qualifies.
        if (completedCourses < c) break;

        final hasBadge = await _hasUserBadge(uid, badgeName);
        if (!hasBadge) {
          final display = await _awardByName(badgeName,
              fallbackType: BadgeType.knowledgeSeeker,
              description: 'Completed $c mini-courses');
          if (display != null) {
            earned.add(display);
          }
        }
      }
    } catch (e) {
      debugPrint(
          'BadgeService: _checkMiniCoursesCompletedMilestones failed: $e');
    }
    return earned;
  }

  // Attempts to award a badge by its server definition name and return a display BadgeModel
  Future<BadgeModel?> _awardByName(String name,
      {required BadgeType fallbackType, String? description}) async {
    try {
      // Client inserts revoked — awards happen in run_my_badge_checks.
      final userId = userProvider?.user?.id;
      if (userId == null) return null;
      final already = await _hasUserBadge(userId, name);
      if (!already) return null;

      final def =
          await _client.from('badges').select().eq('name', name).maybeSingle();
      return BadgeModel(
        id: def?['id']?.toString() ?? name,
        userId: userId,
        type: fallbackType,
        earnedDate: DateTime.now(),
        description: description ?? def?['description'],
      );
    } catch (e) {
      debugPrint('BadgeService: _awardByName failed for "$name": $e');
      return null;
    }
  }

  // REMOVED: SharedPreferences badge tracking - now using database-only checks via user_badges table

  /// Helper method to check if user already has a specific badge in database
  Future<bool> _hasUserBadge(String userId, String badgeName) async {
    try {
      final response = await _client
          .from('user_badges')
          .select('id, badge_id')
          .eq('user_id', userId);

      if (response.isEmpty) return false;

      // Get all badge IDs user has
      final userBadgeIds =
          (response as List).map((ub) => ub['badge_id'] as String).toList();

      // Check if any of these badges match the name we're looking for
      final badgeCheck = await _client
          .from('badges')
          .select('id')
          .eq('name', badgeName)
          .inFilter('id', userBadgeIds);

      return (badgeCheck as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user badge "$badgeName": $e');
      return false; // Assume not awarded if check fails
    }
  }

  // Check if user has won 3 challenges
  Future<List<BadgeModel>> _checkChallengeChampionBadge() async {
    // Check database for existing badge
    final userId = userProvider?.user?.id;
    if (userId == null) return [];

    try {
      // Query user_challenges table for completed challenges
      final challengeResponse = await _client
          .from('user_challenges')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true);

      final completedChallenges = (challengeResponse as List).length;
      debugPrint(
          '🏆 Challenge Champion check: $completedChallenges/3 challenges completed');

      final hasChallengeBadge =
          await _hasUserBadge(userId, 'Challenge Champion');

      if (completedChallenges >= 3 && !hasChallengeBadge) {
        return [
          BadgeModel(
            id: 'challenge_champion_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            type: BadgeType.challengeChampion,
            earnedDate: DateTime.now(),
            description: 'Won 3 challenges',
          )
        ];
      }
    } catch (e) {
      debugPrint('Error checking challenge badges: $e');
    }

    return [];
  }

  // Check if user has maintained a 5-day streak
  Future<List<BadgeModel>> _checkStreakMasterBadge() async {
    // Prefer gratitude-based real streak if provider available
    int currentStreak = 0;
    try {
      if (gratitudeProvider != null) {
        currentStreak = _computeGratitudeStreakDays(gratitudeProvider!);
      } else {
        // Fallback to user model placeholder if no gratitude provider
        currentStreak = userProvider?.user?.currentStreak ?? 0;
      }
    } catch (e) {
      debugPrint('BadgeService: streak computation failed: $e');
      currentStreak = 0;
    }

    // Check database for existing badge
    final userId = userProvider?.user?.id;
    if (userId == null) return [];

    final hasStreakBadge = await _hasUserBadge(userId, 'Streak Master');

    if (currentStreak >= 5 && !hasStreakBadge) {
      return [
        BadgeModel(
          id: 'streak_master_${DateTime.now().millisecondsSinceEpoch}',
          userId: userProvider?.user?.id ?? 'unknown_user',
          type: BadgeType.streakMaster,
          earnedDate: DateTime.now(),
          description: 'Maintained a 5-day streak',
        )
      ];
    }
    return [];
  }

  // Compute consecutive gratitude streak days ending today
  int _computeGratitudeStreakDays(GratitudeProvider g) {
    final entries = g.entries;
    if (entries.isEmpty) return 0;
    // Normalize to set of day strings (yyyy-mm-dd)
    final Set<String> days = entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day)
            .toIso8601String()
            .substring(0, 10))
        .toSet();
    int streak = 0;
    DateTime cursor = DateTime.now();
    while (true) {
      final d = DateTime(cursor.year, cursor.month, cursor.day)
          .toIso8601String()
          .substring(0, 10);
      if (days.contains(d)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // Check if user has completed 10 health goals
  Future<List<BadgeModel>> _checkHealthyHabitHeroBadge() async {
    final userId = userProvider?.user?.id;
    if (userId == null) return [];

    try {
      // Query DB directly to avoid reading the inflated local in-memory list
      final rows = await _client
          .from('daily_goals')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .eq('category', 'health');
      final healthGoals = (rows as List).length;

      final hasHealthBadge = await _hasUserBadge(userId, 'Healthy Habit Hero');

      if (healthGoals >= 10 && !hasHealthBadge) {
        return [
          BadgeModel(
            id: 'healthy_habit_hero_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            type: BadgeType.healthyHabitHero,
            earnedDate: DateTime.now(),
            description: 'Completed 10 health goals',
          )
        ];
      }
    } catch (e) {
      debugPrint('BadgeService: _checkHealthyHabitHeroBadge DB query failed: $e');
    }
    return [];
  }

  // Check if user has completed 10 social goals
  Future<List<BadgeModel>> _checkSocialButterflyBadge() async {
    final userId = userProvider?.user?.id;
    if (userId == null) return [];

    try {
      // Query DB directly to avoid reading the inflated local in-memory list
      final rows = await _client
          .from('daily_goals')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .eq('category', 'social');
      final socialGoals = (rows as List).length;

      final hasSocialBadge = await _hasUserBadge(userId, 'Social Butterfly');

      if (socialGoals >= 10 && !hasSocialBadge) {
        return [
          BadgeModel(
            id: 'social_butterfly_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            type: BadgeType.socialButterfly,
            earnedDate: DateTime.now(),
            description: 'Completed 10 social goals',
          )
        ];
      }
    } catch (e) {
      debugPrint('BadgeService: _checkSocialButterflyBadge DB query failed: $e');
    }
    return [];
  }

  // Check if user has completed 10 academic goals
  Future<List<BadgeModel>> _checkAcademicAceBadge() async {
    final userId = userProvider?.user?.id;
    if (userId == null) return [];

    try {
      // Query DB directly to avoid reading the inflated local in-memory list
      final rows = await _client
          .from('daily_goals')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .eq('category', 'academic');
      final academicGoals = (rows as List).length;

      final hasAcademicBadge = await _hasUserBadge(userId, 'Academic Ace');

      if (academicGoals >= 10 && !hasAcademicBadge) {
        return [
          BadgeModel(
            id: 'academic_ace_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            type: BadgeType.academicAce,
            earnedDate: DateTime.now(),
            description: 'Completed 10 academic goals',
          )
        ];
      }
    } catch (e) {
      debugPrint('BadgeService: _checkAcademicAceBadge DB query failed: $e');
    }
    return [];
  }


  // Check if user has had 10 conversations with Questor
  Future<List<BadgeModel>> _checkQuestorFriendBadge() async {
    // Check if userProvider is initialized
    if (userProvider == null) {
      debugPrint('BadgeService: userProvider is null');
      return [];
    }
    try {
      final uid = userProvider!.user?.id;
      if (uid == null) return [];

      // Prefer counting conversations table; fallback to messages from user
      int count = 0;
      try {
        final convRows = await _client
            .from('ai_coach_conversations')
            .select('id')
            .eq('user_id', uid);
        count = (convRows as List).length;
      } catch (e) {
        debugPrint(
            'Questor count via conversations failed, falling back to messages: $e');
        try {
          final msgRows = await _client
              .from('ai_coach_messages')
              .select('id, sender')
              .eq('user_id', uid)
              .eq('sender', 'user');
          count = (msgRows as List).length;
        } catch (e2) {
          debugPrint('Questor count via messages also failed: $e2');
          count = 0;
        }
      }

      // Ensure not already awarded in database
      try {
        final def = await _client
            .from('badges')
            .select('id')
            .eq('name', 'Questor Friend')
            .maybeSingle();
        if (def != null) {
          final existing = await _client
              .from('user_badges')
              .select('id')
              .eq('user_id', uid)
              .eq('badge_id', def['id'])
              .maybeSingle();
          if (existing != null) return [];
        }
      } catch (_) {}

      if (count >= 10) {
        return [
          BadgeModel(
            id: 'questor_friend_${DateTime.now().millisecondsSinceEpoch}',
            userId: uid,
            type: BadgeType.questorFriend,
            earnedDate: DateTime.now(),
            description: 'Had 10 conversations with Questor',
          )
        ];
      }
      return [];
    } catch (e) {
      debugPrint('BadgeService: _checkQuestorFriendBadge failed: $e');
      return [];
    }
  }

  // Check if user has made 5 posts on the Victory Wall
  Future<List<BadgeModel>> _checkVictoryVeteranBadge() async {
    // Check if userProvider is initialized
    if (userProvider == null) {
      debugPrint('BadgeService: userProvider is null');
      return [];
    }
    try {
      final uid = userProvider!.user?.id;
      if (uid == null) return [];

      int count = 0;
      try {
        final rows =
            await _client.from('posts').select('id').eq('user_id', uid);
        count = (rows as List).length;
      } catch (e) {
        debugPrint('Victory post count failed: $e');
        count = 0;
      }

      if (count < 5) return [];

      // Use unified award path to avoid UI popups without DB persistence
      final display = await _awardByName(
        'Victory Veteran',
        fallbackType: BadgeType.victoryVeteran,
        description: 'Made 5 posts on the Victory Wall',
      );
      if (display != null) {
        return [display];
      }
      // If definition is missing or award failed, avoid repeated popups
      debugPrint(
          '⚠️ Victory Veteran definition missing or already awarded; suppressing UI.');
      return [];
    } catch (e) {
      debugPrint('BadgeService: _checkVictoryVeteranBadge failed: $e');
      return [];
    }
  }

  // Track Questor conversation
  Future<void> trackQuestorConversation() async {
    // No-op: server is the source of truth via ai_coach_conversations/messages
    // Kept for backward compatibility if called by existing flows
  }

  // Track Victory Wall post
  Future<void> trackVictoryPost() async {
    // No-op: server is the source of truth via posts table
    // Kept for backward compatibility if called by existing flows
  }

  // Show badge earned dialog
  void showBadgeEarnedDialog(BuildContext context, BadgeModel badge) {
    final seenKey = (badge.id.isNotEmpty ? badge.id : badge.name);
    BadgeSeenStore.hasSeen(badge.userId, seenKey).then((seen) {
      if (seen) return;
      BadgeSeenStore.markSeen(badge.userId, seenKey);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Badge Earned!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeImage(
                badge: badge,
                size: 100,
              ),
              const SizedBox(height: 16),
              Text(
                badge.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.description ?? badge.defaultDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 12),
              // Rewards line: +coins, +XP from server definition (if available)
              FutureBuilder<Map<String, dynamic>?>(
                future: _client
                    .from('badges')
                    .select('xp_reward, coin_reward')
                    .eq('name', badge.name)
                    .maybeSingle(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  final data = snapshot.data;
                  if (data == null) return const SizedBox.shrink();
                  final int xp = (data['xp_reward'] as int?) ?? 0;
                  final double coins =
                      (data['coin_reward'] as num?)?.toDouble() ?? 0.0;
                  if (xp <= 0 && coins <= 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (coins > 0) ...[
                          const Icon(Icons.monetization_on_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                              '+${coins.toStringAsFixed(coins.truncateToDouble() == coins ? 0 : 1)} coins',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                        if (coins > 0 && xp > 0) const SizedBox(width: 16),
                        if (xp > 0) ...[
                          const Icon(Icons.bolt_rounded,
                              color: Colors.deepPurple, size: 18),
                          const SizedBox(width: 6),
                          Text('+$xp XP',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    });
  }
}
