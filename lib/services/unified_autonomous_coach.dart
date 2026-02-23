import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import 'autonomous_coach_service.dart';
import 'advanced_autonomous_coach.dart';

/// Unified service that coordinates both basic and advanced autonomous coaching
class UnifiedAutonomousCoach {
  static final UnifiedAutonomousCoach _instance = UnifiedAutonomousCoach._internal();
  static UnifiedAutonomousCoach get instance => _instance;
  
  UnifiedAutonomousCoach._internal();

  // Service instances
  late AutonomousCoachService _basicCoach;
  late AdvancedAutonomousCoach _advancedCoach;
  
  // Stream controllers for unified messaging
  final StreamController<dynamic> _unifiedMessageController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get unifiedMessageStream => _unifiedMessageController.stream;
  
  // Configuration
  bool _isAdvancedModeEnabled = true;
  bool _isCoachingEnabled = true;
  bool _isInitialized = false;
  Timer? _coordinationTimer;
  
  // Message coordination
  DateTime? _lastBasicMessage;
  DateTime? _lastAdvancedMessage;
  final Duration _minimumMessageInterval = const Duration(minutes: 30);
  
  // Provider caching
  Map<String, dynamic>? _cachedProviders;

  /// Initialize the unified coaching system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize basic coach
      _basicCoach = AutonomousCoachService.instance;
      _basicCoach.initialize();
      
      // Initialize advanced coach
      _advancedCoach = AdvancedAutonomousCoach.instance;
      // Advanced coach initializes automatically in constructor
      
      // Set up message coordination
      _setupMessageCoordination();
      
      // Start coordination timer
      _startCoordinationTimer();
      
      _isCoachingEnabled = true;
      
      _isInitialized = true;
      debugPrint('UnifiedAutonomousCoach initialized successfully');
      
    } catch (e) {
      debugPrint('Error initializing UnifiedAutonomousCoach: $e');
      rethrow;
    }
  }

  /// Set up message stream coordination
  void _setupMessageCoordination() {
    // Listen to basic coach messages
    _basicCoach.messageStream.listen((basicMessage) {
      _handleBasicMessage(basicMessage);
    });
    
    // Listen to advanced coach messages
    _advancedCoach.messageStream.listen((advancedMessage) {
      _handleAdvancedMessage(advancedMessage);
    });
  }

  /// Handle basic autonomous messages
  void _handleBasicMessage(AutonomousMessage basicMessage) {
    _lastBasicMessage = DateTime.now();
    
    if (_isAdvancedModeEnabled) {
      // In advanced mode, convert basic messages to advanced format
      final advancedMessage = _convertBasicToAdvanced(basicMessage);
      _unifiedMessageController.add(advancedMessage);
    } else {
      // In basic mode, pass through directly
      _unifiedMessageController.add(basicMessage);
    }
    
    debugPrint('Unified Coach: Processed basic message - ${basicMessage.type}');
  }

  /// Handle advanced autonomous messages
  void _handleAdvancedMessage(AdvancedAutonomousMessage advancedMessage) {
    _lastAdvancedMessage = DateTime.now();
    
    // Advanced messages always take priority
    _unifiedMessageController.add(advancedMessage);
    
    debugPrint('Unified Coach: Processed advanced message - ${advancedMessage.type}');
  }

  /// Convert basic message to advanced format
  AdvancedAutonomousMessage _convertBasicToAdvanced(AutonomousMessage basicMessage) {
    // Determine emotional tone based on message type
    String emotionalTone = 'friendly';
    switch (basicMessage.type) {
      case 'Morning Boost':
        emotionalTone = 'encouraging';
        break;
      case 'Midday Check-in':
        emotionalTone = 'supportive';
        break;
      case 'Evening Reflection':
        emotionalTone = 'compassionate';
        break;
    }
    
    return AdvancedAutonomousMessage(
      id: basicMessage.id,
      content: basicMessage.content,
      type: basicMessage.type,
      timestamp: basicMessage.timestamp,
      questorImage: basicMessage.questorImage,
      emotionalTone: emotionalTone,
      personalityState: {
        'empathy': 0.7,
        'enthusiasm': 0.6,
        'wisdom': 0.5,
        'playfulness': 0.4,
        'communication': 0.3,
      },
      predictiveInsight: null, // Basic messages don't have predictive insights
    );
  }

  /// Start coordination timer for intelligent message scheduling
  void _startCoordinationTimer() {
    _coordinationTimer?.cancel();
    
    // Check every 5 minutes for coordination opportunities
    _coordinationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _coordinateMessaging();
    });
  }

  /// Coordinate messaging between basic and advanced coaches
  void _coordinateMessaging() {
    if (!_isCoachingEnabled) return;
    
    final now = DateTime.now();
    
    // Check if we should suppress basic messages due to recent advanced activity
    if (_lastAdvancedMessage != null) {
      final timeSinceAdvanced = now.difference(_lastAdvancedMessage!);
      if (timeSinceAdvanced < _minimumMessageInterval) {
        // Temporarily disable basic coach to avoid message spam
        _basicCoach.setEnabled(false);
        
        // Re-enable after interval
        Timer(_minimumMessageInterval - timeSinceAdvanced, () {
          _basicCoach.setEnabled(true);
        });
      }
    }
    
    // Trigger predictive coaching check if conditions are right
    if (_isAdvancedModeEnabled && _shouldTriggerPredictiveCoaching()) {
      _triggerPredictiveCoaching();
    }
  }

  /// Check if predictive coaching should be triggered
  bool _shouldTriggerPredictiveCoaching() {
    final now = DateTime.now();
    
    // Don't trigger if we've had a recent message
    if (_lastAdvancedMessage != null) {
      final timeSinceAdvanced = now.difference(_lastAdvancedMessage!);
      if (timeSinceAdvanced < const Duration(hours: 2)) {
        return false;
      }
    }
    
    // Trigger during optimal coaching hours (10 AM - 8 PM)
    final hour = now.hour;
    if (hour < 10 || hour > 20) {
      return false;
    }
    
    // Random chance to avoid being too predictable
    return Random().nextDouble() < 0.3; // 30% chance every 5 minutes during optimal hours
  }

  /// Trigger predictive coaching analysis
  void _triggerPredictiveCoaching() async {
    try {
      // Generate a predictive message if providers are cached
      if (_cachedProviders != null) {
        final userProvider = _cachedProviders!['user'] as UserProvider;
        final goalProvider = _cachedProviders!['goal'] as GoalProvider;
        final challengeProvider = _cachedProviders!['challenge'] as ChallengeProvider;
        
        final message = await _advancedCoach.generateAdvancedMessage(
          userProvider: userProvider,
          goalProvider: goalProvider,
          challengeProvider: challengeProvider,
        );
        
        if (message != null) {
          _handleAdvancedMessage(message);
        }
      }
      debugPrint('Unified Coach: Triggered predictive coaching analysis');
    } catch (e) {
      debugPrint('Error triggering predictive coaching: $e');
    }
  }

  /// Cache providers for efficient messaging
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
    
    // Also cache in individual coaches
    _basicCoach.cacheProviders(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
    
    _advancedCoach.cacheProviders(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
    
    debugPrint('Unified Coach: Providers cached for efficient messaging');
  }

  /// Manually trigger unified coaching message
  Future<void> triggerUnifiedMessage({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
  }) async {
    try {
      if (!_isInitialized) {
        debugPrint('Unified Coach: Lazy initializing for manual trigger');
        await initialize();
      }
      
      // Cache providers for future use
      cacheProviders(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );
      
      if (_isAdvancedModeEnabled) {
        // Use advanced coach for manual triggers
        final message = await _advancedCoach.generateAdvancedMessage(
          userProvider: userProvider,
          goalProvider: goalProvider,
          challengeProvider: challengeProvider,
        );
        
        if (message != null) {
          _handleAdvancedMessage(message);
        }
      } else {
        // Use basic coach for manual triggers
        await _basicCoach.triggerAutonomousMessage(
          userProvider: userProvider,
          goalProvider: goalProvider,
          challengeProvider: challengeProvider,
        );
      }
    } catch (e) {
      debugPrint('Error triggering unified message: $e');
    }
  }

  /// Enable or disable advanced mode
  void setAdvancedMode(bool enabled) {
    _isAdvancedModeEnabled = enabled;
    
    // Advanced coach doesn't have enable/disable methods, it's always active
    // We control it through the _isAdvancedModeEnabled flag
    debugPrint('Unified Coach: Advanced mode ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get current coaching statistics
  Map<String, dynamic> getCoachingStats() {
    return {
      'isAdvancedModeEnabled': _isAdvancedModeEnabled,
      'lastBasicMessage': _lastBasicMessage?.toIso8601String(),
      'lastAdvancedMessage': _lastAdvancedMessage?.toIso8601String(),
      'basicCoachEnabled': true, // Basic coach is always available
      'advancedCoachEnabled': _isAdvancedModeEnabled,
    };
  }

  /// Enable the unified coaching system
  void enable() {
    _isCoachingEnabled = true;
    _basicCoach.setEnabled(true);
    // Advanced coach is always enabled, controlled by _isAdvancedModeEnabled flag
    _startCoordinationTimer();
  }

  /// Disable the unified coaching system
  void disable() {
    _isCoachingEnabled = false;
    _basicCoach.setEnabled(false);
    // Advanced coach doesn't have disable method, we use the flag
    _coordinationTimer?.cancel();
  }

  /// Check if the unified system is enabled
  bool get isEnabled => _isInitialized && _isCoachingEnabled;

  /// Dispose of resources
  void dispose() {
    _coordinationTimer?.cancel();
    _unifiedMessageController.close();
    _basicCoach.dispose();
    _advancedCoach.dispose();
  }
}
