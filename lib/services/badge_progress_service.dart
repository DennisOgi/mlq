import 'package:flutter/material.dart';
import '../widgets/badge_progress_indicator.dart';
import '../providers/providers.dart';
import '../models/models.dart';

/// Service to calculate badge progress for display
class BadgeProgressService {
  static List<BadgeProgressData> calculateBadgeProgress({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider? challengeProvider,
    required MiniCourseProvider? miniCourseProvider,
    required GratitudeProvider? gratitudeProvider,
  }) {
    final List<BadgeProgressData> progressList = [];
    final user = userProvider.user;
    if (user == null) return progressList;

    // Get user's earned badges to filter out completed ones
    final earnedBadgeNames = userProvider.badges.map((b) => b.name).toSet();

    // 1. Goal-based badges (daily goals completed)
    final completedDailyGoals =
        goalProvider.dailyGoals.where((g) => g.isCompleted).length;

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Starter Vision',
        'Complete your first goal',
        completedDailyGoals,
        1,
        Icons.flag,
        Colors.blue);

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Sharpshooter',
        'Complete 3 goals',
        completedDailyGoals,
        3,
        Icons.gps_fixed,
        Colors.green);

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Step Climber',
        'Complete 5 goals',
        completedDailyGoals,
        5,
        Icons.trending_up,
        Colors.orange);

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Achiever\'s Medal',
        'Complete 10 goals',
        completedDailyGoals,
        10,
        Icons.military_tech,
        Colors.purple);

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Goal Voyager',
        'Complete 25 goals',
        completedDailyGoals,
        25,
        Icons.explore,
        Colors.teal);

    // 2. Mini-course badges
    if (miniCourseProvider != null) {
      final completedCourses = miniCourseProvider.courses
          .where((c) => c.status == MiniCourseStatus.completed)
          .length;

      _addIfNotEarned(
          progressList,
          earnedBadgeNames,
          'Apprentice Learner',
          'Complete 1 mini-course',
          completedCourses,
          1,
          Icons.school,
          Colors.indigo);

      _addIfNotEarned(
          progressList,
          earnedBadgeNames,
          'Knowledge Seeker',
          'Complete 3 mini-courses',
          completedCourses,
          3,
          Icons.menu_book,
          Colors.deepPurple);
    }

    // 3. Challenge badges
    // Note: ChallengeModel doesn't have isCompleted property
    // Challenge completion is tracked in user_challenge_participations table
    // For now, we skip challenge badge progress (can be added later with proper DB query)
    // if (challengeProvider != null) {
    //   final completedChallenges = 0; // TODO: Query user_challenge_participations
    //   _addIfNotEarned(progressList, earnedBadgeNames, 'Challenge Champion',
    //     'Complete 3 challenges', completedChallenges, 3, Icons.emoji_events, Colors.amber);
    // }

    // 4. Gratitude streak badges
    if (gratitudeProvider != null) {
      final currentStreak = _calculateGratitudeStreak(gratitudeProvider);

      _addIfNotEarned(
          progressList,
          earnedBadgeNames,
          'Grateful Heart',
          'Maintain 1-day gratitude streak',
          currentStreak,
          1,
          Icons.favorite,
          Colors.pink);

      _addIfNotEarned(
          progressList,
          earnedBadgeNames,
          'Streak Master',
          'Maintain 5-day gratitude streak',
          currentStreak,
          5,
          Icons.local_fire_department,
          Colors.deepOrange);
    }

    // 5. Category-specific goal badges
    final healthGoals = goalProvider.dailyGoals
        .where((g) => g.isCompleted && _getGoalCategory(g) == 'Health')
        .length;

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Healthy Habit Hero',
        'Complete 10 health goals',
        healthGoals,
        10,
        Icons.favorite_border,
        Colors.red);

    final socialGoals = goalProvider.dailyGoals
        .where((g) => g.isCompleted && _getGoalCategory(g) == 'Social')
        .length;

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Social Butterfly',
        'Complete 10 social goals',
        socialGoals,
        10,
        Icons.people,
        Colors.lightBlue);

    final academicGoals = goalProvider.dailyGoals
        .where((g) => g.isCompleted && _getGoalCategory(g) == 'Academic')
        .length;

    _addIfNotEarned(
        progressList,
        earnedBadgeNames,
        'Academic Ace',
        'Complete 10 academic goals',
        academicGoals,
        10,
        Icons.school_outlined,
        Colors.blueGrey);

    // Sort by progress percentage (closest to completion first)
    progressList.sort((a, b) {
      final aProgress = a.currentProgress / a.requiredProgress;
      final bProgress = b.currentProgress / b.requiredProgress;
      return bProgress.compareTo(aProgress);
    });

    // Return top 5 closest to completion
    return progressList.take(5).toList();
  }

  static void _addIfNotEarned(
    List<BadgeProgressData> list,
    Set<String> earnedBadges,
    String name,
    String description,
    int current,
    int required,
    IconData icon,
    Color color,
  ) {
    if (!earnedBadges.contains(name)) {
      list.add(BadgeProgressData(
        name: name,
        description: description,
        currentProgress: current,
        requiredProgress: required,
        icon: icon,
        color: color,
      ));
    }
  }

  static int _calculateGratitudeStreak(GratitudeProvider provider) {
    final entries = provider.entries;
    if (entries.isEmpty) return 0;

    entries.sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime checkDate = DateTime.now();

    for (int i = 0; i < entries.length; i++) {
      final entryDate = entries[i].date;
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
      final checkDay = DateTime(checkDate.year, checkDate.month, checkDate.day);

      if (entryDay.isAtSameMomentAs(checkDay)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (entryDay.isBefore(checkDay)) {
        break;
      }
    }

    return streak;
  }

  static String _getGoalCategory(DailyGoalModel goal) {
    // Use the actual category field from the database
    // Capitalize first letter to match the display format
    final category = goal.category;
    return category[0].toUpperCase() + category.substring(1);
  }
}
