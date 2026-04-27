import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/mood_entry_model.dart';
import 'supabase_service.dart';
import 'ai_coach_service.dart';

class MoodTrackingService {
  static final MoodTrackingService _instance = MoodTrackingService._internal();
  static MoodTrackingService get instance => _instance;
  factory MoodTrackingService() => _instance;

  MoodTrackingService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final AiCoachService _aiCoachService = AiCoachService.instance;
  final Uuid _uuid = const Uuid();

  // Save mood entry
  Future<MoodEntryModel> saveMoodEntry({
    required String userId,
    required MoodType mood,
    required bool isMorning,
    String? note,
    List<MoodTrigger> triggers = const [],
  }) async {
    try {
      final entry = MoodEntryModel(
        id: _uuid.v4(),
        userId: userId,
        timestamp: DateTime.now(),
        mood: mood,
        note: note,
        triggers: triggers,
        isMorning: isMorning,
      );

      if (_supabaseService.isAuthenticated) {
        await _supabaseService.client.from('mood_entries').insert(entry.toJson());
      }

      debugPrint('Mood entry saved: ${entry.moodLabel}');
      return entry;
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      rethrow;
    }
  }

  // Get mood entries for a user
  Future<List<MoodEntryModel>> getMoodEntries(String userId,
      {int days = 30}) async {
    try {
      if (!_supabaseService.isAuthenticated) {
        return [];
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final response = await _supabaseService.client
          .from('mood_entries')
          .select()
          .eq('user_id', userId)
          .gte('timestamp', cutoffDate.toIso8601String())
          .order('timestamp', ascending: false);

      return (response as List)
          .map((json) => MoodEntryModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching mood entries: $e');
      return [];
    }
  }

  // Check if user has checked in today
  Future<bool> hasCheckedInToday(String userId, {required bool isMorning}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final entries = await getMoodEntries(userId, days: 1);
      return entries.any((entry) => 
        entry.isMorning == isMorning &&
        entry.timestamp.isAfter(startOfDay)
      );
    } catch (e) {
      debugPrint('Error checking mood check-in status: $e');
      return false;
    }
  }

  // Get mood analytics
  Future<Map<String, dynamic>> getMoodAnalytics(String userId, {int days = 7}) async {
    final entries = await getMoodEntries(userId, days: days);
    
    if (entries.isEmpty) {
      return {
        'averageScore': 5.0,
        'trend': 'neutral',
        'mostCommonMood': MoodType.neutral,
        'mostCommonTriggers': <MoodTrigger>[],
      };
    }

    final scores = entries.map((e) => e.moodScore).toList();
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;

    // Calculate trend
    final recentScores = scores.take(3).toList();
    final olderScores = scores.skip(3).take(3).toList();
    final recentAvg = recentScores.isEmpty ? averageScore : 
        recentScores.reduce((a, b) => a + b) / recentScores.length;
    final olderAvg = olderScores.isEmpty ? averageScore :
        olderScores.reduce((a, b) => a + b) / olderScores.length;
    
    String trend;
    if (recentAvg > olderAvg + 1) {
      trend = 'improving';
    } else if (recentAvg < olderAvg - 1) {
      trend = 'declining';
    } else {
      trend = 'stable';
    }

    // Most common mood
    final moodCounts = <MoodType, int>{};
    for (var entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    final mostCommonMood = moodCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Most common triggers
    final triggerCounts = <MoodTrigger, int>{};
    for (var entry in entries) {
      for (var trigger in entry.triggers) {
        triggerCounts[trigger] = (triggerCounts[trigger] ?? 0) + 1;
      }
    }
    final mostCommonTriggers = triggerCounts.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'averageScore': averageScore,
      'trend': trend,
      'mostCommonMood': mostCommonMood,
      'mostCommonTriggers': mostCommonTriggers.take(3).map((e) => e.key).toList(),
      'entries': entries,
    };
  }

  // Generate AI insights based on mood data
  Future<String> generateMoodInsights(String userId) async {
    final analytics = await getMoodAnalytics(userId, days: 7);
    final entries = analytics['entries'] as List<MoodEntryModel>;
    
    if (entries.isEmpty) {
      return "Start tracking your mood daily to get personalized insights!";
    }

    // For now, return fallback insights
    // TODO: Integrate with AI coach service for personalized insights
    return _getFallbackInsight(analytics);
  }

  String _getFallbackInsight(Map<String, dynamic> analytics) {
    final trend = analytics['trend'] as String;
    
    if (trend == 'improving') {
      return "Great news! Your mood has been improving lately. Keep up the positive momentum!";
    } else if (trend == 'declining') {
      return "I notice you've been feeling down lately. Remember, it's okay to have tough days. Try talking to someone you trust.";
    } else {
      return "Your mood has been pretty steady. Keep tracking to understand your patterns better!";
    }
  }
}
