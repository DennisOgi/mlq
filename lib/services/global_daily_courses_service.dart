import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_daily_course_service.dart';

class GlobalDailyCoursesService {
  GlobalDailyCoursesService();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch today's 3 global courses. Will attempt to trigger generation if missing.
  Future<List<MiniCourseModel>> getTodayCourses() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      Map<String, dynamic>? row = await _supabase
          .from('global_daily_courses')
          .select()
          .eq('date', today)
          .maybeSingle();

      if (row == null) {
        // Try to trigger generation once
        try {
          await _triggerGeneration();
        } catch (e) {
          if (kDebugMode) debugPrint('[GlobalCourses] trigger generation failed: $e');
        }
        await Future.delayed(const Duration(seconds: 3));
        row = await _supabase
            .from('global_daily_courses')
            .select()
            .eq('date', today)
            .maybeSingle();
        if (row == null) {
          throw Exception('Global daily courses not available for $today');
        }
      }

    final status = (row['status'] ?? 'ready').toString();
    if (status == 'generating') {
      await Future.delayed(const Duration(seconds: 2));
      return getTodayCourses();
    }
    if (status == 'failed') {
      throw Exception('Global course generation failed for $today');
    }

      final coursesJson = (row['courses'] as List?) ?? const [];
      final List<MiniCourseModel> list = [];
      for (int i = 0; i < coursesJson.length; i++) {
        final cj = Map<String, dynamic>.from(coursesJson[i] as Map);
        // Generate deterministic ID based on date and index (since server doesn't provide IDs)
        final today = DateTime.now().toIso8601String().split('T').first;
        cj['id'] = '${today}_course_$i';
        // Parse using existing serializer
        final model = SupabaseDailyCourseService.instance.courseFromJson(cj);
        list.add(model);
      }
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[GlobalCourses] ❌ Error in getTodayCourses: $e');
      rethrow; // Re-throw to let provider handle with specific error messages
    }
  }

  /// Fetch today's 3 global courses AND hydrate each course's quiz completion state
  /// from user_course_progress for the current authenticated user.
  ///
  /// This is critical because local caches are cleared on logout, and without hydration
  /// the UI may allow retakes after login even though the server already recorded completion.
  Future<List<MiniCourseModel>> getTodayCoursesForUser({
    required String userId,
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final courses = await getTodayCourses();
    try {
      final completion = await getCompletionMapForDate(
        userId: userId,
        courseDate: today,
      );

      if (completion.isEmpty) return courses;

      final List<MiniCourseModel> hydrated = [];
      for (int i = 0; i < courses.length; i++) {
        final c = courses[i];
        final row = completion[i];
        if (row == null) {
          hydrated.add(c);
          continue;
        }

        final completed = row['completed'] == true;
        final score = (row['score'] as num?)?.toInt();
        if (!completed) {
          hydrated.add(c);
          continue;
        }

        final updatedQuiz = c.quiz.copyWith(
          isCompleted: true,
          score: score,
        );
        hydrated.add(c.copyWith(
          quiz: updatedQuiz,
          status: MiniCourseStatus.completed,
          completedAt: DateTime.tryParse((row['completed_at'] ?? '').toString()),
        ));
      }

      return hydrated;
    } catch (e) {
      debugPrint('[GlobalCourses] ⚠️ Failed hydrating completion state: $e');
      return courses;
    }
  }

  /// Returns a map keyed by course_index -> { completed, score, completed_at } for a given date.
  Future<Map<int, Map<String, dynamic>>> getCompletionMapForDate({
    required String userId,
    required String courseDate,
  }) async {
    final out = <int, Map<String, dynamic>>{};
    try {
      final rows = await _supabase
          .from('user_course_progress')
          .select('course_index, completed, score, completed_at')
          .eq('user_id', userId)
          .eq('course_date', courseDate);

      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final idx = (m['course_index'] as num?)?.toInt();
        if (idx == null) continue;
        out[idx] = m;
      }
    } catch (e) {
      debugPrint('[GlobalCourses] getCompletionMapForDate error: $e');
    }
    return out;
  }

  /// Mark a specific course (by date + index) as completed for a user securely.
  /// Returns a map with reward info: { rewards_granted, coins_awarded, xp_awarded, new_coin_balance, new_xp }
  Future<Map<String, dynamic>> markCompletedSecure({
    required String userId,
    required String courseDate,
    required int courseIndex,
    required int score,
  }) async {
    try {
      debugPrint('[GlobalCourses] Secure quiz completion: userId=$userId, date=$courseDate, index=$courseIndex, score=$score');

      // Fast-path precheck to avoid calling the reward RPC when we already know it's completed.
      // The RPC should still be idempotent, but this reduces load and UX confusion.
      try {
        final already = await isCompleted(
          userId: userId,
          courseDate: courseDate,
          courseIndex: courseIndex,
        );
        if (already) {
          return {
            'rewards_granted': false,
            'already_completed': true,
            'coins_awarded': 0,
            'xp_awarded': 0,
          };
        }
      } catch (_) {}
      
      // Use secure RPC function that atomically checks and awards rewards
      final result = await _supabase.rpc('complete_quiz_secure', params: {
        'p_user_id': userId,
        'p_course_date': courseDate,
        'p_course_index': courseIndex,
        'p_score': score,
        'p_coin_reward': 5.0,
        'p_xp_reward': 20,
      });
      
      final resultMap = Map<String, dynamic>.from(result as Map);
      debugPrint('[GlobalCourses] ✅ Secure completion result: $resultMap');
      return resultMap;
    } catch (e) {
      debugPrint('[GlobalCourses] ❌ ERROR in secure quiz completion: $e');
      rethrow;
    }
  }

  /// Legacy method - kept for backwards compatibility but prefer markCompletedSecure
  @Deprecated('Use markCompletedSecure instead for proper reward handling')
  Future<void> markCompleted({
    required String userId,
    required String courseDate,
    required int courseIndex,
    required int score,
  }) async {
    // Delegate to secure version, ignore result
    await markCompletedSecure(
      userId: userId,
      courseDate: courseDate,
      courseIndex: courseIndex,
      score: score,
    );
  }

  /// Check completion quickly.
  Future<bool> isCompleted({
    required String userId,
    required String courseDate,
    required int courseIndex,
  }) async {
    final res = await _supabase
        .from('user_course_progress')
        .select('completed')
        .eq('user_id', userId)
        .eq('course_date', courseDate)
        .eq('course_index', courseIndex)
        .maybeSingle();
    return res?['completed'] == true;
    
  }

  Future<void> _triggerGeneration() async {
    try {
      await _supabase.functions.invoke('generate_global_daily_courses');
    } catch (e) {
      rethrow;
    }
  }
}
