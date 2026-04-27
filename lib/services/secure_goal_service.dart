import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/badge_service.dart';
import '../services/challenge_evaluator.dart';
import '../providers/user_provider.dart';

/// Secure goal completion service with comprehensive anti-gaming measures.
///
/// Anti-gaming layers implemented:
///  1. Ownership validation   — goal must belong to the calling user
///  2. Valid completion time  — goal date must be today or in the past
///  3. WAT-aware daily cap    — max 15 completions per calendar day (Africa/Lagos)
///  4. Server-side authority  — RPC `complete_goal_secure` enforces the same cap;
///                              client-side check is a UX pre-filter only
///
/// WAT = West Africa Time (UTC+1), used by Nigeria / pearlsgardenhub users.
class SecureGoalService {
  static final SecureGoalService _instance = SecureGoalService._internal();
  factory SecureGoalService() => _instance;
  SecureGoalService._internal();

  final _supabaseService = SupabaseService();
  UserProvider? _userProvider;

  /// Maximum goal completions allowed per calendar day (WAT).
  /// The design allows 3 daily goals per main goal × max 3 active main goals = 9.
  /// Must match the cap enforced inside `complete_goal_secure` on the server.
  static const int _maxDailyCompletions = 9;

  /// West Africa Time offset from UTC.
  static const Duration _watOffset = Duration(hours: 1);

  /// Initialize with UserProvider for local state updates.
  void initialize(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  // ─────────────────────────── public API ────────────────────────────────────

  /// Complete a daily goal with security validation.
  /// Returns `true` on success, `false` on any failure (limit, auth, server).
  Future<bool> completeDailyGoal(String goalId) async {
    try {
      final user    = _supabaseService.client.auth.currentUser;
      final session = _supabaseService.client.auth.currentSession;

      debugPrint(
        'Completing goal $goalId — user ${user != null ? "ok" : "null"}, '
        'session ${session != null ? "ok" : "null"}',
      );

      if (user == null) {
        debugPrint('[SecureGoalService] Auth failed: no current user');
        throw Exception('User must be authenticated to complete goals');
      }

      // 1. Validate ownership
      final goal = await _validateGoalOwnership(goalId);
      if (goal == null) throw Exception('Goal not found or access denied');

      // 2. Already completed?
      if (goal.isCompleted) {
        debugPrint('[SecureGoalService] Goal already completed: $goalId');
        return false;
      }

      // 3. Valid timing (not future)
      if (!_isValidCompletionTime(goal.date)) {
        throw Exception('Goal cannot be completed in the future');
      }

      // 4. WAT-aware client-side daily cap (pre-flight UX check).
      //    Server enforces the same cap; this saves a round-trip for obvious cases.
      if (!await _checkDailyCompletionLimits()) {
        throw Exception(
          'Daily goal completion limit reached ($_maxDailyCompletions per day). '
          'Come back tomorrow!',
        );
      }

      // 5. Atomic server-side completion + rewards
      return await _atomicGoalCompletion(goalId, goal);
    } catch (e) {
      debugPrint('[SecureGoalService] completeDailyGoal error: $e');
      return false;
    }
  }

  // ─────────────────────────── private helpers ───────────────────────────────

  /// Returns the start of the current day in WAT expressed as UTC,
  /// and the exclusive end (start of tomorrow in WAT as UTC).
  ///
  /// Example: if WAT midnight is 2024-03-15 00:00 WAT = 2024-03-14 23:00 UTC,
  /// start = 2024-03-14T23:00:00Z, end = 2024-03-15T23:00:00Z.
  ({DateTime start, DateTime end}) _getTodayBoundsInWat() {
    final nowUtc = DateTime.now().toUtc();
    final nowWat = nowUtc.add(_watOffset);

    // Midnight today in WAT → convert back to UTC for DB comparison
    final midnightWat = DateTime(nowWat.year, nowWat.month, nowWat.day);
    final startUtc    = midnightWat.subtract(_watOffset);
    final endUtc      = startUtc.add(const Duration(days: 1));

    return (start: startUtc, end: endUtc);
  }

  /// Validate goal ownership and return a populated model.
  Future<DailyGoalModel?> _validateGoalOwnership(String goalId) async {
    try {
      final response = await _supabaseService.client
          .from('daily_goals')
          .select()
          .eq('id', goalId)
          .eq('user_id', _supabaseService.currentUser!.id)
          .single();

      return DailyGoalModel(
        id:          response['id'],
        userId:      response['user_id'],
        title:       response['title'],
        date:        DateTime.parse(response['date']),
        isCompleted: response['is_completed'] ?? false,
        mainGoalId:  response['main_goal_id'],
        xpValue:     response['xp_value'] ?? 10,
      );
    } catch (e) {
      debugPrint('[SecureGoalService] _validateGoalOwnership error: $e');
      return null;
    }
  }

  /// Validate completion timing — goal must not be in the future.
  bool _isValidCompletionTime(DateTime goalDate) {
    final nowWat  = DateTime.now().toUtc().add(_watOffset);
    final todayWat = DateTime(nowWat.year, nowWat.month, nowWat.day);
    final goalDay  = DateTime(goalDate.year, goalDate.month, goalDate.day);
    return goalDay.isBefore(todayWat) || goalDay.isAtSameMomentAs(todayWat);
  }

  /// WAT-aware client-side daily completion limit check.
  ///
  /// Uses UTC boundaries that correspond to WAT midnight so the counter
  /// resets at midnight Nigeria time, not UTC midnight (which would allow users
  /// to complete 10 goals just before UTC midnight and 10 more immediately after).
  Future<bool> _checkDailyCompletionLimits() async {
    try {
      final bounds = _getTodayBoundsInWat();

      final response = await _supabaseService.client
          .from('goal_completions')
          .select('id')
          .eq('user_id', _supabaseService.currentUser!.id)
          .gte('completed_at', bounds.start.toIso8601String())
          .lt('completed_at',  bounds.end.toIso8601String());

      final completionsToday = response.length;
      debugPrint(
        '[SecureGoalService] Daily completions today (WAT): '
        '$completionsToday / $_maxDailyCompletions',
      );

      return completionsToday < _maxDailyCompletions;
    } catch (e) {
      debugPrint('[SecureGoalService] _checkDailyCompletionLimits error: $e');
      // Fail-safe: deny if we cannot verify
      return false;
    }
  }

  /// Calls the server-side `complete_goal_secure` RPC — single source of truth.
  /// The server enforces its own daily cap; this call is authoritative.
  Future<bool> _atomicGoalCompletion(String goalId, DailyGoalModel goal) async {
    try {
      debugPrint('[SecureGoalService] RPC complete_goal_secure → $goalId');
      final userId = _supabaseService.currentUser!.id;

      final result = await _supabaseService.client.rpc(
        'complete_goal_secure',
        params: {
          'p_user_id':    userId,
          'p_goal_id':    goalId,
          'p_xp_reward':  goal.xpValue,
          'p_coin_reward': 0.5,
        },
      );

      final resultMap = Map<String, dynamic>.from(result as Map);
      debugPrint('[SecureGoalService] RPC result: $resultMap');

      // ── Server returned daily_limit_reached ─────────────────────────────────
      if (resultMap['error'] == 'daily_limit_reached') {
        debugPrint(
          '[SecureGoalService] Server rejected: daily limit reached '
          '(${resultMap['completions_today']}/$_maxDailyCompletions)',
        );
        return false;
      }

      if (resultMap['success'] != true) {
        debugPrint('[SecureGoalService] Goal completion rejected: ${resultMap['error']}');
        return false;
      }

      // ── Success: update local state for immediate UI feedback ───────────────
      if (resultMap['already_completed'] != true) {
        final xpAwarded     = (resultMap['xp_awarded']     as num?)?.toInt()    ?? 0;
        final coinsAwarded  = (resultMap['coins_awarded']   as num?)?.toDouble() ?? 0.0;

        if (_userProvider != null) {
          _userProvider!.updateLocalXp(xpAwarded);
          _userProvider!.updateLocalCoins(coinsAwarded);
        }

        debugPrint(
          '[SecureGoalService] Goal $goalId completed: '
          '+$xpAwarded XP (${resultMap['completions_today']}/$_maxDailyCompletions today)',
        );
      }

      // ── Post-completion: badge & challenge evaluation ───────────────────────
      try {
        await BadgeService().checkForAchievements();
      } catch (e) {
        debugPrint('[SecureGoalService] Badge check error: $e');
      }
      try {
        await ChallengeEvaluator.instance.evaluateGoalChallenges();
      } catch (e) {
        debugPrint('[SecureGoalService] Challenge eval error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('[SecureGoalService] _atomicGoalCompletion error: $e');
      return false;
    }
  }

  // ─────────────────────────── goal creation ─────────────────────────────────

  /// Create a daily goal with validation and WAT-aware duplicate guard.
  Future<DailyGoalModel?> createDailyGoal({
    required String mainGoalId,
    required String title,
    DateTime? date,
  }) async {
    try {
      if (!_supabaseService.isAuthenticated) {
        throw Exception('User must be authenticated');
      }

      if (!await _checkDailyCreationLimits()) {
        throw Exception('Daily goal creation limit reached');
      }

      if (!await _validateMainGoalOwnership(mainGoalId)) {
        throw Exception('Invalid main goal reference');
      }

      final goalDate = date ?? DateTime.now();

      // Prevent creating goals for dates older than 1 day
      if (_isGoalTooOld(goalDate)) {
        throw Exception('Cannot create goals more than 1 day in the past');
      }

      final response = await _supabaseService.client
          .from('daily_goals')
          .insert({
            'user_id':      _supabaseService.currentUser!.id,
            'main_goal_id': mainGoalId,
            'title':        title,
            'date':         goalDate.toIso8601String(),
            'is_completed': false,
            'xp_value':     10,
            'created_at':   DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return DailyGoalModel(
        id:          response['id'],
        userId:      response['user_id'],
        title:       response['title'],
        date:        DateTime.parse(response['date']),
        isCompleted: false,
        mainGoalId:  response['main_goal_id'],
        xpValue:     response['xp_value'],
      );
    } catch (e) {
      // Propagate the server trigger error (anti_gaming) so the caller can surface it
      debugPrint('[SecureGoalService] createDailyGoal error: $e');
      return null;
    }
  }

  /// WAT-aware daily creation limit check (max 5 user-initiated goal creations per day).
  Future<bool> _checkDailyCreationLimits() async {
    try {
      final bounds = _getTodayBoundsInWat();

      final response = await _supabaseService.client
          .from('daily_goals')
          .select('id')
          .eq('user_id', _supabaseService.currentUser!.id)
          .gte('created_at', bounds.start.toIso8601String())
          .lt('created_at',  bounds.end.toIso8601String());

      // 3 daily goals/day is the app design limit (shown as "3/3" in the UI).
      // Creation is per-day total across all main goals (the user-initiated path).
      // AI-generated goals are handled separately via RPC and bypass this check.
      const maxDailyGoals = 3;
      debugPrint(
        '[SecureGoalService] Daily goals created today (WAT): '
        '${response.length} / $maxDailyGoals',
      );
      return response.length < maxDailyGoals;
    } catch (e) {
      debugPrint('[SecureGoalService] _checkDailyCreationLimits error: $e');
      return false;
    }
  }

  /// Validate main goal ownership.
  Future<bool> _validateMainGoalOwnership(String mainGoalId) async {
    try {
      final response = await _supabaseService.client
          .from('main_goals')
          .select('id')
          .eq('id', mainGoalId)
          .eq('user_id', _supabaseService.currentUser!.id);
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('[SecureGoalService] _validateMainGoalOwnership error: $e');
      return false;
    }
  }

  /// Returns true if the goal date is more than 1 day in the past.
  bool _isGoalTooOld(DateTime goalDate) {
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
    return goalDate.isBefore(oneDayAgo);
  }

  /// Get user's completion stats for admin monitoring.
  Future<Map<String, dynamic>> getUserCompletionStats() async {
    try {
      final response = await _supabaseService.client.rpc(
        'get_user_completion_stats',
        params: {'user_id': _supabaseService.currentUser!.id},
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[SecureGoalService] getUserCompletionStats error: $e');
      return {};
    }
  }
}
