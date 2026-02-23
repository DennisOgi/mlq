import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for a community mini course
class CommunityMiniCourse {
  final String id;
  final String communityId;
  final String communityName;
  final DateTime date;
  final String title;
  final String topic;
  final String? summary;
  final List<Map<String, dynamic>> content;
  final List<Map<String, dynamic>> quizQuestions;
  final int xpReward;
  final double coinReward;
  final String createdBy;
  final bool isCompleted;
  final int? score;

  CommunityMiniCourse({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.date,
    required this.title,
    required this.topic,
    this.summary,
    required this.content,
    required this.quizQuestions,
    required this.xpReward,
    required this.coinReward,
    required this.createdBy,
    this.isCompleted = false,
    this.score,
  });

  factory CommunityMiniCourse.fromJson(Map<String, dynamic> json, {
    String? communityName,
    bool isCompleted = false,
    int? score,
  }) {
    return CommunityMiniCourse(
      id: json['id'] as String,
      communityId: json['community_id'] as String,
      communityName: communityName ?? json['communities']?['name'] as String? ?? 'Community',
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      topic: json['topic'] as String? ?? 'Community Lesson',
      summary: json['summary'] as String?,
      content: List<Map<String, dynamic>>.from(
        (json['content'] as List?) ?? [],
      ),
      quizQuestions: List<Map<String, dynamic>>.from(
        (json['quiz_questions'] as List?) ?? [],
      ),
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 15,
      coinReward: (json['coin_reward'] as num?)?.toDouble() ?? 3.0,
      createdBy: json['created_by'] as String,
      isCompleted: isCompleted,
      score: score,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'community_id': communityId,
    'date': date.toIso8601String().split('T').first,
    'title': title,
    'topic': topic,
    'summary': summary,
    'content': content,
    'quiz_questions': quizQuestions,
    'xp_reward': xpReward,
    'coin_reward': coinReward,
    'created_by': createdBy,
  };

  bool get hasQuiz => quizQuestions.isNotEmpty;

  CommunityMiniCourse copyWith({
    bool? isCompleted,
    int? score,
  }) {
    return CommunityMiniCourse(
      id: id,
      communityId: communityId,
      communityName: communityName,
      date: date,
      title: title,
      topic: topic,
      summary: summary,
      content: content,
      quizQuestions: quizQuestions,
      xpReward: xpReward,
      coinReward: coinReward,
      createdBy: createdBy,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
    );
  }
}

/// Service for managing community mini courses
class CommunityCourseService {
  CommunityCourseService._();
  static final CommunityCourseService instance = CommunityCourseService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch today's community courses ONLY for communities the user is a member of
  Future<List<CommunityMiniCourse>> getTodayCommunityCourses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final today = DateTime.now().toIso8601String().split('T').first;

      // Step 1: Get all community IDs where the user is an active member
      final membershipResponse = await _supabase
          .from('community_members')
          .select('community_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      if ((membershipResponse as List).isEmpty) {
        debugPrint('[CommunityCourse] User is not a member of any community');
        return [];
      }

      final memberCommunityIds = (membershipResponse as List)
          .map((m) => m['community_id'] as String)
          .toList();

      debugPrint('[CommunityCourse] User is member of ${memberCommunityIds.length} communities');

      // Step 2: Get today's courses ONLY for those communities
      final response = await _supabase
          .from('community_daily_courses')
          .select('*, communities!inner(id, name)')
          .eq('date', today)
          .inFilter('community_id', memberCommunityIds);

      if ((response as List).isEmpty) {
        debugPrint('[CommunityCourse] No courses found for today in user\'s communities');
        return [];
      }

      // Step 3: Get user's progress for these courses
      final courseIds = (response as List).map((c) => c['id'] as String).toList();
      final progressResponse = await _supabase
          .from('user_community_course_progress')
          .select('community_course_id, completed, score')
          .eq('user_id', userId)
          .inFilter('community_course_id', courseIds);

      final progressMap = <String, Map<String, dynamic>>{};
      for (final p in (progressResponse as List)) {
        progressMap[p['community_course_id'] as String] = p;
      }

      return (response as List).map((json) {
        final courseId = json['id'] as String;
        final progress = progressMap[courseId];
        final communityData = json['communities'] as Map<String, dynamic>?;
        
        return CommunityMiniCourse.fromJson(
          json,
          communityName: communityData?['name'] as String?,
          isCompleted: progress?['completed'] == true,
          score: (progress?['score'] as num?)?.toInt(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[CommunityCourse] Error fetching today\'s courses: $e');
      return [];
    }
  }

  /// Fetch today's course for a specific community
  Future<CommunityMiniCourse?> getTodayCourseForCommunity(String communityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final today = DateTime.now().toIso8601String().split('T').first;

      final response = await _supabase
          .from('community_daily_courses')
          .select('*, communities!inner(id, name)')
          .eq('community_id', communityId)
          .eq('date', today)
          .maybeSingle();

      if (response == null) return null;

      // Get user's progress
      bool isCompleted = false;
      int? score;
      if (userId != null) {
        final progress = await _supabase
            .from('user_community_course_progress')
            .select('completed, score')
            .eq('user_id', userId)
            .eq('community_course_id', response['id'])
            .maybeSingle();
        
        isCompleted = progress?['completed'] == true;
        score = (progress?['score'] as num?)?.toInt();
      }

      final communityData = response['communities'] as Map<String, dynamic>?;
      return CommunityMiniCourse.fromJson(
        response,
        communityName: communityData?['name'] as String?,
        isCompleted: isCompleted,
        score: score,
      );
    } catch (e) {
      debugPrint('[CommunityCourse] Error fetching course for community: $e');
      return null;
    }
  }

  /// Create or update today's course for a community (owner only)
  Future<CommunityMiniCourse?> upsertTodayCourse({
    required String communityId,
    required String title,
    String? topic,
    String? summary,
    required List<Map<String, dynamic>> content,
    List<Map<String, dynamic>>? quizQuestions,
    int xpReward = 15,
    double coinReward = 3.0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final today = DateTime.now().toIso8601String().split('T').first;

      final data = {
        'community_id': communityId,
        'date': today,
        'title': title,
        'topic': topic ?? 'Community Lesson',
        'summary': summary,
        'content': content,
        'quiz_questions': quizQuestions ?? [],
        'xp_reward': xpReward,
        'coin_reward': coinReward,
        'created_by': userId,
      };

      // Upsert based on community_id + date unique constraint
      final response = await _supabase
          .from('community_daily_courses')
          .upsert(data, onConflict: 'community_id,date')
          .select('*, communities!inner(id, name)')
          .single();

      final communityData = response['communities'] as Map<String, dynamic>?;
      return CommunityMiniCourse.fromJson(
        response,
        communityName: communityData?['name'] as String?,
      );
    } catch (e) {
      debugPrint('[CommunityCourse] Error upserting course: $e');
      rethrow;
    }
  }

  /// Mark a community course as completed
  /// Note: Community courses do NOT award XP or coins - they are for learning only
  Future<Map<String, dynamic>> markCompleted({
    required String courseId,
    required int score,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Check if already completed
      final existing = await _supabase
          .from('user_community_course_progress')
          .select('completed')
          .eq('user_id', userId)
          .eq('community_course_id', courseId)
          .maybeSingle();

      if (existing?['completed'] == true) {
        return {
          'rewards_granted': false,
          'already_completed': true,
          'xp_awarded': 0,
          'coins_awarded': 0,
        };
      }

      // Record completion (no XP/coins for community courses)
      await _supabase.from('user_community_course_progress').upsert({
        'user_id': userId,
        'community_course_id': courseId,
        'completed': true,
        'score': score,
        'completed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,community_course_id');

      // Community courses don't give XP or coins
      return {
        'rewards_granted': false,
        'already_completed': false,
        'xp_awarded': 0,
        'coins_awarded': 0,
      };
    } catch (e) {
      debugPrint('[CommunityCourse] Error marking completed: $e');
      rethrow;
    }
  }

  /// Check if user has completed a specific course
  Future<bool> isCompleted(String courseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('user_community_course_progress')
          .select('completed')
          .eq('user_id', userId)
          .eq('community_course_id', courseId)
          .maybeSingle();

      return response?['completed'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a community course (owner only)
  Future<void> deleteCourse(String courseId) async {
    try {
      await _supabase
          .from('community_daily_courses')
          .delete()
          .eq('id', courseId);
    } catch (e) {
      debugPrint('[CommunityCourse] Error deleting course: $e');
      rethrow;
    }
  }
}
