import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class VictoryWallService {
  static const VictoryWallService _instance = VictoryWallService._internal();
  factory VictoryWallService() => _instance;
  static VictoryWallService get instance => _instance;
  
  const VictoryWallService._internal();

  /// Automatically create a victory post when a user completes a goal
  static Future<void> createGoalCompletionPost({
    required UserProvider userProvider,
    required PostProvider postProvider,
    required String goalTitle,
    required String goalCategory,
    required int xpEarned,
  }) async {
    final user = userProvider.user;
    if (user == null) return;

    final content = _generateGoalCompletionMessage(
      goalTitle: goalTitle,
      category: goalCategory,
      xpEarned: xpEarned,
    );

    final post = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      final result = await postProvider.addPost(post);
      if (result['success']) {
        debugPrint('Auto-created victory post for goal completion: $goalTitle');
      }
    } catch (e) {
      debugPrint('Error creating goal completion post: $e');
    }
  }

  /// Automatically create a victory post when a user earns a badge
  static Future<void> createBadgeEarnedPost({
    required UserProvider userProvider,
    required PostProvider postProvider,
    required BadgeModel badge,
  }) async {
    final user = userProvider.user;
    if (user == null) return;

    final content = _generateBadgeEarnedMessage(badge);

    final post = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      final result = await postProvider.addPost(post);
      if (result['success']) {
        debugPrint('Auto-created victory post for badge earned: ${badge.type}');
      }
    } catch (e) {
      debugPrint('Error creating badge earned post: $e');
    }
  }

  /// Automatically create a victory post when a user completes a challenge
  static Future<void> createChallengeCompletionPost({
    required UserProvider userProvider,
    required PostProvider postProvider,
    required String challengeTitle,
    required int coinsEarned,
  }) async {
    final user = userProvider.user;
    if (user == null) return;

    final content = _generateChallengeCompletionMessage(
      challengeTitle: challengeTitle,
      coinsEarned: coinsEarned,
    );

    final post = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      final result = await postProvider.addPost(post);
      if (result['success']) {
        debugPrint('Auto-created victory post for challenge completion: $challengeTitle');
      }
    } catch (e) {
      debugPrint('Error creating challenge completion post: $e');
    }
  }

  /// Generate a personalized message for goal completion
  static String _generateGoalCompletionMessage({
    required String goalTitle,
    required String category,
    required int xpEarned,
  }) {
    final List<String> templates = [
      "Just crushed my $category goal: '$goalTitle'! 🎯 Earned $xpEarned XP and feeling unstoppable! 💪",
      "Victory achieved! ✨ Completed '$goalTitle' in my $category journey. $xpEarned XP closer to my dreams! 🌟",
      "Another milestone reached! 🚀 '$goalTitle' is done and I'm $xpEarned XP stronger! Who's next? 😎",
      "Success tastes sweet! 🍯 Just finished '$goalTitle' and earned $xpEarned XP. Leadership level up! 📈",
      "Goal conquered! ⚡ '$goalTitle' is officially complete. $xpEarned XP added to my leadership journey! 🏆",
    ];

    final random = DateTime.now().millisecondsSinceEpoch % templates.length;
    return templates[random];
  }

  /// Generate a personalized message for badge earned
  static String _generateBadgeEarnedMessage(BadgeModel badge) {
    final badgeName = _getBadgeDisplayName(badge.type);
    
    final List<String> templates = [
      "New badge unlocked! 🏅 Just earned the '$badgeName' badge! My leadership journey keeps growing! 🌱",
      "Badge alert! 🚨 '$badgeName' is now mine! Feeling proud of this achievement! ✨",
      "Another badge for the collection! 🎖️ '$badgeName' earned through dedication and hard work! 💪",
      "Leadership milestone reached! 🎯 The '$badgeName' badge is officially mine! Onward and upward! 🚀",
      "Badge earned! 🏆 '$badgeName' added to my victory wall. Every step counts in this journey! 👑",
    ];

    final random = DateTime.now().millisecondsSinceEpoch % templates.length;
    return templates[random];
  }

  /// Generate a personalized message for challenge completion
  static String _generateChallengeCompletionMessage({
    required String challengeTitle,
    required int coinsEarned,
  }) {
    final List<String> templates = [
      "Challenge conquered! 💥 Just completed '$challengeTitle' and earned $coinsEarned coins! 🪙",
      "Victory is mine! 🏆 '$challengeTitle' challenge complete! $coinsEarned coins richer and wiser! ✨",
      "Challenge accepted and CRUSHED! ⚡ '$challengeTitle' done, $coinsEarned coins earned! 💪",
      "Another challenge in the books! 📚 '$challengeTitle' complete with $coinsEarned coins to show for it! 🌟",
      "Challenge mastered! 🎯 '$challengeTitle' is finished and I'm $coinsEarned coins stronger! 🚀",
    ];

    final random = DateTime.now().millisecondsSinceEpoch % templates.length;
    return templates[random];
  }

  /// Get display name for badge type
  static String _getBadgeDisplayName(BadgeType badgeType) {
    switch (badgeType) {
      case BadgeType.goalNinja:
        return 'Goal Ninja';
      case BadgeType.challengeChampion:
        return 'Challenge Champion';
      case BadgeType.streakMaster:
        return 'Streak Master';
      case BadgeType.helpfulHero:
        return 'Helpful Hero';
      case BadgeType.knowledgeSeeker:
        return 'Knowledge Seeker';
      case BadgeType.healthyHabitHero:
        return 'Healthy Habit Hero';
      case BadgeType.socialButterfly:
        return 'Social Butterfly';
      case BadgeType.academicAce:
        return 'Academic Ace';
      case BadgeType.questorFriend:
        return 'Questor Friend';
      case BadgeType.victoryVeteran:
        return 'Victory Veteran';
      default:
        return 'Achievement';
    }
  }

  /// Create a milestone celebration post
  static Future<void> createMilestonePost({
    required UserProvider userProvider,
    required PostProvider postProvider,
    required String milestone,
    required String description,
  }) async {
    final user = userProvider.user;
    if (user == null) return;

    final content = "🎉 Milestone achieved! $milestone 🎉\n\n$description\n\nEvery step forward is a victory! 💪✨";

    final post = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: content,
      createdAt: DateTime.now(),
    );

    try {
      final result = await postProvider.addPost(post);
      if (result['success']) {
        debugPrint('Auto-created milestone post: $milestone');
      }
    } catch (e) {
      debugPrint('Error creating milestone post: $e');
    }
  }

  /// Check if user should get an automatic encouragement post
  static Future<void> checkForEncouragementPost({
    required UserProvider userProvider,
    required PostProvider postProvider,
    required GoalProvider goalProvider,
  }) async {
    final user = userProvider.user;
    if (user == null) return;

    // Check if user hasn't posted in a while but has been active
    final userPosts = postProvider.posts.where((p) => p.userId == user.id).toList();
    final lastPost = userPosts.isNotEmpty ? userPosts.first.createdAt : null;
    
    // If no posts in last 7 days but has completed goals recently
    if (lastPost == null || DateTime.now().difference(lastPost).inDays >= 7) {
      final recentGoals = goalProvider.dailyGoals.where((g) => 
        g.isCompleted && 
        DateTime.now().difference(g.date).inDays <= 3
      ).toList();

      if (recentGoals.isNotEmpty) {
        final content = "Making steady progress on my leadership journey! 🌟 "
            "Completed ${recentGoals.length} goals this week. "
            "Small steps lead to big victories! 💪✨";

        final post = PostModel(
          id: const Uuid().v4(),
          userId: user.id,
          userName: user.name,
          content: content,
          createdAt: DateTime.now(),
        );

        try {
          final result = await postProvider.addPost(post);
          if (result['success']) {
            debugPrint('Auto-created encouragement post for user activity');
          }
        } catch (e) {
          debugPrint('Error creating encouragement post: $e');
        }
      }
    }
  }
}
