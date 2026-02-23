import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/gratitude_provider.dart';

class UserDataAggregator {
  static final UserDataAggregator _instance = UserDataAggregator._internal();
  static UserDataAggregator get instance => _instance;

  final GratitudeProvider _gratitudeProvider = GratitudeProvider();

  UserDataAggregator._internal();

  /// Aggregates comprehensive user data for AI coaching analysis
  Future<Map<String, dynamic>> aggregateUserData({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    try {
      final user = userProvider.user;
      if (user == null) {
        debugPrint('UserDataAggregator: No user found');
        return _getEmptySnapshot();
      }

      debugPrint('UserDataAggregator: Aggregating data for user ${user.name}');

      // Ensure gratitude provider is loaded
      await _gratitudeProvider.loadEntries();

      // Collect all data components
      final userData = _getUserData(user);
      final goalsData = _getGoalsData(goalProvider);
      final challengesData = _getChallengesData(challengeProvider);
      final behaviorData = _getBehaviorData(goalProvider);
      final emotionalData = _getEmotionalData();
      final contextData = _getContextData();

      // Combine all data into comprehensive snapshot
      final snapshot = {
        'user': userData,
        'goals': goalsData,
        'challenges': challengesData,
        'behavior': behaviorData,
        'emotional': emotionalData,
        'context': contextData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('UserDataAggregator: Successfully aggregated user data snapshot');
      return snapshot;
    } catch (e) {
      debugPrint('UserDataAggregator: Error aggregating user data: $e');
      return _getEmptySnapshot();
    }
  }

  /// Collects user profile and basic information
  Map<String, dynamic> _getUserData(UserModel user) {
    return {
      'id': user.id,
      'name': user.name,
      'age': user.age,
      'xp': user.xp,
      'coins': user.coins,
      'badges': user.badges,
      'interests': user.interests,
      'isPremium': user.isPremium,
    };
  }

  /// Collects goals data and progress information
  Map<String, dynamic> _getGoalsData(GoalProvider goalProvider) {
    final mainGoals = goalProvider.mainGoals;
    final dailyGoals = goalProvider.dailyGoals;
    final todayGoals = goalProvider.todayGoals;
    final weeklyRates = goalProvider.weeklyCompletionRates;

    return {
      'mainGoals': mainGoals.map((goal) => {
        'id': goal.id,
        'title': goal.title,
        'description': goal.description,
        'category': goal.category,
        'targetXp': goal.totalXpRequired,
        'currentXp': goal.currentXp,
        'isCompleted': goal.isCompleted,
      }).toList(),
      'dailyGoals': dailyGoals.map((goal) => {
        'id': goal.id,
        'title': goal.title,
        'isCompleted': goal.isCompleted,
        'date': goal.date.toIso8601String(),
        'mainGoalId': goal.mainGoalId,
      }).toList(),
      'todayGoalsCount': todayGoals.length,
      'todayCompletedCount': todayGoals.where((g) => g.isCompleted).length,
      'weeklyCompletionRates': weeklyRates.map((date, rate) => 
        MapEntry(date.toIso8601String(), rate)
      ),
      'totalMainGoals': mainGoals.length,
      'completedMainGoals': mainGoals.where((g) => g.isCompleted).length,
    };
  }

  /// Analyzes behavioral patterns and engagement levels
  Map<String, dynamic> _getBehaviorData(GoalProvider goalProvider) {
    final dailyGoals = goalProvider.dailyGoals;
    final currentStreak = goalProvider.getCurrentStreak();

    // Calculate engagement patterns
    final last7Days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: i)));
    final dailyActivity = <String, int>{};
    
    for (final date in last7Days) {
      final dateKey = date.toIso8601String().split('T')[0];
      final goalsForDay = goalProvider.getDailyGoalsForDate(date);
      dailyActivity[dateKey] = goalsForDay.where((g) => g.isCompleted).length;
    }

    return {
      'currentStreak': currentStreak,
      'dailyActivity': dailyActivity,
      'totalDailyGoals': dailyGoals.length,
      'completedDailyGoals': dailyGoals.where((g) => g.isCompleted).length,
      'averageCompletionRate': dailyGoals.isEmpty ? 0.0 : 
        dailyGoals.where((g) => g.isCompleted).length / dailyGoals.length,
    };
  }

  /// Collects challenge participation and performance data
  Map<String, dynamic> _getChallengesData(ChallengeProvider challengeProvider) {
    final challenges = challengeProvider.challenges;
    final participatingIds = challengeProvider.participatingChallengeIds;

    return {
      'availableChallenges': challenges.map((challenge) => {
        'id': challenge.id,
        'title': challenge.title,
        'description': challenge.description,
        'type': challenge.type.toString(),
        'coinsCost': challenge.coinsCost,
        'coinReward': challenge.coinReward,
      }).toList(),
      'participatingChallenges': participatingIds,
      'totalChallenges': challenges.length,
      'activeChallenges': participatingIds.length,
      'completedChallenges': 0, // Would need additional tracking
    };
  }

  /// Collects emotional indicators from gratitude jar and other sources
  Map<String, dynamic> _getEmotionalData() {
    try {
      // Get gratitude entries from local provider
      final gratitudeEntries = _gratitudeProvider.entries;
      final recentEntries = gratitudeEntries.where((entry) => 
        DateTime.now().difference(entry.date).inDays <= 7
      ).toList();

      // Analyze mood patterns
      final moodCounts = <String, int>{};
      for (final entry in recentEntries) {
        final mood = entry.mood;
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }

      return {
        'gratitudeEntries': gratitudeEntries.length,
        'recentGratitudeCount': recentEntries.length,
        'moodDistribution': moodCounts,
        'averageMoodScore': _calculateAverageMoodScore(recentEntries),
        'gratitudeFrequency': _calculateGratitudeFrequency(gratitudeEntries),
      };
    } catch (e) {
      debugPrint('UserDataAggregator: Error getting emotional data: $e');
      return {
        'gratitudeEntries': 0,
        'recentGratitudeCount': 0,
        'moodDistribution': <String, int>{},
        'averageMoodScore': 0.5,
        'gratitudeFrequency': 'low',
      };
    }
  }

  /// Current context (time, day, etc.)
  Map<String, dynamic> _getContextData() {
    final now = DateTime.now();
    return {
      'current_time': now.toIso8601String(),
      'hour_of_day': now.hour,
      'day_of_week': now.weekday,
      'is_weekend': now.weekday >= 6,
      'time_period': _getTimePeriod(now.hour),
    };
  }

  /// Calculates average mood score from gratitude entries
  double _calculateAverageMoodScore(List<GratitudeEntry> entries) {
    if (entries.isEmpty) return 0.5;
    
    final moodScores = {
      'sad': 0.2,
      'neutral': 0.5,
      'happy': 0.8,
      'excited': 1.0,
    };
    
    double totalScore = 0.0;
    int validEntries = 0;
    
    for (final entry in entries) {
      final mood = entry.mood;
      if (moodScores.containsKey(mood)) {
        totalScore += moodScores[mood]!;
        validEntries++;
      }
    }
    
    return validEntries > 0 ? totalScore / validEntries : 0.5;
  }

  /// Calculates gratitude frequency pattern
  String _calculateGratitudeFrequency(List<GratitudeEntry> entries) {
    if (entries.isEmpty) return 'none';
    
    final now = DateTime.now();
    final last30Days = entries.where((entry) => 
      now.difference(entry.date).inDays <= 30
    ).length;
    
    if (last30Days >= 20) return 'high';
    if (last30Days >= 10) return 'medium';
    if (last30Days >= 3) return 'low';
    return 'very_low';
  }

  /// Returns empty snapshot when user data is unavailable
  Map<String, dynamic> _getEmptySnapshot() {
    return {
      'user': {},
      'goals': {},
      'challenges': {},
      'behavior': {},
      'emotional': {},
      'context': _getContextData(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Returns time period based on hour of day
  String _getTimePeriod(int hour) {
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }
}
