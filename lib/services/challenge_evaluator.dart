import 'dart:async';
import 'package:flutter/foundation.dart';

import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/gratitude_provider.dart';
import '../providers/mini_course_provider.dart';
import '../providers/challenge_provider.dart';
import '../services/supabase_service.dart';
import '../services/badge_service.dart';

/// UI-facing completion event payload
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

/// Triggers secure, server-side evaluation of the current user's basic
/// challenges.
///
/// IMPORTANT: all rule evaluation and completion happens on the server via the
/// `evaluate_challenges_for_user` RPC (SECURITY DEFINER). The client never
/// computes rewards or calls `complete_challenge` directly — that RPC is
/// locked to service_role to prevent coin-minting. This class is a thin
/// trigger + UI-notification layer:
///   * the various `evaluateX` methods simply ask the server to re-evaluate
///     (the 5-minute cron does the same thing on a schedule), and
///   * completed challenges returned by the RPC are surfaced to the UI via
///     [completionStream] for the celebration popup.
class ChallengeEvaluator {
  static final ChallengeEvaluator instance = ChallengeEvaluator._internal();
  ChallengeEvaluator._internal() {
    debugPrint('[Evaluator] ChallengeEvaluator instance created.');
  }

  final _completionCtrl =
      StreamController<ChallengeCompletionEvent>.broadcast();
  Stream<ChallengeCompletionEvent> get completionStream =>
      _completionCtrl.stream;

  UserProvider? _userProvider;

  bool _running = false;
  DateTime? _lastRun;
  // Coalesce bursts of trigger calls (e.g. several goals completed at once)
  // while still allowing an immediate run after an explicit user action.
  static const Duration _minInterval = Duration(milliseconds: 1200);

  /// Providers are accepted for backward compatibility with existing call
  /// sites. Only [userProvider] is retained (used to refresh the coin balance
  /// after a server-side completion); evaluation itself is fully server-side.
  void initialize({
    required UserProvider userProvider,
    required GoalProvider goalProvider,
    required ChallengeProvider challengeProvider,
    required MiniCourseProvider miniCourseProvider,
    GratitudeProvider? gratitudeProvider,
  }) {
    _userProvider = userProvider;
    debugPrint('[Evaluator] ChallengeEvaluator initialized.');
  }

  /// Called when the user joins a challenge so it can be evaluated immediately.
  Future<void> onJoinedChallenge(String challengeId) async {
    await _runServerEvaluation(force: true);
  }

  /// Evaluate all of the user's active basic challenges.
  Future<void> evaluateAll() => _runServerEvaluation();

  /// Kept as distinct entry points so call sites read naturally; all of them
  /// delegate to the same server-side evaluation (the server evaluates every
  /// active basic challenge regardless of which metric changed).
  Future<void> evaluateGratitudeChallenges() => _runServerEvaluation();
  Future<void> evaluateGoalChallenges() => _runServerEvaluation();
  Future<void> evaluateMiniCourseChallenges() => _runServerEvaluation();

  Future<void> _runServerEvaluation({bool force = false}) async {
    if (!SupabaseService.instance.isReady) {
      debugPrint('[Evaluator] Skipping evaluation: Supabase not ready.');
      return;
    }

    final userId = SupabaseService().currentUser?.id;
    if (userId == null) {
      debugPrint('[Evaluator] Skipping evaluation: no authenticated user.');
      return;
    }

    if (_running) {
      debugPrint('[Evaluator] Evaluation already in progress; skipping.');
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastRun != null &&
        now.difference(_lastRun!) < _minInterval) {
      debugPrint('[Evaluator] Throttled: evaluated very recently.');
      return;
    }

    _running = true;
    _lastRun = now;
    try {
      final result = await SupabaseService().client.rpc(
        'evaluate_challenges_for_user',
        params: {'p_user_id': userId},
      );

      final completed = <ChallengeCompletionEvent>[];
      if (result is List) {
        for (final item in result) {
          if (item is Map && item['completed'] == true) {
            completed.add(ChallengeCompletionEvent(
              challengeId: (item['challenge_id'] ?? '').toString(),
              title: (item['title'] ?? 'Challenge').toString(),
              coinReward: (item['coins_awarded'] as num?)?.toInt() ?? 0,
              completedAt: DateTime.now(),
            ));
          }
        }
      }

      if (completed.isEmpty) {
        debugPrint('[Evaluator] Server evaluation: no new completions.');
        return;
      }

      debugPrint(
          '[Evaluator] Server evaluation completed ${completed.length} challenge(s).');

      // Refresh coin balance once for the whole batch.
      try {
        await _userProvider?.reinitializeUser();
      } catch (e) {
        debugPrint('[Evaluator] Failed to refresh user after completion: $e');
      }

      // Process any badges queued by the completions (best effort).
      unawaited(_processBadgeQueue(userId).catchError((e) {
        debugPrint('[Evaluator] Badge queue processing failed: $e');
      }));

      // Notify UI for celebration popups.
      for (final event in completed) {
        try {
          _completionCtrl.add(event);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[Evaluator] Server evaluation error: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _processBadgeQueue(String userId) async {
    try {
      debugPrint('🏆 Processing badge queue for user $userId...');
      // Server-only awards (client INSERT on user_badges is revoked).
      final result = await SupabaseService().client.rpc('run_my_badge_checks');
      debugPrint('🏆 Badge checks result: $result');
      // Refresh local badge list for UI popups / counts.
      try {
        await BadgeService().checkForAchievements();
      } catch (e) {
        debugPrint('Badge UI refresh skipped: $e');
      }
    } catch (e) {
      debugPrint('❌ Badge queue processing error: $e');
    }
  }
}
