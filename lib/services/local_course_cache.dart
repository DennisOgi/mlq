import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/mini_course_model.dart';
import 'supabase_daily_course_service.dart';

class LocalCourseCache {
  LocalCourseCache._();
  static final instance = LocalCourseCache._();

  String _courseKey(String userId, String dateKey) => 'mini_course:$userId:$dateKey';
  String _metaKey(String userId, String dateKey) => 'mini_course:meta:$userId:$dateKey';
  String _lastSuccessfulKey(String userId) => 'mini_course:last_successful:$userId';
  String _globalKey(String dateKey) => 'global_mini_courses:$dateKey';

  Future<void> saveCourse({
    required String userId,
    required String dateKey,
    required MiniCourseModel course,
    DailyGenerationStatus status = DailyGenerationStatus.ready,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final service = SupabaseDailyCourseService.instance;
    final jsonMap = service.courseToJson(course);
    await prefs.setString(_courseKey(userId, dateKey), json.encode(jsonMap));
    await prefs.setString(
      _metaKey(userId, dateKey),
      json.encode({
        'status': describeEnum(status),
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
    if (status == DailyGenerationStatus.ready) {
      await prefs.setString(_lastSuccessfulKey(userId), dateKey);
    }
  }

  Future<MiniCourseModel?> getCourse({
    required String userId,
    required String dateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_courseKey(userId, dateKey));
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return SupabaseDailyCourseService.instance.courseFromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getLastSuccessfulDateKey(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSuccessfulKey(userId));
  }

  /// Clear all cached courses for a user
  Future<void> clearUserCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final userKeys = keys.where((key) => 
      key.startsWith('mini_course:$userId:') || 
      key.startsWith('mini_course:meta:$userId:') ||
      key == 'mini_course:last_successful:$userId'
    );
    for (final key in userKeys) {
      await prefs.remove(key);
    }
    debugPrint('[LocalCache] Cleared all cached courses for user: $userId');
  }

  /// Clear a specific date's cache
  Future<void> clearDateCache(String userId, String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_courseKey(userId, dateKey));
    await prefs.remove(_metaKey(userId, dateKey));
    debugPrint('[LocalCache] Cleared cache for date: $dateKey');
  }

  // ===== Global daily courses (shared trio) =====
  Future<void> saveDailyCourses(String dateKey, List<MiniCourseModel> courses) async {
    final prefs = await SharedPreferences.getInstance();
    final service = SupabaseDailyCourseService.instance;
    final list = <Map<String, dynamic>>[];
    for (int i = 0; i < courses.length; i++) {
      final c = courses[i];
      final map = service.courseToJson(c);
      // Persist identity for deterministic progress mapping
      map['courseIndex'] = c.quiz.questions.isNotEmpty ? (c.quiz.questions.first.selectedOptionIndex ?? i) : i; // fallback to i
      map['courseIndex'] = i; // enforce index
      map['courseDate'] = dateKey;
      list.add(map);
    }
    await prefs.setString(_globalKey(dateKey), json.encode(list));
    debugPrint('[LocalCache] Saved global courses for $dateKey (count=${courses.length})');
  }

  Future<List<MiniCourseModel>?> getDailyCourses(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_globalKey(dateKey));
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as List;
      final service = SupabaseDailyCourseService.instance;
      final list = <MiniCourseModel>[];
      for (int i = 0; i < decoded.length; i++) {
        final m = Map<String, dynamic>.from(decoded[i] as Map);
        // Ensure identity fields are present
        m['courseIndex'] = m['courseIndex'] ?? i;
        m['courseDate'] = m['courseDate'] ?? dateKey;
        list.add(service.courseFromJson(m));
      }
      return list;
    } catch (e) {
      debugPrint('[LocalCache] Failed parsing global courses for $dateKey: $e');
      return null;
    }
  }

  Future<void> clearGlobalDateCache(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_globalKey(dateKey));
    debugPrint('[LocalCache] Cleared global courses cache for date: $dateKey');
  }
}
