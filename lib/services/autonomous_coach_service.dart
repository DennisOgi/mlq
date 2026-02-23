import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/ai_coach_service.dart';
import '../services/user_data_aggregator.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';

class AutonomousCoachService {
  static final AutonomousCoachService _instance = AutonomousCoachService._internal();
  factory AutonomousCoachService() => _instance;
  static AutonomousCoachService get instance => _instance;
  
  final UserDataAggregator _userDataAggregator = UserDataAggregator.instance;
  final AiCoachService _aiCoachService = AiCoachService.instance;
  
  // Stream controller for autonomous messages
  final StreamController<AutonomousMessage> _messageController = 
      StreamController<AutonomousMessage>.broadcast();
  
  /// Stream of autonomous messages
  Stream<AutonomousMessage> get messageStream => _messageController.stream;
  
  /// Expose message controller for testing
  StreamController<AutonomousMessage> get messageController => _messageController;
  
  Timer? _scheduledTimer;
  bool _isEnabled = true;
  
  // Resource optimization: Cache provider references
  Map<String, dynamic>? _cachedProviders;
  DateTime? _lastDataAggregation;
  Map<String, dynamic>? _cachedUserSnapshot;
  
  // Resource limits
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const int _maxFallbackMessages = 10;
  
  AutonomousCoachService._internal() {
    _initializeScheduling();
  }
  
  /// Initialize scheduled coaching sessions
  void _initializeScheduling() {
    // Schedule coaching messages 3 times per day
    // Morning: 9 AM, Midday: 1 PM, Evening: 7 PM
    _scheduleNextMessage();
  }
  
  /// Schedule the next autonomous coaching message
  void _scheduleNextMessage() {
    if (!_isEnabled) return;
    
    final now = DateTime.now();
    final scheduledTimes = [9, 13, 19]; // 9 AM, 1 PM, 7 PM
    
    // Find next scheduled time
    DateTime? nextScheduled;
    for (final hour in scheduledTimes) {
      final scheduledToday = DateTime(now.year, now.month, now.day, hour);
      if (scheduledToday.isAfter(now)) {
        nextScheduled = scheduledToday;
        break;
      }
    }
    
    // If no more times today, schedule for tomorrow morning
    nextScheduled ??= DateTime(now.year, now.month, now.day + 1, 9);
    
    final delay = nextScheduled.difference(now);
    debugPrint('Autonomous Coach: Next message scheduled in ${delay.inMinutes} minutes');
    
    _scheduledTimer?.cancel();
    _scheduledTimer = Timer(delay, () {
      _triggerScheduledMessage();
      _scheduleNextMessage(); // Schedule the next one
    });
  }
  
  /// Initialize the autonomous coach service
  void initialize() {
    startAutonomousCoaching();
  }
  
  /// Start autonomous coaching with scheduled messages
  void startAutonomousCoaching() {
    _isEnabled = true;
    _scheduleNextMessage();
  }
  
  /// Cache providers for efficient scheduled messaging
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
    debugPrint('Autonomous Coach: Providers cached for efficient scheduling');
  }
  
  /// Manually trigger an autonomous message
  Future<void> triggerAutonomousMessage({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    // Cache providers for future scheduled messages
    cacheProviders(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
    
    final message = await generateAutonomousMessage(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
    
    if (message != null) {
      _messageController.add(message);
    }
  }
  
  /// Generate autonomous coaching message with caching optimization
  Future<AutonomousMessage?> generateAutonomousMessage({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    try {
      debugPrint('Autonomous Coach: Generating message...');
      
      // Check if we can use cached data to reduce resource usage
      Map<String, dynamic> userSnapshot;
      final now = DateTime.now();
      
      if (_cachedUserSnapshot != null && 
          _lastDataAggregation != null &&
          now.difference(_lastDataAggregation!).inMinutes < _cacheValidityDuration.inMinutes) {
        debugPrint('Autonomous Coach: Using cached user data');
        userSnapshot = _cachedUserSnapshot!;
      } else {
        debugPrint('Autonomous Coach: Aggregating fresh user data');
        // Generate fresh user data snapshot
        userSnapshot = await _userDataAggregator.aggregateUserData(
          userProvider: userProvider,
          goalProvider: goalProvider,
          challengeProvider: challengeProvider,
        );
        
        // Cache the data for future use
        _cachedUserSnapshot = userSnapshot;
        _lastDataAggregation = now;
      }
      
      if (userSnapshot.isEmpty) {
        debugPrint('Autonomous Coach: No user data available');
        return null;
      }
      
      // Generate AI response using the enhanced AI Coach service
      final aiResponse = await _aiCoachService.generateAutonomousMessage(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );
      
      // Create autonomous message from AI response
      final messageType = _determineMessageType(userSnapshot);
      final message = AutonomousMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: aiResponse,
        timestamp: DateTime.now(),
        type: messageType,
        questorImage: _selectQuestorImage(userSnapshot),
      );
        
      debugPrint('Autonomous Coach: Message generated - ${message.content.substring(0, 50)}...');
      return message;
      
    } catch (e) {
      debugPrint('Autonomous Coach: Error generating message: $e');
      return _getFallbackMessage();
    }
  }
  
  /// Trigger scheduled autonomous message
  void _triggerScheduledMessage() async {
    try {
      // Use cached provider references if available
      if (_cachedProviders != null) {
        final message = await generateAutonomousMessage(
          userProvider: _cachedProviders!['user'] as UserProvider,
          goalProvider: _cachedProviders!['goal'] as GoalProvider,
          challengeProvider: _cachedProviders!['challenge'] as ChallengeProvider,
        );
        
        if (message != null) {
          _messageController.add(message);
          return;
        }
      }
      
      // Fallback to simple message if no providers available
      final fallbackMessage = _getFallbackMessage();
      _messageController.add(fallbackMessage);
      
    } catch (e) {
      debugPrint('Autonomous Coach: Error in scheduled message: $e');
      // Always provide fallback to ensure user experience
      final fallbackMessage = _getFallbackMessage();
      _messageController.add(fallbackMessage);
    }
  }
  

  
  /// Enable/disable autonomous coaching
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled) {
      _scheduleNextMessage();
    } else {
      _scheduledTimer?.cancel();
    }
  }
  

  /// Determine message type based on user data
  String _determineMessageType(Map<String, dynamic> userSnapshot) {
    final context = userSnapshot['context'] ?? {};
    final timePeriod = context['time_period'] ?? 'morning';
    
    switch (timePeriod) {
      case 'morning':
        return 'Morning Boost';
      case 'afternoon':
        return 'Midday Check-in';
      case 'evening':
        return 'Evening Reflection';
      default:
        return 'Friendly Reminder';
    }
  }
  
  /// Select appropriate Questor image based on user mood/progress
  String _selectQuestorImage(Map<String, dynamic> userSnapshot) {
    final behavior = userSnapshot['behavior'] ?? {};
    final emotional = userSnapshot['emotional'] ?? {};
    
    final streak = behavior['currentStreak'] ?? 0;
    final moodScore = emotional['averageMoodScore'] ?? 0.5;
    
    if (streak >= 3 && moodScore > 0.7) {
      return 'assets/images/questor 4.png'; // Excited Questor
    } else if (moodScore > 0.6) {
      return 'assets/images/questor 2.png'; // Happy Questor
    } else {
      return 'assets/images/questor 3.png'; // Default friendly Questor
    }
  }
  
  /// Get fallback message when AI is unavailable
  AutonomousMessage _getFallbackMessage() {
    final fallbackMessages = [
      "Hey there! 🌟 Ready to tackle your goals today?",
      "You're doing amazing! 🎉 Keep up the great work!",
      "Time for a quick goal check-in! 📝 What's on your list?",
      "Remember: every small step counts! 👣✨",
      "You've got this! 💪 I believe in you!",
    ];
    
    final random = Random();
    final message = fallbackMessages[random.nextInt(fallbackMessages.length)];
    
    return AutonomousMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: message,
      timestamp: DateTime.now(),
      type: 'Friendly Reminder',
      questorImage: 'assets/images/questor 3.png',
    );
  }
  

  
  /// Dispose resources
  void dispose() {
    _scheduledTimer?.cancel();
    _messageController.close();
  }
}

/// Autonomous message model
class AutonomousMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final String type;
  final String questorImage;
  
  AutonomousMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.type,
    required this.questorImage,
  });
  
  @override
  String toString() {
    return 'AutonomousMessage(id: $id, content: $content, type: $type)';
  }
}
