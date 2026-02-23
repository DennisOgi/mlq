import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/gratitude_provider.dart';
import '../providers/mini_course_provider.dart';
import '../providers/challenge_provider.dart';
import '../services/supabase_service.dart';
import '../services/badge_service.dart';
import '../models/challenge_model.dart';
import '../models/models.dart';

// Evaluation result container (top-level, not nested inside a class)
class _Eval {
  final bool satisfied;
  final int progressCapped;
  const _Eval(this.satisfied, this.progressCapped);
}

// UI-facing completion event payload
class ChallengeCompletionEvent {
  final String challengeId;
  final String title;
  final int coinReward;
  final DateTime completedAt;
  const ChallengeCompletionEvent({
    required this.challengeId,
    required this.title,
    required this.coinReward,
    required this.completedAt,
  });
}

class ChallengeEvaluator {
  static final ChallengeEvaluator instance = ChallengeEvaluator._internal();
  ChallengeEvaluator._internal() {
    debugPrint('[Evaluator] ChallengeEvaluator instance created.');
  }

  Future<int> _countGratitudeEntries(DateTime start, DateTime end) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return 0;

      // Query database directly for accurate count
      final response = await SupabaseService()
          .client
          .from('gratitude_entries')
          .select('id')
          .eq('user_id', userId)
          .gte('date', start.toIso8601String())
          .lte('date', end.toIso8601String());

      debugPrint(
          '[Evaluator] Gratitude entries count: ${response.length} (${start.toIso8601String()} to ${end.toIso8601String()})');
      return response.length;
    } catch (e) {
      debugPrint('[Evaluator] Error counting gratitude entries: $e');
      return 0;
    }
  }

  /// Called when user joins a challenge so we can evaluate immediately.
  Future<void> onJoinedChallenge(String challengeId) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        debugPrint('[Evaluator] onJoinedChallenge aborted: no user');
        return;
      }

      // Try to get challenge from provider first, then fetch from DB if not found
      ChallengeModel? challenge = _challengeProvider?.getChallengeById(challengeId);
      if (challenge == null) {
        debugPrint('[Evaluator] onJoinedChallenge: challenge not in provider, fetching from DB');
        try {
          final challengeData = await _client
              .from('challenges')
              .select('*')
              .eq('id', challengeId)
              .maybeSingle();
          if (challengeData != null) {
            challenge = ChallengeModel.fromJson(challengeData);
          }
        } catch (e) {
          debugPrint('[Evaluator] Failed to fetch challenge from DB: $e');
        }
      }
      
      if (challenge == null) {
        debugPrint('[Evaluator] onJoinedChallenge: challenge not found: $challengeId');
        return;
      }
      if (challenge.type != ChallengeType.basic) {
        // Only basic challenges use template-driven auto evaluation
        return;
      }

      final uc = await _client
          .from('user_challenges')
          .select('id, is_completed')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (uc == null) {
        debugPrint(
            '[Evaluator] onJoinedChallenge: user_challenges row not found for $challengeId');
        return;
      }
      if ((uc['is_completed'] as bool?) == true) {
        return; // already completed
      }

      final userChallengeId = uc['id'] as String;
      debugPrint(
          '[Evaluator] onJoinedChallenge → evaluating $challengeId (uc=$userChallengeId)');
      await _evaluateChallenge(challenge, userChallengeId);
    } catch (e) {
      debugPrint('[Evaluator] onJoinedChallenge error: $e');
    }
  }

  final _completionCtrl =
      StreamController<ChallengeCompletionEvent>.broadcast();
  Stream<ChallengeCompletionEvent> get completionStream =>
      _completionCtrl.stream;

  UserProvider? _userProvider;
  GoalProvider? _goalProvider;
  GratitudeProvider? _gratitudeProvider;
  MiniCourseProvider? _miniCourseProvider;
  ChallengeProvider? _challengeProvider;

  SupabaseClient get _client => Supabase.instance.client;
  // Minimal retry mechanism to account for async provider updates landing shortly after a goal completes
  final Set<String> _pendingRetry = <String>{};
  final Map<String, DateTime> _lastEvaluation = <String, DateTime>{};
  static const Duration _evaluationCooldown = Duration(seconds: 5);

  void initialize({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
    required MiniCourseProvider miniCourseProvider,
    GratitudeProvider? gratitudeProvider,
  }) {
    _userProvider = userProvider;
    _goalProvider = goalProvider;
    _gratitudeProvider = gratitudeProvider;
    _miniCourseProvider = miniCourseProvider;
    _challengeProvider = challengeProvider;
    debugPrint('[Evaluator] ChallengeEvaluator initialized with providers.');
  }

  /// Evaluate all active challenges (use sparingly - prefer filtered methods)
  Future<void> evaluateAll() async {
    debugPrint('[Evaluator] evaluateAll() called.');
    await _evaluateChallengesWithFilter(null);
  }

  /// Evaluate only gratitude-related challenges
  Future<void> evaluateGratitudeChallenges() async {
    debugPrint('[Evaluator] evaluateGratitudeChallenges() called.');
    await _evaluateChallengesWithFilter(
        ['gratitude_streak_days', 'gratitude_count_in_window']);
  }

  /// Evaluate only goal-related challenges
  Future<void> evaluateGoalChallenges() async {
    debugPrint('[Evaluator] evaluateGoalChallenges() called.');
    await _evaluateChallengesWithFilter([
      'daily_goal_streak_days',
      'daily_goal_count_in_window',
      'main_goals_completed',
      'main_goal_count_in_window',
      'any_goals_completed',
    ]);
  }

  /// Evaluate only mini-course challenges
  Future<void> evaluateMiniCourseChallenges() async {
    debugPrint('[Evaluator] evaluateMiniCourseChallenges() called.');
    await _evaluateChallengesWithFilter(['mini_courses_completed']);
  }

  /// Internal method to evaluate challenges with optional rule type filter
  Future<void> _evaluateChallengesWithFilter(
      List<String>? ruleTypeFilter) async {
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) {
      debugPrint('[Evaluator] Aborting: User is not authenticated.');
      return;
    }

    List<UserChallengeModel> userChallenges;
    try {
      userChallenges = await SupabaseService().fetchUserChallenges();
      debugPrint(
          '[Evaluator] Found ${userChallenges.length} active challenges for user $userId.');
    } catch (e) {
      debugPrint('[Evaluator] CRITICAL: Failed to fetch user challenges: $e');
      return;
    }

    for (final userChallenge in userChallenges) {
      if (userChallenge.isCompleted) continue;

      // Use challenge from UserChallengeModel first, then try provider, then fetch from DB
      ChallengeModel? challenge = userChallenge.challenge;
      challenge ??= _challengeProvider?.getChallengeById(userChallenge.challengeId);
      
      if (challenge == null) {
        // Fetch from DB as last resort
        try {
          final challengeData = await _client
              .from('challenges')
              .select('*')
              .eq('id', userChallenge.challengeId)
              .maybeSingle();
          if (challengeData != null) {
            challenge = ChallengeModel.fromJson(challengeData);
          }
        } catch (e) {
          debugPrint('[Evaluator] Failed to fetch challenge from DB: $e');
        }
      }
      
      if (challenge == null) {
        debugPrint('[Evaluator] Challenge not found: ${userChallenge.challengeId}');
        continue;
      }
      if (challenge.type != ChallengeType.basic) continue;

      // If filter is provided, check if challenge has matching rule types
      if (ruleTypeFilter != null) {
        final hasMatchingRule =
            await _challengeHasRuleType(challenge.id, ruleTypeFilter);
        if (!hasMatchingRule) {
          debugPrint(
              '[Evaluator] Skipping ${challenge.title} - no matching rule types');
          continue;
        }
      }

      await _evaluateChallenge(challenge, userChallenge.id);
    }
  }

  /// Check if a challenge has any rules matching the given types
  Future<bool> _challengeHasRuleType(
      String challengeId, List<String> ruleTypes) async {
    try {
      final rules = await _client
          .from('challenge_rules')
          .select('rule_type')
          .eq('challenge_id', challengeId);

      for (final rule in rules) {
        if (ruleTypes.contains(rule['rule_type'])) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[Evaluator] Error checking rule types: $e');
      return false;
    }
  }

  Future<void> _evaluateChallenge(
      ChallengeModel challenge, String userChallengeId) async {
    // Use SupabaseService for consistent user ID retrieval
    final userId = _userProvider?.user?.id ?? SupabaseService().currentUser?.id;
    if (userId == null) {
      debugPrint('[Evaluator] _evaluateChallenge aborted: no user ID available');
      return;
    }

    try {
      final userCh = await _client
          .from('user_challenges')
          .select('id, is_completed, start_date, progress')
          .eq('id', userChallengeId)
          .single();

      if (userCh['is_completed'] as bool? ?? false) return; // already completed

      debugPrint(
          '[Evaluator] Evaluating challenge ${challenge.title} (${challenge.id}) for user $userId');

      // Fetch rules for this challenge
      final rules = await _client
          .from('challenge_rules')
          .select('*')
          .eq('challenge_id', challenge.id);

      if (rules.isEmpty) {
        return;
      }

      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (final r in rules) {
        final gid = (r['group_id'] as String?) ?? 'single_${r['id']}';
        groups.putIfAbsent(gid, () => []).add(Map<String, dynamic>.from(r));
      }

      bool allGroupsSatisfied = true;
      int totalProgress = 0;

      for (final entry in groups.entries) {
        final groupRules = entry.value;
        final op = (groupRules.first['group_operator'] as String?) ?? 'all';

        int satisfied = 0;
        int groupProgress = 0;

        for (final rule in groupRules) {
          final eval = await _evaluateRule(rule, challenge);
          groupProgress += eval.progressCapped;
          if (eval.satisfied) satisfied++;

          try {
            final rt = (rule['rule_type'] ?? '').toString();
            final target = (rule['target_value'] as int?) ?? 0;
            final wtype = (rule['window_type'] ?? '').toString();
            final wdays = (rule['window_value_days'] as int?) ?? 0;
            debugPrint(
                '[Evaluator]  · Rule $rt target=$target window=$wtype(${wdays > 0 ? wdays : '-'}) → progress=${eval.progressCapped} satisfied=${eval.satisfied}');
          } catch (_) {}
        }

        totalProgress += groupProgress;
        final groupSatisfied =
            op == 'any' ? (satisfied > 0) : (satisfied == groupRules.length);
        if (!groupSatisfied) {
          allGroupsSatisfied = false;
        }

        try {
          debugPrint(
              '[Evaluator] Group ${entry.key} op=$op → satisfied=$groupSatisfied (rulesSatisfied=$satisfied/${groupRules.length}, groupProgress=$groupProgress)');
        } catch (_) {}
      }

      await _client.from('user_challenges').update({
        'progress': totalProgress,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userChallengeId);

      try {
        debugPrint(
            '[Evaluator] Updated progress for ${challenge.id}: totalProgress=$totalProgress allGroupsSatisfied=$allGroupsSatisfied');
      } catch (_) {}

      if (allGroupsSatisfied) {
        debugPrint(
            '[Evaluator] All groups satisfied → completing challenge ${challenge.id}');
        await _completeChallenge(challenge, userChallengeId, userId);
      } else {
        // Retry mechanism with rate limiting
        final lastEval = _lastEvaluation[userChallengeId];
        final now = DateTime.now();

        // Only retry if not recently evaluated (5 second cooldown)
        if (lastEval == null ||
            now.difference(lastEval) > const Duration(seconds: 5)) {
          if (!_pendingRetry.contains(userChallengeId)) {
            _pendingRetry.add(userChallengeId);
            _lastEvaluation[userChallengeId] = now;

            // Retry after 1 second (increased from 600ms for better async handling)
            Future.delayed(const Duration(seconds: 1), () async {
              try {
                await _evaluateChallenge(challenge, userChallengeId);
              } finally {
                _pendingRetry.remove(userChallengeId);
              }
            });
          }
        } else {
          debugPrint(
              '[Evaluator] Skipping retry for $userChallengeId - recently evaluated');
        }
      }
    } catch (e) {
      debugPrint('ChallengeEvaluator._evaluateChallenge error: $e');
    }
  }

  Future<void> _completeChallenge(
      ChallengeModel challenge, String userChallengeId, String userId) async {
    try {
      // Use database function for atomic completion with locking
      final result = await _client.rpc('complete_challenge', params: {
        'p_user_challenge_id': userChallengeId,
        'p_coin_reward': challenge.coinReward,
        'p_challenge_id': challenge.id,
      });

      debugPrint('✅ Challenge completion result: $result');

      if (result['idempotent'] == true) {
        debugPrint('⚠️ Challenge was already completed (idempotent)');
        return;
      }

      // Update local user provider with new balance
      if (challenge.coinReward > 0 && result['new_balance'] != null) {
        try {
          final newBalance = result['new_balance'] as num;
          await _userProvider?.reinitializeUser();
          debugPrint('✅ User balance updated: $newBalance');
        } catch (e) {
          debugPrint('⚠️ Failed to update local balance: $e');
        }
      }

      // Process badge queue asynchronously (don't wait)
      _processBadgeQueue(userId).catchError((e) {
        debugPrint('⚠️ Badge queue processing failed: $e');
      });

      // Emit completion event for UI popup
      try {
        _completionCtrl.add(ChallengeCompletionEvent(
          challengeId: challenge.id,
          title: challenge.title,
          coinReward: challenge.coinReward,
          completedAt: DateTime.now(),
        ));
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ ChallengeEvaluator._completeChallenge error: $e');
      // Log to error_log table
      try {
        await _client.from('error_log').insert({
          'error_type': 'challenge_completion_client_error',
          'error_message': e.toString(),
          'context': {
            'user_challenge_id': userChallengeId,
            'challenge_id': challenge.id,
            'user_id': userId,
          },
        });
      } catch (_) {}
    }
  }

  Future<void> _processBadgeQueue(String userId) async {
    try {
      final badgeService = BadgeService();
      debugPrint('🏆 Processing badge queue for user $userId...');
      await badgeService.checkForAchievements();

      // Mark badge checks as processed
      await _client
          .from('badge_check_queue')
          .update({
            'processed': true,
            'processed_at': DateTime.now().toIso8601String()
          })
          .eq('user_id', userId)
          .eq('processed', false);
    } catch (e) {
      debugPrint('❌ Badge queue processing error: $e');
    }
  }

  Future<_Eval> _evaluateRule(
      Map<String, dynamic> rule, ChallengeModel challenge) async {
    try {
      final String ruleType = rule['rule_type'];
      final int target = (rule['target_value'] as int?) ?? 0;
      final bool consecutive = (rule['consecutive_required'] as bool?) ?? false;
      final String windowType = rule['window_type'];
      final int? windowDays = rule['window_value_days'] as int?;
      final int maxGapDays = (rule['max_gap_days'] as int?) ?? 0;

      DateTime windowStart;
      DateTime windowEnd;
      final now = DateTime.now();

      switch (windowType) {
        case 'rolling_days':
          final days = windowDays ?? 7;
          windowStart = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: days - 1));
          windowEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'per_user_enrollment':
          // Attempt to get the user's join date from user_challenges
          final enrollUserId = _userProvider?.user?.id ?? SupabaseService().currentUser?.id;
          DateTime joinDate = challenge.startDate;
          if (enrollUserId != null) {
            final uc = await _client
                .from('user_challenges')
                .select('start_date')
                .eq('user_id', enrollUserId)
                .eq('challenge_id', challenge.id)
                .maybeSingle();
            if (uc != null && uc['start_date'] != null) {
              joinDate = DateTime.parse(uc['start_date']);
            }
          }
          windowStart = DateTime(joinDate.year, joinDate.month, joinDate.day);
          // For per_user_enrollment, the window extends from join date to NOW
          // (or challenge end date if it's in the future, whichever is later)
          // This allows users to complete challenges even if the original end date passed
          final nowDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          windowEnd = challenge.endDate.isAfter(nowDate) ? challenge.endDate : nowDate;
          break;
        case 'fixed_window':
        default:
          windowStart = challenge.startDate;
          windowEnd = challenge.endDate;
      }

      debugPrint('[Evaluator] Rule $ruleType window: $windowStart to $windowEnd (type=$windowType)');

      switch (ruleType) {
        case 'gratitude_streak_days':
          final streak = await _computeGratitudeStreak(windowStart, windowEnd);
          final satisfied = streak >= target;
          final capped = streak < 0 ? 0 : (streak > target ? target : streak);
          return _Eval(satisfied, capped);
        case 'gratitude_count_in_window':
          final count = await _countGratitudeEntries(windowStart, windowEnd);
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        case 'daily_goal_streak_days':
          final streak = await _computeDailyGoalStreak(windowStart, windowEnd,
              maxGapDays: maxGapDays);
          final satisfied = streak >= target;
          final capped = streak < 0 ? 0 : (streak > target ? target : streak);
          return _Eval(satisfied, capped);
        case 'main_goals_completed':
          final count =
              await _countGoalsCompleted(windowStart, windowEnd, scope: 'main');
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        case 'any_goals_completed':
          final count =
              await _countGoalsCompleted(windowStart, windowEnd, scope: 'any');
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        case 'mini_courses_completed':
          final count =
              await _countMiniCoursesCompleted(windowStart, windowEnd);
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        case 'daily_goal_count_in_window':
          final count = await _countGoalsCompleted(windowStart, windowEnd,
              scope: 'daily');
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        case 'main_goal_count_in_window':
          final count =
              await _countGoalsCompleted(windowStart, windowEnd, scope: 'main');
          final capped = count < 0 ? 0 : (count > target ? target : count);
          return _Eval(count >= target, capped);
        default:
          return _Eval(false, 0);
      }
    } catch (e) {
      debugPrint('ChallengeEvaluator._evaluateRule error: $e');
      return _Eval(false, 0);
    }
  }

  Future<int> _computeGratitudeStreak(DateTime start, DateTime end) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return 0;

      // Normalize to UTC date boundaries for consistent timezone handling
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final startDate = DateTime.utc(start.year, start.month, start.day);
      final endDate = DateTime.utc(end.year, end.month, end.day);

      // Query database for gratitude entries
      final response = await SupabaseService()
          .client
          .from('gratitude_entries')
          .select('date')
          .eq('user_id', userId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('date', ascending: true);

      if (response.isEmpty) return 0;

      // Normalize all entry dates to UTC date-only
      final dates = <DateTime>{};
      for (final entry in response) {
        try {
          final dt = DateTime.parse(entry['date']).toUtc();
          dates.add(DateTime.utc(dt.year, dt.month, dt.day));
        } catch (_) {}
      }

      if (dates.isEmpty) return 0;

      // Count consecutive days ending today
      int streak = 0;
      DateTime cursor = today.isAfter(endDate) ? endDate : today;

      // Allow today to be empty (grace period until end of day)
      bool allowOneMissing = !dates.contains(today) && cursor == today;

      while (!cursor.isBefore(startDate)) {
        if (dates.contains(cursor)) {
          streak++;
          cursor = cursor.subtract(const Duration(days: 1));
        } else if (allowOneMissing && cursor == today) {
          // Today is allowed to be empty - grace period
          allowOneMissing = false;
          cursor = cursor.subtract(const Duration(days: 1));
        } else {
          break; // Streak broken
        }
      }

      debugPrint(
          '[Evaluator] Gratitude streak: $streak days (today grace: ${!dates.contains(today)})');
      return streak;
    } catch (e) {
      debugPrint('[Evaluator] Error computing gratitude streak: $e');
      return 0;
    }
  }

  Future<int> _computeDailyGoalStreak(DateTime start, DateTime end,
      {int maxGapDays = 0}) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return 0;

      // Normalize to UTC date boundaries
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final startDate = DateTime.utc(start.year, start.month, start.day);
      final endDate = DateTime.utc(end.year, end.month, end.day);

      // Query database for completed daily goals
      final response = await SupabaseService()
          .client
          .from('daily_goals')
          .select('date')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('date', ascending: true);

      if (response.isEmpty) return 0;

      // Normalize to UTC date-only set
      final completedDates = <DateTime>{};
      for (final goal in response) {
        try {
          final dt = DateTime.parse(goal['date']).toUtc();
          completedDates.add(DateTime.utc(dt.year, dt.month, dt.day));
        } catch (_) {}
      }

      if (completedDates.isEmpty) return 0;

      int streak = 0;
      int gaps = 0;
      DateTime cursor = today.isAfter(endDate) ? endDate : today;

      // Allow today to be empty (grace period)
      bool allowTodayMissing =
          !completedDates.contains(today) && cursor == today;

      while (!cursor.isBefore(startDate)) {
        if (completedDates.contains(cursor)) {
          streak++;
          cursor = cursor.subtract(const Duration(days: 1));
        } else if (allowTodayMissing && cursor == today) {
          // Today grace period
          allowTodayMissing = false;
          cursor = cursor.subtract(const Duration(days: 1));
        } else {
          gaps++;
          if (gaps > maxGapDays) break;
          cursor = cursor.subtract(const Duration(days: 1));
        }
      }

      debugPrint(
          '[Evaluator] Daily goal streak: $streak days (gaps: $gaps/$maxGapDays, today grace: ${!completedDates.contains(today)})');
      return streak;
    } catch (e) {
      debugPrint('[Evaluator] Error computing daily goal streak: $e');
      return 0;
    }
  }

  Future<int> _countGoalsCompleted(DateTime start, DateTime end,
      {required String scope}) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return 0;

      int count = 0;

      if (scope == 'daily' || scope == 'any') {
        final dailyResponse = await SupabaseService()
            .client
            .from('daily_goals')
            .select('id')
            .eq('user_id', userId)
            .eq('is_completed', true)
            .gte('date', start.toIso8601String())
            .lte('date', end.toIso8601String());
        count += dailyResponse.length;
        debugPrint(
            '[Evaluator] Daily goals completed: ${dailyResponse.length}');
      }

      if (scope == 'main' || scope == 'any') {
        // Main goals are completed when status='completed' or completed_at is set
        // We fetch updated_at as a fallback for completion time
        final mainResponse = await SupabaseService()
            .client
            .from('main_goals')
            .select('id, current_xp, total_xp_required, status, completed_at, updated_at')
            .eq('user_id', userId);

        // Filter completed goals within the window
        int mainCompleted = 0;
        for (final goal in mainResponse) {
          final status = goal['status'] as String?;
          final completedAtStr = goal['completed_at'] as String?;
          final updatedAtStr = goal['updated_at'] as String?;
          final currentXp = (goal['current_xp'] as int?) ?? 0;
          final totalXp = (goal['total_xp_required'] as int?) ?? 1;
          
          bool isCompleted = false;
          DateTime? effectiveCompletionDate;

          if (completedAtStr != null) {
            isCompleted = true;
            effectiveCompletionDate = DateTime.tryParse(completedAtStr);
          } else if (status == 'completed') {
            isCompleted = true;
            // Fallback to updated_at if completed_at is missing
            if (updatedAtStr != null) {
              effectiveCompletionDate = DateTime.tryParse(updatedAtStr);
            }
          } else if (currentXp >= totalXp) {
            isCompleted = true;
            // Fallback to updated_at if purely XP-based
            if (updatedAtStr != null) {
              effectiveCompletionDate = DateTime.tryParse(updatedAtStr);
            }
          }
          
          if (!isCompleted) continue;
          
          // If we have a date, check if it's in the window
          if (effectiveCompletionDate != null) {
            if (effectiveCompletionDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                effectiveCompletionDate.isBefore(end.add(const Duration(seconds: 1)))) {
              mainCompleted++;
            } else {
              debugPrint('[Evaluator] Main goal ${goal['id']} excluded: completed at $effectiveCompletionDate outside window $start - $end');
            }
          } else {
            // No date available - if it's completed, we might count it if the window is "all time" or "fixed" covering creation?
            // For safety, if we can't determine WHEN it was completed, we usually shouldn't count it for a specific window.
            // But for "per_user_enrollment", if the goal was created/updated during the enrollment, it might count.
            // Let's assume if updated_at is missing, it's very old or invalid.
            debugPrint('[Evaluator] Main goal ${goal['id']} excluded: no completion date found');
          }
        }
        count += mainCompleted;
        debugPrint('[Evaluator] Main goals completed: $mainCompleted');
      }

      debugPrint('[Evaluator] Total goals completed ($scope): $count');
      return count;
    } catch (e) {
      debugPrint('[Evaluator] Error counting goals: $e');
      return 0;
    }
  }

  Future<int> _countMiniCoursesCompleted(DateTime start, DateTime end) async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) return 0;

      // Query user_course_progress - use completed_at for accurate date filtering
      final response = await SupabaseService()
          .client
          .from('user_course_progress')
          .select('id, completed, score, completed_at')
          .eq('user_id', userId)
          .eq('completed', true);

      // Filter by completion date within window and score >= 70
      int count = 0;
      for (final item in (response as List)) {
        final completedAtStr = item['completed_at'] as String?;
        if (completedAtStr == null) continue;
        
        final completedAt = DateTime.tryParse(completedAtStr);
        if (completedAt == null) continue;
        
        // Check if within the window
        if (completedAt.isBefore(start) || completedAt.isAfter(end)) continue;
        
        final score = item['score'] as int?;
        if (score == null || score >= 70) {
          // No quiz required (null score) OR quiz passed with score >= 70
          count++;
        }
      }

      debugPrint(
          '[Evaluator] Mini-courses completed (with score >= 70 or no quiz): $count');
      return count;
    } catch (e) {
      debugPrint('[Evaluator] Error counting mini-courses: $e');
      return 0;
    }
  }
}
