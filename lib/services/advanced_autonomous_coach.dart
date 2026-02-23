import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_coach_service.dart';
import '../services/user_data_aggregator.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/gratitude_provider.dart';

/// Phase 3: Advanced Autonomous Coach with Predictive Intelligence
class AdvancedAutonomousCoach {
  static final AdvancedAutonomousCoach _instance = AdvancedAutonomousCoach._internal();
  factory AdvancedAutonomousCoach() => _instance;
  static AdvancedAutonomousCoach get instance => _instance;

  final UserDataAggregator _userDataAggregator = UserDataAggregator.instance;
  final AiCoachService _aiCoachService = AiCoachService.instance;
  
  final StreamController<AdvancedAutonomousMessage> _messageController = 
      StreamController<AdvancedAutonomousMessage>.broadcast();
  
  Stream<AdvancedAutonomousMessage> get messageStream => _messageController.stream;
  
  Timer? _scheduledTimer;
  Timer? _predictiveTimer;
  bool _isEnabled = true;
  
  Map<String, dynamic>? _cachedProviders;
  DateTime? _lastDataAggregation;
  Map<String, dynamic>? _cachedUserSnapshot;
  QuestorPersonality? _currentPersonality;
  List<EmotionalPattern> _emotionalHistory = [];
  List<PredictiveInsight> _activeInsights = [];
  
  static const Duration _cacheValidityDuration = Duration(minutes: 3);
  static const Duration _predictiveAnalysisInterval = Duration(hours: 2);

  AdvancedAutonomousCoach._internal() {
    _initializeAdvancedCoaching();
  }

  void _initializeAdvancedCoaching() {
    _loadPersonalityProfile();
    _scheduleNextMessage();
    _schedulePredictiveAnalysis();
  }

  void _schedulePredictiveAnalysis() {
    _predictiveTimer?.cancel();
    _predictiveTimer = Timer.periodic(_predictiveAnalysisInterval, (timer) {
      _performPredictiveAnalysis();
    });
  }

  Future<void> _performPredictiveAnalysis() async {
    if (_cachedProviders == null) return;
    
    try {
      final userProvider = _cachedProviders!['user'] as UserProvider;
      final goalProvider = _cachedProviders!['goal'] as GoalProvider;
      
      final insights = await _generatePredictiveInsights(
        userProvider: userProvider,
        goalProvider: goalProvider,
      );
      
      _activeInsights.addAll(insights);
      if (_activeInsights.length > 10) {
        _activeInsights = _activeInsights.take(10).toList();
      }
      
      final urgentInsight = insights.where((i) => i.priority == InsightPriority.urgent).firstOrNull;
      if (urgentInsight != null) {
        await _triggerPredictiveCoaching(urgentInsight);
      }
      
    } catch (e) {
      debugPrint('Advanced Coach: Error in predictive analysis: $e');
    }
  }

  Future<List<PredictiveInsight>> _generatePredictiveInsights({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
  }) async {
    final insights = <PredictiveInsight>[];
    final now = DateTime.now();
    
    final dailyGoals = goalProvider.dailyGoals;
    final recentGoals = dailyGoals.where((g) => 
      now.difference(g.date).inDays <= 7
    ).toList();
    
    if (recentGoals.isNotEmpty) {
      final completionRate = recentGoals.where((g) => g.isCompleted).length / recentGoals.length;
      
      if (completionRate < 0.3 && recentGoals.length >= 3) {
        insights.add(PredictiveInsight(
          id: 'goal_struggle_${now.millisecondsSinceEpoch}',
          type: InsightType.goalStrugglePrediction,
          priority: InsightPriority.high,
          confidence: 0.8,
          predictedScenario: 'User showing signs of goal completion difficulty',
          recommendedIntervention: 'Provide motivational support and goal simplification',
          predictionDate: now,
        ));
      }
    }
    
    return insights;
  }

  Future<void> _triggerPredictiveCoaching(PredictiveInsight insight) async {
    try {
      final message = await _generatePredictiveMessage(insight);
      if (message != null) {
        _messageController.add(message);
      }
    } catch (e) {
      debugPrint('Advanced Coach: Error in predictive coaching: $e');
    }
  }

  Future<AdvancedAutonomousMessage?> _generatePredictiveMessage(PredictiveInsight insight) async {
    try {
      final prompt = _buildPredictivePrompt(insight);
      final conversationId = 'predictive_${DateTime.now().millisecondsSinceEpoch}';
      final aiResponse = await _aiCoachService.sendMessage(conversationId, prompt);

      if (aiResponse?.content != null) {
        await _adaptPersonalityForInsight(insight);

        return AdvancedAutonomousMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiResponse!.content,
          timestamp: DateTime.now(),
          type: _mapInsightToMessageType(insight.type),
          questorImage: _selectQuestorImageForInsight(insight),
          emotionalTone: _determineEmotionalTone(insight),
          personalityState: _currentPersonality?.toJson() ?? {},
          predictiveInsight: insight,
        );
      }
    } catch (e) {
      debugPrint('Advanced Coach: Error generating predictive message: $e');
    }
    
    return _getAdvancedFallbackMessage(insight.type);
  }

  String _buildPredictivePrompt(PredictiveInsight insight) {
    final personality = _currentPersonality ?? QuestorPersonality.defaultPersonality();
    
    return '''
You are Questor, an advanced AI coach for kids aged 8-16 with dynamic personality.

PERSONALITY STATE:
- Enthusiasm Level: ${personality.enthusiasmLevel}/10
- Wisdom Tone: ${personality.wisdomTone}
- Playfulness: ${personality.playfulness}/10

PREDICTIVE INSIGHT:
- Type: ${insight.type.toString()}
- Confidence: ${(insight.confidence * 100).toInt()}%
- Scenario: ${insight.predictedScenario}
- Approach: ${insight.recommendedIntervention}

Generate ONE brief coaching message (max 50 words) that addresses the predicted need proactively with encouraging, age-appropriate language and emojis.
''';
  }

  Future<void> _adaptPersonalityForInsight(PredictiveInsight insight) async {
    if (_currentPersonality == null) return;
    
    switch (insight.type) {
      case InsightType.emotionalSupport:
        _currentPersonality = _currentPersonality!.copyWith(
          enthusiasmLevel: max(1, _currentPersonality!.enthusiasmLevel - 2),
          wisdomTone: 'compassionate',
        );
        break;
      case InsightType.breakthroughOpportunity:
        _currentPersonality = _currentPersonality!.copyWith(
          enthusiasmLevel: min(10, _currentPersonality!.enthusiasmLevel + 2),
          wisdomTone: 'celebratory',
        );
        break;
      default:
        break;
    }
    
    await _savePersonalityProfile();
  }

  void cacheProviders({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) {
    _cachedProviders = {
      'user': userProvider,
      'goal': goalProvider,
      'challenge': challengeProvider,
    };
  }

  Future<AdvancedAutonomousMessage?> generateAdvancedMessage({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    try {
      cacheProviders(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );

      final emotionalState = await _analyzeEmotionalState();
      _emotionalHistory.insert(0, emotionalState);
      if (_emotionalHistory.length > 50) {
        _emotionalHistory = _emotionalHistory.take(50).toList();
      }

      final userSnapshot = await _getOptimizedUserData(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );

      if (userSnapshot.isEmpty) return null;

      final urgentInsight = _activeInsights.where((i) => i.priority == InsightPriority.urgent).firstOrNull;
      if (urgentInsight != null) {
        return await _generatePredictiveMessage(urgentInsight);
      }

      final conversationId = 'advanced_${DateTime.now().millisecondsSinceEpoch}';
      final prompt = _buildAdvancedCoachingPrompt(userSnapshot, emotionalState);
      final aiResponse = await _aiCoachService.sendMessage(conversationId, prompt);

      if (aiResponse?.content != null) {
        await _evolvePersonality(emotionalState, userSnapshot);

        return AdvancedAutonomousMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: aiResponse!.content,
          timestamp: DateTime.now(),
          type: _determineAdvancedMessageType(userSnapshot, emotionalState),
          questorImage: _selectAdvancedQuestorImage(emotionalState, userSnapshot),
          emotionalTone: _determineEmotionalTone(null, emotionalState),
          personalityState: _currentPersonality?.toJson() ?? {},
          predictiveInsight: null,
        );
      }

      return _getAdvancedFallbackMessage(InsightType.general);

    } catch (e) {
      debugPrint('Advanced Coach: Error generating message: $e');
      return _getAdvancedFallbackMessage(InsightType.general);
    }
  }

  Future<EmotionalPattern> _analyzeEmotionalState() async {
    try {
      final gratitudeProvider = GratitudeProvider();
      await gratitudeProvider.loadEntries();
      
      final recentEntries = gratitudeProvider.entries.where((entry) => 
        DateTime.now().difference(entry.date).inDays <= 3
      ).toList();

      double moodScore = 0.5;
      String dominantMood = 'neutral';
      
      if (recentEntries.isNotEmpty) {
        final moodScores = {'sad': 0.2, 'neutral': 0.5, 'happy': 0.8, 'excited': 1.0};
        final moodCounts = <String, int>{};
        double totalScore = 0.0;
        
        for (final entry in recentEntries) {
          final mood = entry.mood;
          moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
          totalScore += moodScores[mood] ?? 0.5;
        }
        
        moodScore = totalScore / recentEntries.length;
        dominantMood = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      return EmotionalPattern(
        timestamp: DateTime.now(),
        moodScore: moodScore,
        dominantMood: dominantMood,
        gratitudeFrequency: recentEntries.length,
        motivationLevel: _calculateMotivationLevel(moodScore),
      );
    } catch (e) {
      return EmotionalPattern.neutral();
    }
  }

  Future<Map<String, dynamic>> _getOptimizedUserData({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    final now = DateTime.now();
    
    if (_cachedUserSnapshot != null && 
        _lastDataAggregation != null &&
        now.difference(_lastDataAggregation!).inMinutes < _cacheValidityDuration.inMinutes) {
      return _cachedUserSnapshot!;
    }

    final userSnapshot = await _userDataAggregator.aggregateUserData(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );

    _cachedUserSnapshot = userSnapshot;
    _lastDataAggregation = now;
    return userSnapshot;
  }

  String _buildAdvancedCoachingPrompt(Map<String, dynamic> userSnapshot, EmotionalPattern emotionalState) {
    final user = userSnapshot['user'] ?? {};
    final goals = userSnapshot['goals'] ?? {};
    final behavior = userSnapshot['behavior'] ?? {};
    final personality = _currentPersonality ?? QuestorPersonality.defaultPersonality();

    return '''
You are Questor, an advanced AI coach for kids aged 8-16 with emotional intelligence.

PERSONALITY: Enthusiasm ${personality.enthusiasmLevel}/10, ${personality.wisdomTone}, Playful ${personality.playfulness}/10

USER: ${user['name'] ?? 'there'} (age ${user['age'] ?? 'unknown'})
EMOTIONAL STATE: Mood ${(emotionalState.moodScore * 100).toInt()}%, ${emotionalState.dominantMood}, Motivation ${emotionalState.motivationLevel}
PROGRESS: ${goals['todayCompletedCount'] ?? 0}/${goals['todayGoalsCount'] ?? 0} goals, ${behavior['currentStreak'] ?? 0} day streak

Generate ONE personalized message (max 50 words) that responds to their emotional state with your personality, provides actionable guidance, and uses encouraging language with emojis.
''';
  }

  String _calculateMotivationLevel(double moodScore) {
    if (moodScore >= 0.8) return 'high';
    if (moodScore >= 0.6) return 'medium';
    if (moodScore >= 0.4) return 'low';
    return 'very_low';
  }

  String _determineAdvancedMessageType(Map<String, dynamic> userSnapshot, EmotionalPattern emotionalState) {
    if (emotionalState.moodScore < 0.4) return 'Emotional Support';
    
    final context = userSnapshot['context'] ?? {};
    final timePeriod = context['time_period'] ?? 'morning';
    
    switch (timePeriod) {
      case 'morning': return 'Morning Boost';
      case 'afternoon': return 'Midday Check-in';
      case 'evening': return 'Evening Reflection';
      default: return 'Friendly Reminder';
    }
  }

  String _selectAdvancedQuestorImage(EmotionalPattern emotionalState, Map<String, dynamic> userSnapshot) {
    if (emotionalState.moodScore < 0.4) return 'assets/images/questor 5.png'; // Compassionate Questor
    if (emotionalState.moodScore > 0.8) return 'assets/images/questor 4.png'; // Excited Questor
    return 'assets/images/questor 2.png'; // Happy Questor
  }

  String _determineEmotionalTone(PredictiveInsight? insight, [EmotionalPattern? emotionalState]) {
    if (insight != null) {
      switch (insight.type) {
        case InsightType.emotionalSupport: return 'compassionate';
        case InsightType.breakthroughOpportunity: return 'celebratory';
        default: return 'encouraging';
      }
    }
    
    if (emotionalState != null) {
      if (emotionalState.moodScore < 0.4) return 'compassionate';
      if (emotionalState.moodScore > 0.8) return 'celebratory';
    }
    
    return 'encouraging';
  }

  String _mapInsightToMessageType(InsightType type) {
    switch (type) {
      case InsightType.emotionalSupport: return 'Emotional Support';
      case InsightType.breakthroughOpportunity: return 'Breakthrough Coaching';
      case InsightType.goalStrugglePrediction: return 'Goal Support';
      default: return 'Predictive Coaching';
    }
  }

  String _selectQuestorImageForInsight(PredictiveInsight insight) {
    switch (insight.type) {
      case InsightType.emotionalSupport: return 'assets/images/questor 5.png'; // Compassionate Questor
      case InsightType.breakthroughOpportunity: return 'assets/images/questor 4.png'; // Excited Questor
      default: return 'assets/images/questor 3.png'; // Default Questor
    }
  }

  AdvancedAutonomousMessage _getAdvancedFallbackMessage(InsightType type) {
    final fallbackMessages = {
      InsightType.emotionalSupport: "I'm here for you! 🤗 Remember, you're stronger than you know.",
      InsightType.breakthroughOpportunity: "You're on fire! 🔥 Ready for an even bigger challenge?",
      InsightType.goalStrugglePrediction: "Struggling with goals? 💪 Let's break them into smaller steps!",
      InsightType.general: "Hey there, champion! 🌟 Ready to make today amazing?",
    };

    final message = fallbackMessages[type] ?? fallbackMessages[InsightType.general]!;

    return AdvancedAutonomousMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      timestamp: DateTime.now(),
      type: _mapInsightToMessageType(type),
      questorImage: _selectQuestorImageForInsight(PredictiveInsight.fallback(type)),
      emotionalTone: _determineEmotionalTone(PredictiveInsight.fallback(type)),
      personalityState: _currentPersonality?.toJson() ?? {},
      predictiveInsight: null,
    );
  }

  Future<void> _evolvePersonality(EmotionalPattern emotionalState, Map<String, dynamic> userSnapshot) async {
    if (_currentPersonality == null) return;

    if (emotionalState.moodScore < 0.4 && _currentPersonality!.enthusiasmLevel > 5) {
      _currentPersonality = _currentPersonality!.copyWith(
        enthusiasmLevel: max(3, _currentPersonality!.enthusiasmLevel - 1),
        wisdomTone: 'compassionate',
      );
    } else if (emotionalState.moodScore > 0.8 && _currentPersonality!.enthusiasmLevel < 8) {
      _currentPersonality = _currentPersonality!.copyWith(
        enthusiasmLevel: min(10, _currentPersonality!.enthusiasmLevel + 1),
        wisdomTone: 'celebratory',
      );
    }

    await _savePersonalityProfile();
  }

  void _scheduleNextMessage() {
    if (!_isEnabled) return;
    
    final now = DateTime.now();
    final scheduledTimes = [9, 13, 19];
    
    DateTime? nextScheduled;
    for (final hour in scheduledTimes) {
      final scheduledToday = DateTime(now.year, now.month, now.day, hour);
      if (scheduledToday.isAfter(now)) {
        nextScheduled = scheduledToday;
        break;
      }
    }
    
    nextScheduled ??= DateTime(now.year, now.month, now.day + 1, 9);
    
    final delay = nextScheduled.difference(now);
    
    _scheduledTimer?.cancel();
    _scheduledTimer = Timer(delay, () {
      _triggerScheduledMessage();
      _scheduleNextMessage();
    });
  }

  void _triggerScheduledMessage() async {
    try {
      if (_cachedProviders != null) {
        final message = await generateAdvancedMessage(
          userProvider: _cachedProviders!['user'] as UserProvider,
          goalProvider: _cachedProviders!['goal'] as GoalProvider,
          challengeProvider: _cachedProviders!['challenge'] as ChallengeProvider,
        );
        
        if (message != null) {
          _messageController.add(message);
          return;
        }
      }
      
      final fallbackMessage = _getAdvancedFallbackMessage(InsightType.general);
      _messageController.add(fallbackMessage);
      
    } catch (e) {
      final fallbackMessage = _getAdvancedFallbackMessage(InsightType.general);
      _messageController.add(fallbackMessage);
    }
  }

  Future<void> _loadPersonalityProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final personalityJson = prefs.getString('questor_personality');
      if (personalityJson != null) {
        final personalityData = jsonDecode(personalityJson);
        _currentPersonality = QuestorPersonality.fromJson(personalityData);
      } else {
        _currentPersonality = QuestorPersonality.defaultPersonality();
        await _savePersonalityProfile();
      }
    } catch (e) {
      _currentPersonality = QuestorPersonality.defaultPersonality();
    }
  }

  Future<void> _savePersonalityProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final personalityJson = jsonEncode(_currentPersonality!.toJson());
      await prefs.setString('questor_personality', personalityJson);
    } catch (e) {
      debugPrint('Error saving personality: $e');
    }
  }

  void dispose() {
    _scheduledTimer?.cancel();
    _predictiveTimer?.cancel();
    _messageController.close();
  }
}

// Supporting models
class AdvancedAutonomousMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final String type;
  final String questorImage;
  final String emotionalTone;
  final Map<String, dynamic> personalityState;
  final PredictiveInsight? predictiveInsight;

  AdvancedAutonomousMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.type,
    required this.questorImage,
    required this.emotionalTone,
    required this.personalityState,
    this.predictiveInsight,
  });
}

class QuestorPersonality {
  final int enthusiasmLevel;
  final String wisdomTone;
  final int playfulness;
  final String communicationStyle;

  QuestorPersonality({
    required this.enthusiasmLevel,
    required this.wisdomTone,
    required this.playfulness,
    required this.communicationStyle,
  });

  static QuestorPersonality defaultPersonality() {
    return QuestorPersonality(
      enthusiasmLevel: 7,
      wisdomTone: 'encouraging',
      playfulness: 6,
      communicationStyle: 'friendly',
    );
  }

  QuestorPersonality copyWith({
    int? enthusiasmLevel,
    String? wisdomTone,
    int? playfulness,
    String? communicationStyle,
  }) {
    return QuestorPersonality(
      enthusiasmLevel: enthusiasmLevel ?? this.enthusiasmLevel,
      wisdomTone: wisdomTone ?? this.wisdomTone,
      playfulness: playfulness ?? this.playfulness,
      communicationStyle: communicationStyle ?? this.communicationStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enthusiasmLevel': enthusiasmLevel,
      'wisdomTone': wisdomTone,
      'playfulness': playfulness,
      'communicationStyle': communicationStyle,
    };
  }

  factory QuestorPersonality.fromJson(Map<String, dynamic> json) {
    return QuestorPersonality(
      enthusiasmLevel: json['enthusiasmLevel'] ?? 7,
      wisdomTone: json['wisdomTone'] ?? 'encouraging',
      playfulness: json['playfulness'] ?? 6,
      communicationStyle: json['communicationStyle'] ?? 'friendly',
    );
  }
}

class EmotionalPattern {
  final DateTime timestamp;
  final double moodScore;
  final String dominantMood;
  final int gratitudeFrequency;
  final String motivationLevel;

  EmotionalPattern({
    required this.timestamp,
    required this.moodScore,
    required this.dominantMood,
    required this.gratitudeFrequency,
    required this.motivationLevel,
  });

  static EmotionalPattern neutral() {
    return EmotionalPattern(
      timestamp: DateTime.now(),
      moodScore: 0.5,
      dominantMood: 'neutral',
      gratitudeFrequency: 0,
      motivationLevel: 'medium',
    );
  }
}

class PredictiveInsight {
  final String id;
  final InsightType type;
  final InsightPriority priority;
  final double confidence;
  final String predictedScenario;
  final String recommendedIntervention;
  final DateTime predictionDate;

  PredictiveInsight({
    required this.id,
    required this.type,
    required this.priority,
    required this.confidence,
    required this.predictedScenario,
    required this.recommendedIntervention,
    required this.predictionDate,
  });

  static PredictiveInsight fallback(InsightType type) {
    return PredictiveInsight(
      id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      priority: InsightPriority.low,
      confidence: 0.5,
      predictedScenario: 'General coaching needed',
      recommendedIntervention: 'Provide encouraging message',
      predictionDate: DateTime.now(),
    );
  }
}

enum InsightType {
  emotionalSupport,
  breakthroughOpportunity,
  goalStrugglePrediction,
  motivationDip,
  general,
}

enum InsightPriority {
  urgent,
  high,
  medium,
  low,
}
