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
        throw Exception(
          'MAINTENANCE: Today\'s mini-courses are temporarily unavailable while we fix an issue. Please check back later.',
        );
      }

      final coursesJson = (row['courses'] as List?) ?? const [];
      if (coursesJson.length < 3) {
        throw Exception(
          'MAINTENANCE: Today\'s mini-courses are still being prepared. Please try again in a few minutes.',
        );
      }

      final List<MiniCourseModel> list = [];
      for (int i = 0; i < coursesJson.length; i++) {
        final cj = Map<String, dynamic>.from(coursesJson[i] as Map);
        cj['id'] = '${today}_course_$i';
        final model = SupabaseDailyCourseService.instance.courseFromJson(cj);
        list.add(model);
      }
      return list;
    } catch (e) {
      if (kDebugMode) debugPrint('[GlobalCourses] ❌ Error in getTodayCourses: $e');
      rethrow;
    }
  }

  /// Courses from the previous [days] days, newest first, for read-only
  /// review. Quizzes are not offered for these because the quiz RPC would
  /// still grant rewards for past dates.
  Future<List<({String date, MiniCourseModel course})>> getRecentPastCourses({
    int days = 7,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final since = now
        .subtract(Duration(days: days))
        .toIso8601String()
        .split('T')
        .first;

    final rows = await _supabase
        .from('global_daily_courses')
        .select('date, status, courses')
        .lt('date', today)
        .gte('date', since)
        .order('date', ascending: false);

    final out = <({String date, MiniCourseModel course})>[];
    for (final r in (rows as List)) {
      final row = Map<String, dynamic>.from(r as Map);
      if ((row['status'] ?? 'ready').toString() != 'ready') continue;
      final date = row['date'].toString();
      final coursesJson = (row['courses'] as List?) ?? const [];
      for (int i = 0; i < coursesJson.length; i++) {
        try {
          final cj = Map<String, dynamic>.from(coursesJson[i] as Map);
          cj['id'] = '${date}_course_$i';
          out.add((
            date: date,
            course: SupabaseDailyCourseService.instance.courseFromJson(cj),
          ));
        } catch (e) {
          if (kDebugMode) debugPrint('[GlobalCourses] skip past course: $e');
        }
      }
    }
    return out;
  }

  /// Apply pass-only completion flags. Failed/empty attempts stay retryable.
  Future<List<MiniCourseModel>> hydrateCourseCompletion({
    required List<MiniCourseModel> courses,
    required String userId,
    String? courseDate,
  }) async {
    final date = courseDate ?? DateTime.now().toIso8601String().split('T').first;
    try {
      final completion = await getCompletionMapForDate(
        userId: userId,
        courseDate: date,
      );

      final List<MiniCourseModel> hydrated = [];
      for (int i = 0; i < courses.length; i++) {
        final c = courses[i];
        final row = completion[i];
        final completed = row?['completed'] == true;
        final score = (row?['score'] as num?)?.toInt();
        final passed = completed && (score ?? 0) >= 70;
        debugPrint(
          '[GlobalCourses] hydrate index=$i row=${row != null} '
          'completed=$completed score=$score passed=$passed',
        );
        hydrated.add(c.copyWith(
          quiz: c.quiz.copyWith(
            isCompleted: passed,
            score: passed ? score : null,
          ),
          status: passed
              ? MiniCourseStatus.completed
              : (c.status == MiniCourseStatus.completed
                  ? MiniCourseStatus.notStarted
                  : c.status),
          completedAt: passed
              ? DateTime.tryParse((row?['completed_at'] ?? '').toString())
              : null,
        ));
      }
      return hydrated;
    } catch (e) {
      debugPrint('[GlobalCourses] ⚠️ Failed hydrating completion state: $e');
      return courses;
    }
  }

  /// Fetch today's 3 global courses AND hydrate quiz completion from user_course_progress.
  Future<List<MiniCourseModel>> getTodayCoursesForUser({
    required String userId,
  }) async {
    final courses = await getTodayCourses();
    return hydrateCourseCompletion(courses: courses, userId: userId);
  }

  Future<Map<int, Map<String, dynamic>>> getCompletionMapForDate({
    required String userId,
    required String courseDate,
  }) async {
    final out = <int, Map<String, dynamic>>{};
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
    return out;
  }

  /// Submit a quiz. Only a pass (>=70) is stored; fails stay retryable.
  Future<Map<String, dynamic>> submitQuizSecure({
    required String userId,
    required String courseDate,
    required int courseIndex,
    required int score,
  }) async {
    try {
      debugPrint(
        '[GlobalCourses] Secure quiz submit: userId=$userId, date=$courseDate, index=$courseIndex, score=$score',
      );

      final result = await _supabase.rpc('complete_quiz_secure', params: {
        'p_user_id': userId,
        'p_course_date': courseDate,
        'p_course_index': courseIndex,
        'p_score': score,
        'p_coin_reward': 5.0,
      });

      final resultMap = Map<String, dynamic>.from(result as Map);
      debugPrint('[GlobalCourses] ✅ Secure quiz submit result: $resultMap');
      return resultMap;
    } catch (e) {
      debugPrint('[GlobalCourses] ❌ ERROR in secure quiz submit: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> markCompletedSecure({
    required String userId,
    required String courseDate,
    required int courseIndex,
    required int score,
  }) async {
    return submitQuizSecure(
      userId: userId,
      courseDate: courseDate,
      courseIndex: courseIndex,
      score: score,
    );
  }

  @Deprecated('Use markCompletedSecure instead for proper reward handling')
  Future<void> markCompleted({
    required String userId,
    required String courseDate,
    required int courseIndex,
    required int score,
  }) async {
    await markCompletedSecure(
      userId: userId,
      courseDate: courseDate,
      courseIndex: courseIndex,
      score: score,
    );
  }

  Future<bool> isCompleted({
    required String userId,
    required String courseDate,
    required int courseIndex,
  }) async {
    final res = await _supabase
        .from('user_course_progress')
        .select('completed, score')
        .eq('user_id', userId)
        .eq('course_date', courseDate)
        .eq('course_index', courseIndex)
        .maybeSingle();
    final completed = res?['completed'] == true;
    final score = (res?['score'] as num?)?.toInt() ?? 0;
    return completed && score >= 70;
  }

  /// True when this daily course was actually passed (not just opened/failed).
  Future<bool> hasAttempted({
    required String userId,
    required String courseDate,
    required int courseIndex,
  }) async {
    final res = await _supabase
        .from('user_course_progress')
        .select('id, completed, score')
        .eq('user_id', userId)
        .eq('course_date', courseDate)
        .eq('course_index', courseIndex)
        .maybeSingle();
    final completed = res?['completed'] == true;
    final score = (res?['score'] as num?)?.toInt() ?? 0;
    final passed = completed && score >= 70;
    debugPrint(
      '[GlobalCourses] hasAttempted user=$userId date=$courseDate index=$courseIndex '
      'row=${res != null} completed=$completed score=$score passed=$passed',
    );
    return passed;
  }

  Future<void> _triggerGeneration() async {
    await _supabase.functions.invoke('generate_global_daily_courses');
  }
}
