import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tutorial/tutorial_overlay.dart';

class TutorialService {
  // Feature flag: quickly enable/disable tutorial globally
  // Set to false to disable tutorial for now
  static bool enabled = false;
  static const String _tutorialCompletedKey = 'tutorial_completed';
  static const String _userIdKey = 'tutorial_user_id';

  static Future<bool> shouldShowTutorial(String userId) async {
    try {
      // Short-circuit if globally disabled
      if (!enabled) return false;
      final prefs = await SharedPreferences.getInstance();
      final completedUserId = prefs.getString(_userIdKey);
      final isCompleted = prefs.getBool(_tutorialCompletedKey) ?? false;
      
      // Show tutorial if not completed or if different user
      return !isCompleted || completedUserId != userId;
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      return true; // Show tutorial on error to be safe
    }
  }

  static Future<void> markTutorialCompleted(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tutorialCompletedKey, true);
      await prefs.setString(_userIdKey, userId);
      debugPrint('Tutorial marked as completed for user: $userId');
    } catch (e) {
      debugPrint('Error marking tutorial as completed: $e');
    }
  }

  static Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tutorialCompletedKey);
      await prefs.remove(_userIdKey);
      debugPrint('Tutorial status reset');
    } catch (e) {
      debugPrint('Error resetting tutorial: $e');
    }
  }

  static List<TutorialStep> getMainNavigationSteps({
    required GlobalKey homeKey,
    required GlobalKey goalsKey,
    required GlobalKey challengesKey,
    required GlobalKey victoryWallKey,
    required GlobalKey leaderboardKey,
  }) {
    return [
      TutorialStep(
        title: 'Welcome to MLQ! 🎉',
        description: 'Let\'s take a quick tour of your leadership journey. This is your Home where you can see your progress and get personalized coaching.',
        targetKey: homeKey,
        position: TutorialPosition.top,
        icon: Icons.home_rounded,
      ),
      TutorialStep(
        title: 'Set Your Goals 🎯',
        description: 'Create main goals and daily tasks to build your leadership skills. Track your progress and earn XP for completing them!',
        targetKey: goalsKey,
        position: TutorialPosition.top,
        icon: Icons.flag_rounded,
      ),
      TutorialStep(
        title: 'Join Challenges 🏆',
        description: 'Participate in exciting challenges to test your skills, compete with others, and win amazing prizes!',
        targetKey: challengesKey,
        position: TutorialPosition.top,
        icon: Icons.emoji_events_rounded,
      ),
      TutorialStep(
        title: 'Share Your Victories 🎊',
        description: 'Celebrate your achievements on the Victory Wall! Share your successes and get inspired by others.',
        targetKey: victoryWallKey,
        position: TutorialPosition.top,
        icon: Icons.celebration_rounded,
      ),
      TutorialStep(
        title: 'Climb the Leaderboard 📊',
        description: 'See how you rank against other young leaders. Earn XP through goals and challenges to climb higher!',
        targetKey: leaderboardKey,
        position: TutorialPosition.top,
        icon: Icons.leaderboard_rounded,
      ),
    ];
  }

  static void showTutorial({
    required BuildContext context,
    required List<TutorialStep> steps,
    required String userId,
    VoidCallback? onComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TutorialOverlay(
        steps: steps,
        onComplete: () {
          Navigator.of(context).pop();
          markTutorialCompleted(userId);
          onComplete?.call();
        },
        onSkip: () {
          Navigator.of(context).pop();
          markTutorialCompleted(userId);
          onComplete?.call();
        },
      ),
    );
  }
}
