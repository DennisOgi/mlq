import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/mini_course_model.dart';
import 'supabase_service.dart';

/// Status values returned by the backend for a user's daily course
enum DailyGenerationStatus { pending, generating, ready, failed }

/// Lightweight representation of the daily-course DB row
class DailyRow {
  final String userId;
  final String dateKey; // yyyy-MM-dd in the user's timezone
  final DailyGenerationStatus status;
  final Map<String, dynamic>? courseJson; // The serialized MiniCourseModel
  final String? requestId;
  final DateTime? updatedAt;
  final String? error;

  const DailyRow({
    required this.userId,
    required this.dateKey,
    required this.status,
    this.courseJson,
    this.requestId,
    this.updatedAt,
    this.error,
  });

  DailyRow copyWith({
    DailyGenerationStatus? status,
    Map<String, dynamic>? courseJson,
    String? requestId,
    DateTime? updatedAt,
    String? error,
  }) {
    return DailyRow(
      userId: userId,
      dateKey: dateKey,
      status: status ?? this.status,
      courseJson: courseJson ?? this.courseJson,
      requestId: requestId ?? this.requestId,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error ?? this.error,
    );
  }
}

/// RPC client wrapper for daily mini-courses using Supabase.
/// NOTE: This is a scaffold. Wire actual Supabase client calls in the TODOs.
class SupabaseDailyCourseService {
  SupabaseDailyCourseService._();
  static final instance = SupabaseDailyCourseService._();

  Future<DailyRow> getOrCreate({
    required String userId,
    required String dateKey,
  }) async {
    debugPrint('[SupabaseDailyCourse] getOrCreate userId=$userId dateKey=$dateKey');
    try {
      final client = SupabaseService().client;
      // Try existing row
      final existing = await client
          .from('daily_courses')
          .select()
          .eq('user_id', userId)
          .eq('date_key', dateKey)
          .maybeSingle();

      if (existing != null) {
        final map = Map<String, dynamic>.from(existing);
        return _rowFromMap(map);
      }

      // Insert new pending row
      final inserted = await client
          .from('daily_courses')
          .insert({
            'user_id': userId,
            'date_key': dateKey,
            'status': 'pending',
          })
          .select()
          .single();

      final map = Map<String, dynamic>.from(inserted);
      return _rowFromMap(map);
    } catch (e) {
      debugPrint('[SupabaseDailyCourse] getOrCreate error: $e');
      rethrow;
    }
  }

  Future<DailyRow> beginGenerate({
    required String userId,
    required String dateKey,
    required String idempotencyKey,
    required String requestId,
  }) async {
    debugPrint('[SupabaseDailyCourse] beginGenerate userId=$userId dateKey=$dateKey');
    try {
      final client = SupabaseService().client;
      // Ensure row exists, then mark generating
      await getOrCreate(userId: userId, dateKey: dateKey);
      final updated = await client
          .from('daily_courses')
          .update({
            'status': 'generating',
            'idempotency_key': idempotencyKey,
            'request_id': requestId,
          })
          .eq('user_id', userId)
          .eq('date_key', dateKey)
          .select()
          .single();
      final map = Map<String, dynamic>.from(updated);
      return _rowFromMap(map);
    } catch (e) {
      debugPrint('[SupabaseDailyCourse] beginGenerate error: $e');
      rethrow;
    }
  }

  Future<DailyRow> finishGenerate({
    required String userId,
    required String dateKey,
    required Map<String, dynamic> courseJson,
    required String requestId,
    required DailyGenerationStatus status,
    Map<String, dynamic>? tokenUsage,
  }) async {
    debugPrint('[SupabaseDailyCourse] finishGenerate userId=$userId dateKey=$dateKey status=$status');
    try {
      final client = SupabaseService().client;
      final updated = await client
          .from('daily_courses')
          .update({
            'status': _statusToDb(status),
            'course_json': courseJson,
            'request_id': requestId,
          })
          .eq('user_id', userId)
          .eq('date_key', dateKey)
          .select()
          .single();
      final map = Map<String, dynamic>.from(updated);
      return _rowFromMap(map);
    } catch (e) {
      debugPrint('[SupabaseDailyCourse] finishGenerate error: $e');
      rethrow;
    }
  }

  Future<DailyRow> getStatus({
    required String userId,
    required String dateKey,
  }) async {
    debugPrint('[SupabaseDailyCourse] getStatus userId=$userId dateKey=$dateKey');
    try {
      final client = SupabaseService().client;
      final row = await client
          .from('daily_courses')
          .select()
          .eq('user_id', userId)
          .eq('date_key', dateKey)
          .single();
      final map = Map<String, dynamic>.from(row);
      return _rowFromMap(map);
    } catch (e) {
      debugPrint('[SupabaseDailyCourse] getStatus error: $e');
      rethrow;
    }
  }

  // Helpers for converting MiniCourseModel to/from JSON maps that the DB stores
  Map<String, dynamic> courseToJson(MiniCourseModel model) {
    // Minimal serializer; rely on model fields available
    return <String, dynamic>{
      'id': model.id,
      'title': model.title,
      'description': model.description,
      'topic': model.topic, // Include topic field
      'status': describeEnum(model.status),
      'currentLessonIndex': model.currentLessonIndex,
      'lessons': model.lessons
          .map((l) => {
                'id': l.id,
                'title': l.title,
                'content': l.content,
                'keyTakeaways': l.keyTakeaways,
                'isCompleted': l.isCompleted,
              })
          .toList(),
      'quiz': {
        'id': model.quiz.id,
        'title': model.quiz.title,
        'description': model.quiz.description,
        'isCompleted': model.quiz.isCompleted,
        'score': model.quiz.score,
        'questions': model.quiz.questions
            .map((q) => {
                  'id': q.id,
                  'text': q.text,
                  'options': q.options,
                  'correctAnswerIndex': q.correctAnswerIndex,
                  'selectedOptionIndex': q.selectedOptionIndex,
                })
            .toList(),
      },
    };
  }

  MiniCourseModel courseFromJson(Map<String, dynamic> jsonMap) {
    try {
      // Generate deterministic IDs if not provided by server
      final courseId = jsonMap['id'] as String? ?? 'course_${DateTime.now().millisecondsSinceEpoch}';
      
      final lessons = (jsonMap['lessons'] as List<dynamic>? ?? [])
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final l = entry.value;
            return MiniCourseLessonModel(
              id: l['id'] as String? ?? '${courseId}_lesson_$index',
              title: l['title'] as String? ?? 'Lesson',
              content: l['content'] as String? ?? '',
              keyTakeaways: (l['keyTakeaways'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList(),
              isCompleted: l['isCompleted'] as bool? ?? false,
            );
          })
          .toList();

      final questions = (jsonMap['quiz']?['questions'] as List<dynamic>? ?? [])
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final q = entry.value;
            return MiniCourseQuizQuestionModel(
              id: q['id'] as String? ?? '${courseId}_quiz_q$index',
              text: q['question'] as String? ?? q['text'] as String? ?? '',
              options: (q['options'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList(),
              correctAnswerIndex: q['correctAnswerIndex'] as int? ?? 0,
              selectedOptionIndex: q['selectedOptionIndex'] as int?,
            );
          })
          .toList();

      final quiz = MiniCourseQuizModel(
        id: jsonMap['quiz']?['id'] as String? ?? '${courseId}_quiz',
        title: jsonMap['quiz']?['title'] as String? ?? 'Quiz',
        description: jsonMap['quiz']?['description'] as String? ?? 'Test your knowledge!',
        isCompleted: jsonMap['quiz']?['isCompleted'] as bool? ?? false,
        score: jsonMap['quiz']?['score'] as int?,
        questions: questions,
      );

      return MiniCourseModel(
        id: courseId,
        title: jsonMap['title'] as String? ?? 'Daily Course',
        description: jsonMap['description'] as String? ?? '',
        topic: jsonMap['topic'] as String?, // Parse topic from server
        lessons: lessons,
        quiz: quiz,
        status: _statusFromString(jsonMap['status'] as String? ?? 'notStarted'),
        currentLessonIndex: jsonMap['currentLessonIndex'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('SupabaseDailyCourseService.courseFromJson error: $e');
      // Fallback minimal course to avoid crashes
      return MiniCourseModel(
        id: UniqueKey().toString(),
        title: 'Daily Course',
        description: '',
        topic: null, // Will default to title
        lessons: const [],
        quiz: MiniCourseQuizModel(
          id: UniqueKey().toString(),
          title: 'Quiz',
          description: '',
          questions: const [],
          isCompleted: false,
          score: null,
        ),
        status: MiniCourseStatus.notStarted,
        currentLessonIndex: 0,
      );
    }
  }

  MiniCourseStatus _statusFromString(String value) {
    switch (value) {
      case 'inProgress':
        return MiniCourseStatus.inProgress;
      case 'completed':
        return MiniCourseStatus.completed;
      case 'notStarted':
      default:
        return MiniCourseStatus.notStarted;
    }
  }

  // ====== Internal mapping helpers ======
  DailyRow _rowFromMap(Map<String, dynamic> m) {
    final rawCourse = m['course_json'];
    Map<String, dynamic>? courseJson;
    if (rawCourse is String) {
      try {
        courseJson = json.decode(rawCourse) as Map<String, dynamic>;
      } catch (_) {
        courseJson = null;
      }
    } else if (rawCourse is Map<String, dynamic>) {
      courseJson = rawCourse;
    }

    return DailyRow(
      userId: (m['user_id'] ?? m['userId']) as String,
      dateKey: (m['date_key'] ?? m['dateKey']) as String,
      status: _statusFromDb(m['status'] as String?),
      courseJson: courseJson,
      requestId: m['request_id'] as String?,
      updatedAt: _parseDateTime(m['updated_at']),
      error: m['error'] as String?,
    );
  }

  DailyGenerationStatus _statusFromDb(String? s) {
    switch (s) {
      case 'generating':
        return DailyGenerationStatus.generating;
      case 'ready':
        return DailyGenerationStatus.ready;
      case 'failed':
        return DailyGenerationStatus.failed;
      case 'pending':
      default:
        return DailyGenerationStatus.pending;
    }
  }

  String _statusToDb(DailyGenerationStatus s) {
    switch (s) {
      case DailyGenerationStatus.generating:
        return 'generating';
      case DailyGenerationStatus.ready:
        return 'ready';
      case DailyGenerationStatus.failed:
        return 'failed';
      case DailyGenerationStatus.pending:
        return 'pending';
    }
  }

  DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}
