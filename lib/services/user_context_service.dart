import 'package:flutter/foundation.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/gratitude_provider.dart';
import '../models/main_goal_model.dart';
import '../models/daily_goal_model.dart';
import '../models/challenge_model.dart';

class UserContextService {
  static const UserContextService _instance = UserContextService._internal();
  factory UserContextService() => _instance;
  static UserContextService get instance => _instance;
  
  const UserContextService._internal();

  /// Builds comprehensive user context for personalized AI interactions
  static Future<Map<String, dynamic>> getUserContext({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
    GratitudeProvider? gratitudeProvider,
  }) async {
    try {
      final user = userProvider.user;
      if (user == null) {
        debugPrint('User is null, returning default context');
        return _getDefaultContext();
      }
      
      final mainGoals = goalProvider.mainGoals;
      final todayGoals = goalProvider.dailyGoals.where((g) => 
        g.date.year == DateTime.now().year &&
        g.date.month == DateTime.now().month &&
        g.date.day == DateTime.now().day
      ).toList();
      final challenges = challengeProvider.challenges;
      
      // Calculate goal completion stats
      final completedTodayGoals = todayGoals.where((g) => g.isCompleted).length;
      final totalTodayGoals = todayGoals.length;
      final goalCompletionRate = totalTodayGoals > 0 ? (completedTodayGoals / totalTodayGoals * 100).round() : 0;
      
      // Calculate main goal progress (using XP completion percentage)
      final mainGoalProgress = mainGoals.isNotEmpty 
        ? mainGoals.map((g) => (g.currentXp / g.totalXpRequired * 100).clamp(0.0, 100.0)).reduce((a, b) => a + b) / mainGoals.length
        : 0.0;
      
      // Get recent activity patterns
      final recentGoals = goalProvider.dailyGoals
        .where((g) => g.date.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();
      
      final weeklyCompletionRate = recentGoals.isNotEmpty
        ? (recentGoals.where((g) => g.isCompleted).length / recentGoals.length * 100).round()
        : 0;
      
      // Calculate streak
      final currentStreak = _calculateGoalStreak(goalProvider.dailyGoals);
      
      // Get active challenges (simplified - just get all challenges for now)
      final activeChallenges = challenges.where((c) => 
        DateTime.now().isBefore(c.endDate) && DateTime.now().isAfter(c.startDate)
      ).toList();
      
      // Get gratitude entries (if provider available)
      List<String> recentGratitude = [];
      if (gratitudeProvider != null) {
        try {
          // GratitudeProvider uses 'entries' property
          final gratitudeEntries = gratitudeProvider.entries
            .where((entry) => entry.date.isAfter(DateTime.now().subtract(const Duration(days: 3))))
            .take(3)
            .map((entry) => entry.content)
            .toList();
          recentGratitude = gratitudeEntries;
        } catch (e) {
          // Fallback if entries access fails
          recentGratitude = [];
        }
      }
      
      return {
        'user': {
          'name': user.name,
          'age': user.age,
          'coins': user.coins,
          'xp': user.xp,
          'level': _calculateLevel(user.xp),
        },
        'goals_today': {
          'completed': completedTodayGoals,
          'total': totalTodayGoals,
          'completion_rate': goalCompletionRate,
          'goals': todayGoals.map((g) => {
            'title': g.title,
            'completed': g.isCompleted,
            'xp_value': g.xpValue,
          }).toList(),
        },
        'main_goals': {
          'count': mainGoals.length,
          'average_progress': mainGoalProgress.round(),
          'goals': mainGoals.map((g) => {
            'title': g.title,
            'progress': (g.currentXp / g.totalXpRequired * 100).clamp(0.0, 100.0).round(),
            'category': g.category.toString().split('.').last,
          }).toList(),
        },
        'activity_patterns': {
          'current_streak': currentStreak,
          'weekly_completion_rate': weeklyCompletionRate,
          'total_goals_this_week': recentGoals.length,
        },
        'challenges': {
          'active_count': activeChallenges.length,
          'active_challenges': activeChallenges.map((c) => {
            'title': c.title,
            'type': c.type.toString().split('.').last,
          }).toList(),
        },
        'gratitude': {
          'recent_entries': recentGratitude,
          'has_entries': recentGratitude.isNotEmpty,
        },
        'engagement_level': _calculateEngagementLevel(
          goalCompletionRate,
          currentStreak,
          activeChallenges.length,
        ),
      };
    } catch (e) {
      debugPrint('Error building user context: $e');
      return _getDefaultContext();
    }
  }

  /// Calculate user level based on XP
  static int _calculateLevel(int xp) {
    // Simple level calculation: 100 XP per level
    return (xp / 100).floor() + 1;
  }

  /// Calculate engagement level based on user activity
  static String _calculateEngagementLevel(int goalCompletionRate, int currentStreak, int activeChallenges) {
    int score = 0;
    
    // Goal completion rate (0-50 points)
    score += (goalCompletionRate * 0.5).round();
    
    // Current streak (0-30 points)
    score += (currentStreak * 3).clamp(0, 30);
    
    // Active challenges (0-20 points)
    score += (activeChallenges * 5).clamp(0, 20);
    
    if (score >= 70) return 'high';
    if (score >= 40) return 'medium';
    return 'low';
  }



  /// Analyzes user message to determine what context is relevant
  static Map<String, dynamic> analyzeMessageContext(String userMessage) {
    final lowerMessage = userMessage.toLowerCase().trim();
    
    // Determine message type and required context
    bool isGreeting = _isGreeting(lowerMessage);
    bool isGoalRelated = _isGoalRelated(lowerMessage);
    bool isChallengeRelated = _isChallengeRelated(lowerMessage);
    bool isProgressInquiry = _isProgressInquiry(lowerMessage);
    bool isMotivationalRequest = _isMotivationalRequest(lowerMessage);
    bool isComplexQuestion = _isComplexQuestion(lowerMessage);
    
    return {
      'isGreeting': isGreeting,
      'isGoalRelated': isGoalRelated,
      'isChallengeRelated': isChallengeRelated,
      'isProgressInquiry': isProgressInquiry,
      'isMotivationalRequest': isMotivationalRequest,
      'isComplexQuestion': isComplexQuestion,
      'needsUserProfile': isGreeting || isMotivationalRequest,
      'needsGoalContext': isGoalRelated || isProgressInquiry || isComplexQuestion,
      'needsChallengeContext': isChallengeRelated || isComplexQuestion,
      'needsProgressContext': isProgressInquiry || isComplexQuestion,
      'suggestedResponseLength': _getSuggestedResponseLength(isGreeting, isComplexQuestion, isMotivationalRequest),
    };
  }
  
  static bool _isGreeting(String message) {
    final greetings = ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening', 'howdy', 'greetings'];
    return greetings.any((greeting) => message.startsWith(greeting) || message == greeting);
  }
  
  static bool _isGoalRelated(String message) {
    final goalKeywords = ['goal', 'target', 'objective', 'aim', 'plan', 'achieve', 'accomplish'];
    return goalKeywords.any((keyword) => message.contains(keyword));
  }
  
  static bool _isChallengeRelated(String message) {
    final challengeKeywords = ['challenge', 'competition', 'contest', 'difficult', 'hard', 'struggle'];
    return challengeKeywords.any((keyword) => message.contains(keyword));
  }
  
  static bool _isProgressInquiry(String message) {
    final progressKeywords = ['how am i doing', 'my progress', 'how far', 'where am i', 'status', 'update', 'report'];
    return progressKeywords.any((keyword) => message.contains(keyword));
  }
  
  static bool _isMotivationalRequest(String message) {
    final motivationKeywords = ['motivate', 'inspire', 'encourage', 'help me', 'feeling down', 'give up', 'discouraged', 'stuck'];
    return motivationKeywords.any((keyword) => message.contains(keyword));
  }
  
  static bool _isComplexQuestion(String message) {
    return message.contains('?') && message.split(' ').length > 5;
  }
  
  static String _getSuggestedResponseLength(bool isGreeting, bool isComplexQuestion, bool isMotivationalRequest) {
    if (isGreeting) return 'short'; // 30-60 words
    if (isComplexQuestion || isMotivationalRequest) return 'detailed'; // 150-250 words
    return 'medium'; // 80-120 words
  }

  /// Builds a personalized AI prompt with intelligent context filtering
  static String buildPersonalizedPrompt(Map<String, dynamic> context, String userMessage) {
    // Analyze what context is actually needed
    final messageAnalysis = analyzeMessageContext(userMessage);
    final userProfile = context['user'] as Map<String, dynamic>? ?? {};
    final goalsToday = context['goals_today'] as Map<String, dynamic>? ?? {};
    final mainGoals = context['main_goals'] as Map<String, dynamic>? ?? {};
    final activity = context['activity_patterns'] as Map<String, dynamic>? ?? {};
    final challenges = context['challenges'] as Map<String, dynamic>? ?? {};

    final userName = userProfile['name'] as String? ?? 'User';
    final userAge = userProfile['age'] as int? ?? 12;
    final responseLength = messageAnalysis['suggestedResponseLength'] as String;
    
    // Build base prompt
    String prompt = '''You are Questor, a friendly and encouraging AI leadership coach for kids aged 8-16. You help with goal-setting, self-development, and building leadership skills.''';
    
    // Add user profile only if needed
    if (messageAnalysis['needsUserProfile'] == true) {
      prompt += '''\n\nUSER PROFILE:\n- Name: $userName (Age: $userAge)''';
    }
    
    // Add goal context only if relevant
    if (messageAnalysis['needsGoalContext'] == true) {
      final completedToday = goalsToday['completed'] as int? ?? 0;
      final totalToday = goalsToday['total'] as int? ?? 0;
      final mainGoalsList = mainGoals['goals'] as List? ?? [];
      
      if (totalToday > 0 || mainGoalsList.isNotEmpty) {
        prompt += '''\n\nGOAL PROGRESS:''';
        if (totalToday > 0) {
          prompt += '''\n- Today: $completedToday/$totalToday daily goals completed''';
        }
        if (mainGoalsList.isNotEmpty) {
          prompt += '''\n- Main Goals: ${_formatMainGoalsForPrompt(mainGoalsList)}''';
        }
      }
    }
    
    // Add challenge context only if relevant
    if (messageAnalysis['needsChallengeContext'] == true) {
      final activeChallenges = challenges['active_challenges'] as List? ?? [];
      if (activeChallenges.isNotEmpty) {
        prompt += '''\n\nACTIVE CHALLENGES:\n${activeChallenges.map((c) => "• ${c['title']}").join('\n')}''';
      }
    }
    
    // Add progress context only if specifically requested
    if (messageAnalysis['needsProgressContext'] == true) {
      final currentStreak = activity['current_streak'] as int? ?? 0;
      if (currentStreak > 0) {
        prompt += '''\n\nCURRENT STREAK: $currentStreak days''';
      }
    }
    
    // Response length guidelines based on message analysis
    String lengthGuideline;
    switch (responseLength) {
      case 'short':
        lengthGuideline = 'Keep your response brief and friendly (30-60 words). Perfect for greetings and simple acknowledgments.';
        break;
      case 'detailed':
        lengthGuideline = 'Provide a comprehensive, thoughtful response (150-250 words) with specific advice, examples, and follow-up questions.';
        break;
      default:
        lengthGuideline = 'Provide a balanced response (80-120 words) that addresses their question with helpful insights.';
    }
    
    prompt += '''\n\nCOACHING GUIDELINES:\n- Use $userName's name naturally when appropriate\n- Be encouraging and age-appropriate for a $userAge-year-old\n- $lengthGuideline\n- Focus on what's most relevant to their message\n- Only reference context information if it directly relates to their question\n- Be genuine and avoid forcing irrelevant information into your response\n\nRespond as Questor would - friendly, supportive, and focused on what $userName actually needs right now!''';
    
    return prompt;
  }

  /// Builds an autonomous message prompt for proactive coaching
  static String buildAutonomousPrompt(Map<String, dynamic> context) {
    // For autonomous messages, we want comprehensive context since we're being proactive
    final userProfile = context['user'] as Map<String, dynamic>? ?? {};
    final goalsToday = context['goals_today'] as Map<String, dynamic>? ?? {};
    final mainGoals = context['main_goals'] as Map<String, dynamic>? ?? {};
    final activity = context['activity_patterns'] as Map<String, dynamic>? ?? {};
    final challenges = context['challenges'] as Map<String, dynamic>? ?? {};
    final userName = userProfile['name'] as String? ?? 'User';
    final userAge = userProfile['age'] as int? ?? 12;
    final completedToday = goalsToday['completed'] as int? ?? 0;
    final totalToday = goalsToday['total'] as int? ?? 0;
    final currentStreak = activity['current_streak'] as int? ?? 0;
    final mainGoalsList = mainGoals['goals'] as List? ?? [];
    final activeChallenges = challenges['active_challenges'] as List? ?? [];
    
    String prompt = '''You are Questor, a friendly and encouraging AI leadership coach for kids aged 8-16. You help with goal-setting, self-development, and building leadership skills.

USER PROFILE:
- Name: $userName (Age: $userAge)''';
    
    // Add relevant context for autonomous messaging
    if (totalToday > 0) {
      prompt += '''\n- Today: $completedToday/$totalToday daily goals completed''';
    }
    
    if (currentStreak > 0) {
      prompt += '''\n- Current streak: $currentStreak days''';
    }
    
    if (mainGoalsList.isNotEmpty) {
      prompt += '''\n- Main Goals: ${_formatMainGoalsForPrompt(mainGoalsList)}''';
    }
    
    if (activeChallenges.isNotEmpty) {
      prompt += '''\n- Active Challenges: ${activeChallenges.map((c) => c['title']).join(', ')}''';
    }
    
    prompt += '''\n\nAUTONOMOUS MESSAGE INSTRUCTIONS:
You are proactively reaching out to help and encourage. Generate a brief, personalized message (30-50 words) that:
- Acknowledges their recent progress or current situation
- Provides encouragement or a helpful tip
- Feels natural and supportive, not robotic
- Includes their name
- Focuses on one specific aspect of their leadership journey

Examples of good autonomous messages:
- "Hey Sarah! I noticed you completed 3/5 goals today - that's great progress! Tomorrow, try tackling your hardest goal first when your energy is highest. You've got this! 🌟"
- "Hi Alex! Your 5-day streak is amazing! Leaders build strong habits just like you're doing. What leadership skill do you want to focus on next? 💪"

Generate ONE autonomous message now:''';
    
    return prompt;
  }

  static String _formatMainGoalsForPrompt(List goals) {
    if (goals.isEmpty) return "No main goals set";
    
    return goals.map((g) {
      return "• ${g['title']} - ${g['progress']}% complete (${g['category']})";
    }).join('\n');
  }

  static int _calculateGoalStreak(List<DailyGoalModel> dailyGoals) {
    if (dailyGoals.isEmpty) return 0;
    
    // Sort goals by date (most recent first)
    final sortedGoals = dailyGoals.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    // Check each day going backwards
    for (int i = 0; i < 30; i++) { // Check up to 30 days
      final checkDate = currentDate.subtract(Duration(days: i));
      final dayGoals = sortedGoals.where((g) => 
        g.date.year == checkDate.year &&
        g.date.month == checkDate.month &&
        g.date.day == checkDate.day
      ).toList();
      
      if (dayGoals.isEmpty) {
        // No goals for this day - streak might continue if it's today
        if (i == 0) continue;
        break;
      }
      
      // Check if any goals were completed this day
      final hasCompletedGoals = dayGoals.any((g) => g.isCompleted);
      if (hasCompletedGoals) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }



  static Map<String, dynamic> _getDefaultContext() {
    return {
      'user': {
        'name': 'User',
        'age': 12,
        'coins': 0.0,
        'xp': 0,
        'level': 1,
      },
      'goals_today': {
        'completed': 0,
        'total': 0,
        'completion_rate': 0,
        'goals': [],
      },
      'main_goals': {
        'count': 0,
        'average_progress': 0,
        'goals': [],
      },
      'activity_patterns': {
        'current_streak': 0,
        'weekly_completion_rate': 0,
        'total_goals_this_week': 0,
      },
      'challenges': {
        'active_count': 0,
        'active_challenges': [],
      },
      'gratitude': {
        'recent_entries': [],
        'has_entries': false,
      },
      'engagement_level': 'Getting Started',
    };
  }
}
