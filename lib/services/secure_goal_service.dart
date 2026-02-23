import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/badge_service.dart';
import '../services/challenge_evaluator.dart';
import '../providers/user_provider.dart';

/// Secure goal completion service with anti-gaming measures
class SecureGoalService {
  static final SecureGoalService _instance = SecureGoalService._internal();
  factory SecureGoalService() => _instance;
  SecureGoalService._internal();

  final _supabaseService = SupabaseService();
  UserProvider? _userProvider;
  
  /// Initialize with UserProvider for local state updates
  void initialize(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  /// Complete a daily goal with security validation
  Future<bool> completeDailyGoal(String goalId) async {
    try {
      // Force refresh authentication state
      final user = _supabaseService.client.auth.currentUser;
      final session = _supabaseService.client.auth.currentSession;
      
      debugPrint('Completing goal $goalId - Auth state: user ${user != null ? "exists" : "is null"}, session ${session != null ? "exists" : "is null"}');
      
      if (user == null) {
        debugPrint('Authentication failed: No current user found');
        throw Exception('User must be authenticated to complete goals');
      }

      // 1. Validate goal exists and belongs to user
      final goal = await _validateGoalOwnership(goalId);
      if (goal == null) {
        throw Exception('Goal not found or access denied');
      }

      // 2. Check if already completed today
      if (goal.isCompleted) {
        debugPrint('Goal already completed: $goalId');
        return false;
      }

      // 3. Validate completion timing (prevent future dating)
      if (!_isValidCompletionTime(goal.date)) {
        throw Exception('Invalid completion time - goal cannot be completed in the future');
      }

      // 4. Check daily completion limits
      if (!await _checkDailyCompletionLimits()) {
        throw Exception('Daily goal completion limit reached');
      }

      // 5. Server-side atomic transaction for completion + reward
      final success = await _atomicGoalCompletion(goalId, goal);
      
      if (success) {
        debugPrint('Goal completed securely: $goalId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Secure goal completion failed: $e');
      return false;
    }
  }

  /// Validate goal ownership and existence
  Future<DailyGoalModel?> _validateGoalOwnership(String goalId) async {
    try {
      final response = await _supabaseService.client
          .from('daily_goals')
          .select()
          .eq('id', goalId)
          .eq('user_id', _supabaseService.currentUser!.id)
          .single();

      return DailyGoalModel(
        id: response['id'],
        userId: response['user_id'],
        title: response['title'],
        date: DateTime.parse(response['date']),
        isCompleted: response['is_completed'] ?? false,
        mainGoalId: response['main_goal_id'],
        xpValue: response['xp_value'] ?? 10,
      );
    } catch (e) {
      debugPrint('Goal validation failed: $e');
      return null;
    }
  }

  /// Validate completion timing (prevent future dating)
  bool _isValidCompletionTime(DateTime goalDate) {
    final now = DateTime.now();
    final goalDay = DateTime(goalDate.year, goalDate.month, goalDate.day);
    final today = DateTime(now.year, now.month, now.day);
    
    // Goal can only be completed on or after its date, but not in the future
    return goalDay.isBefore(today) || goalDay.isAtSameMomentAs(today);
  }

  /// Check daily completion limits (prevent goal farming)
  Future<bool> _checkDailyCompletionLimits() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final response = await _supabaseService.client
          .from('goal_completions')
          .select('id')
          .eq('user_id', _supabaseService.currentUser!.id)
          .gte('completed_at', startOfDay.toIso8601String())
          .lte('completed_at', endOfDay.toIso8601String());

      final completionsToday = response.length;
      const maxDailyCompletions = 10; // Reasonable daily limit

      return completionsToday < maxDailyCompletions;
    } catch (e) {
      debugPrint('Daily limit check failed: $e');
      return false; // Fail safe - deny completion if check fails
    }
  }

  /// Atomic goal completion with reward distribution (server-side)
  Future<bool> _atomicGoalCompletion(String goalId, DailyGoalModel goal) async {
    try {
      debugPrint('Completing goal via secure RPC: $goalId');
      final userId = _supabaseService.currentUser!.id;
      
      // Use server-side atomic function for all reward logic
      final result = await _supabaseService.client.rpc('complete_goal_secure', params: {
        'p_user_id': userId,
        'p_goal_id': goalId,
        'p_xp_reward': goal.xpValue,
        'p_coin_reward': 0.5,
      });
      
      final resultMap = Map<String, dynamic>.from(result as Map);
      debugPrint('Secure goal completion result: $resultMap');
      
      if (resultMap['success'] != true) {
        debugPrint('Goal completion failed: ${resultMap['error']}');
        return false;
      }
      
      // Update local state for immediate UI feedback
      if (resultMap['already_completed'] != true) {
        final xpAwarded = (resultMap['xp_awarded'] as num?)?.toInt() ?? 0;
        final coinsAwarded = (resultMap['coins_awarded'] as num?)?.toDouble() ?? 0.0;
        
        if (_userProvider != null) {
          // Update local state only (server already updated DB)
          _userProvider!.updateLocalXp(xpAwarded);
          _userProvider!.updateLocalCoins(coinsAwarded);
        }
        
        debugPrint('Goal completion fully processed: $goalId with $xpAwarded XP');
      }
      
      // Check for badge achievements after successful goal completion
      try {
        final badgeService = BadgeService();
        await badgeService.checkForAchievements();
      } catch (badgeError) {
        debugPrint('Error checking badges after goal completion: $badgeError');
      }
      
      // Trigger goal-specific challenge evaluation
      try {
        await ChallengeEvaluator.instance.evaluateGoalChallenges();
      } catch (evalErr) {
        debugPrint('Challenge evaluation after goal completion failed: $evalErr');
      }
      
      return true;
    } catch (e) {
      debugPrint('Atomic completion failed: $e');
      return false;
    }
  }

  /// Create goal with validation
  Future<DailyGoalModel?> createDailyGoal({
    required String mainGoalId,
    required String title,
    DateTime? date,
  }) async {
    try {
      if (!_supabaseService.isAuthenticated) {
        throw Exception('User must be authenticated');
      }

      // Validate daily goal creation limits
      if (!await _checkDailyCreationLimits()) {
        throw Exception('Daily goal creation limit reached');
      }

      // Validate main goal ownership
      if (!await _validateMainGoalOwnership(mainGoalId)) {
        throw Exception('Invalid main goal reference');
      }

      final goalDate = date ?? DateTime.now();
      
      // Prevent creating goals in the past (more than 1 day ago)
      if (_isGoalTooOld(goalDate)) {
        throw Exception('Cannot create goals more than 1 day in the past');
      }

      final response = await _supabaseService.client
          .from('daily_goals')
          .insert({
            'user_id': _supabaseService.currentUser!.id,
            'main_goal_id': mainGoalId,
            'title': title,
            'date': goalDate.toIso8601String(),
            'is_completed': false,
            'xp_value': 10,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return DailyGoalModel(
        id: response['id'],
        userId: response['user_id'],
        title: response['title'],
        date: DateTime.parse(response['date']),
        isCompleted: false,
        mainGoalId: response['main_goal_id'],
        xpValue: response['xp_value'],
      );
    } catch (e) {
      debugPrint('Secure goal creation failed: $e');
      return null;
    }
  }

  /// Check daily goal creation limits
  Future<bool> _checkDailyCreationLimits() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final response = await _supabaseService.client
          .from('daily_goals')
          .select('count')
          .eq('user_id', _supabaseService.currentUser!.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      const maxDailyGoals = 5; // Reasonable daily limit
      return response.length < maxDailyGoals;
    } catch (e) {
      debugPrint('Creation limit check failed: $e');
      return false;
    }
  }

  /// Validate main goal ownership
  Future<bool> _validateMainGoalOwnership(String mainGoalId) async {
    try {
      final response = await _supabaseService.client
          .from('main_goals')
          .select('id')
          .eq('id', mainGoalId)
          .eq('user_id', _supabaseService.currentUser!.id);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Main goal validation failed: $e');
      return false;
    }
  }

  /// Check if goal date is too old
  bool _isGoalTooOld(DateTime goalDate) {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(days: 1));
    return goalDate.isBefore(oneDayAgo);
  }

  /// Get user's completion stats for monitoring
  Future<Map<String, dynamic>> getUserCompletionStats() async {
    try {
      final response = await _supabaseService.client.rpc('get_user_completion_stats', params: {
        'user_id': _supabaseService.currentUser!.id,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Stats retrieval failed: $e');
      return {};
    }
  }
}
