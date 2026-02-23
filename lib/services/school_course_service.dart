import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'supabase_service.dart';

// ignore_for_file: deprecated_member_use

/// Service for managing school-specific mini courses
/// This is a PREMIUM feature for schools with premium/enterprise subscriptions
class SchoolCourseService {
  static final SchoolCourseService _instance = SchoolCourseService._internal();
  static SchoolCourseService get instance => _instance;
  factory SchoolCourseService() => _instance;
  SchoolCourseService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // =====================================================
  // SCHOOL & USER ROLE METHODS
  // =====================================================

  /// Get current user's school info
  Future<Map<String, dynamic>?> getCurrentUserSchool() async {
    try {
      if (_userId == null) return null;

      final response = await _client
          .from('profiles')
          .select('school_id, school_name, role')
          .eq('id', _userId!)
          .maybeSingle();

      if (response == null || response['school_id'] == null) return null;

      // Get full school details
      final school = await _client
          .from('schools')
          .select('*')
          .eq('id', response['school_id'])
          .maybeSingle();

      if (school != null) {
        school['user_role'] = response['role'];
      }

      return school;
    } catch (e) {
      debugPrint('Error getting user school: $e');
      return null;
    }
  }

  /// Check if current user is a school admin
  Future<bool> isSchoolAdmin() async {
    try {
      if (_userId == null) return false;

      final response = await _client
          .from('profiles')
          .select('role, school_id')
          .eq('id', _userId!)
          .maybeSingle();

      return response != null &&
          response['role'] == 'school_admin' &&
          response['school_id'] != null;
    } catch (e) {
      debugPrint('Error checking school admin status: $e');
      return false;
    }
  }

  /// Check if current user is a teacher (or school admin)
  Future<bool> isSchoolTeacher() async {
    try {
      if (_userId == null) return false;

      final response = await _client
          .from('profiles')
          .select('role, school_id')
          .eq('id', _userId!)
          .maybeSingle();

      return response != null &&
          (response['role'] == 'teacher' || response['role'] == 'school_admin') &&
          response['school_id'] != null;
    } catch (e) {
      debugPrint('Error checking teacher status: $e');
      return false;
    }
  }

  /// Check if school has premium features enabled
  Future<bool> schoolHasPremium(String schoolId) async {
    try {
      final response = await _client
          .from('schools')
          .select('subscription_tier, subscription_expires_at')
          .eq('id', schoolId)
          .maybeSingle();

      if (response == null) return false;

      final tier = response['subscription_tier'] as String?;
      final expiresAt = response['subscription_expires_at'] as String?;

      if (tier != 'premium' && tier != 'enterprise') return false;

      if (expiresAt != null) {
        final expiry = DateTime.parse(expiresAt);
        if (expiry.isBefore(DateTime.now())) return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking school premium status: $e');
      return false;
    }
  }

  // =====================================================
  // SCHOOL BRANDING METHODS
  // =====================================================

  /// Upload school logo
  Future<String?> uploadSchoolLogo(String schoolId, Uint8List imageBytes, String fileName) async {
    try {
      // Optimize image
      final optimizedBytes = await _optimizeImage(imageBytes);

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName).toLowerCase();
      final uniqueFileName = 'school_${schoolId}_logo_$timestamp$extension';

      // Upload to Supabase Storage
      final uploadPath = 'school-logos/$uniqueFileName';
      await _client.storage
          .from('organization-assets')
          .uploadBinary(uploadPath, optimizedBytes);

      // Get public URL
      final publicUrl = _client.storage
          .from('organization-assets')
          .getPublicUrl(uploadPath);

      // Update school record
      await _client
          .from('schools')
          .update({
            'logo_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', schoolId);

      debugPrint('School logo uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading school logo: $e');
      return null;
    }
  }

  /// Update school branding settings
  Future<bool> updateSchoolBranding({
    required String schoolId,
    String? primaryColor,
    String? secondaryColor,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (primaryColor != null) updates['primary_color'] = primaryColor;
      if (secondaryColor != null) updates['secondary_color'] = secondaryColor;

      await _client.from('schools').update(updates).eq('id', schoolId);

      debugPrint('School branding updated');
      return true;
    } catch (e) {
      debugPrint('Error updating school branding: $e');
      return false;
    }
  }

  // =====================================================
  // COURSE CATEGORY METHODS
  // =====================================================

  /// Get all categories for a school
  Future<List<Map<String, dynamic>>> getSchoolCategories(String schoolId) async {
    try {
      final response = await _client
          .from('school_course_categories')
          .select('*')
          .eq('school_id', schoolId)
          .eq('is_active', true)
          .order('sort_order');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting school categories: $e');
      return [];
    }
  }

  /// Create a new category
  Future<Map<String, dynamic>?> createCategory({
    required String schoolId,
    required String name,
    String? description,
    String icon = 'book',
    String color = '#00C4FF',
  }) async {
    try {
      final response = await _client
          .from('school_course_categories')
          .insert({
            'school_id': schoolId,
            'name': name,
            'description': description,
            'icon': icon,
            'color': color,
          })
          .select()
          .single();

      debugPrint('Category created: $name');
      return response;
    } catch (e) {
      debugPrint('Error creating category: $e');
      return null;
    }
  }

  /// Update a category
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? icon,
    String? color,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (icon != null) updates['icon'] = icon;
      if (color != null) updates['color'] = color;
      if (sortOrder != null) updates['sort_order'] = sortOrder;
      if (isActive != null) updates['is_active'] = isActive;

      await _client
          .from('school_course_categories')
          .update(updates)
          .eq('id', categoryId);

      return true;
    } catch (e) {
      debugPrint('Error updating category: $e');
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _client
          .from('school_course_categories')
          .delete()
          .eq('id', categoryId);

      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
  }

  // =====================================================
  // COURSE CRUD METHODS
  // =====================================================

  /// Get all courses for a school (admin/teacher view)
  Future<List<Map<String, dynamic>>> getSchoolCoursesForAdmin(String schoolId) async {
    try {
      final response = await _client
          .from('school_mini_courses')
          .select('''
            *,
            category:school_course_categories(id, name, icon, color),
            creator:profiles!school_mini_courses_created_by_fkey(id, name, avatar_url),
            approver:profiles!school_mini_courses_approved_by_fkey(id, name)
          ''')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting school courses for admin: $e');
      return [];
    }
  }

  /// Get published courses for students
  Future<List<Map<String, dynamic>>> getPublishedCourses(String schoolId, {String? gradeLevel}) async {
    try {
      var query = _client
          .from('school_mini_courses')
          .select('''
            *,
            category:school_course_categories(id, name, icon, color),
            creator:profiles!school_mini_courses_created_by_fkey(id, name, avatar_url)
          ''')
          .eq('school_id', schoolId)
          .eq('status', 'published')
          .or('publish_date.is.null,publish_date.lte.${DateTime.now().toIso8601String()}')
          .or('expiry_date.is.null,expiry_date.gt.${DateTime.now().toIso8601String()}');

      final response = await query.order('is_featured', ascending: false).order('created_at', ascending: false);

      var courses = List<Map<String, dynamic>>.from(response);

      // Filter by grade level if specified
      if (gradeLevel != null && gradeLevel.isNotEmpty) {
        courses = courses.where((course) {
          final gradeLevels = List<String>.from(course['grade_levels'] ?? []);
          return gradeLevels.isEmpty || gradeLevels.contains(gradeLevel);
        }).toList();
      }

      return courses;
    } catch (e) {
      debugPrint('Error getting published courses: $e');
      return [];
    }
  }

  /// Get courses pending approval (for school admins)
  Future<List<Map<String, dynamic>>> getPendingApprovalCourses(String schoolId) async {
    try {
      final response = await _client
          .from('school_mini_courses')
          .select('''
            *,
            category:school_course_categories(id, name, icon, color),
            creator:profiles!school_mini_courses_created_by_fkey(id, name, avatar_url)
          ''')
          .eq('school_id', schoolId)
          .eq('status', 'pending_approval')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting pending courses: $e');
      return [];
    }
  }

  /// Get courses created by current user (for teachers)
  Future<List<Map<String, dynamic>>> getMyCourses() async {
    try {
      if (_userId == null) return [];

      final response = await _client
          .from('school_mini_courses')
          .select('''
            *,
            category:school_course_categories(id, name, icon, color)
          ''')
          .eq('created_by', _userId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting my courses: $e');
      return [];
    }
  }

  /// Get a single course by ID
  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      final response = await _client
          .from('school_mini_courses')
          .select('''
            *,
            category:school_course_categories(id, name, icon, color),
            creator:profiles!school_mini_courses_created_by_fkey(id, name, avatar_url),
            school:schools(id, name, logo_url, primary_color)
          ''')
          .eq('id', courseId)
          .maybeSingle();

      // Increment view count
      if (response != null) {
        await _client
            .from('school_mini_courses')
            .update({'view_count': (response['view_count'] ?? 0) + 1})
            .eq('id', courseId);
      }

      return response;
    } catch (e) {
      debugPrint('Error getting course: $e');
      return null;
    }
  }

  /// Create a new course
  Future<Map<String, dynamic>?> createCourse({
    required String schoolId,
    required String title,
    required String description,
    required String topic,
    String? summary,
    required List<Map<String, dynamic>> content,
    List<Map<String, dynamic>>? quizQuestions,
    List<String>? gradeLevels,
    String? subject,
    String? categoryId,
    int xpReward = 20,
    double coinReward = 5.0,
    String difficulty = 'beginner',
    int estimatedDuration = 10,
    String? thumbnailUrl,
    bool submitForApproval = false,
  }) async {
    try {
      if (_userId == null) return null;

      // Determine initial status
      final isAdmin = await isSchoolAdmin();
      String status = 'draft';
      if (submitForApproval && !isAdmin) {
        status = 'pending_approval';
      }

      final response = await _client
          .from('school_mini_courses')
          .insert({
            'school_id': schoolId,
            'category_id': categoryId,
            'title': title,
            'description': description,
            'topic': topic,
            'summary': summary,
            'content': content,
            'quiz_questions': quizQuestions ?? [],
            'grade_levels': gradeLevels ?? [],
            'subject': subject,
            'xp_reward': xpReward,
            'coin_reward': coinReward,
            'difficulty': difficulty,
            'estimated_duration': estimatedDuration,
            'thumbnail_url': thumbnailUrl,
            'status': status,
            'created_by': _userId,
          })
          .select()
          .single();

      debugPrint('Course created: $title');
      return response;
    } catch (e) {
      debugPrint('Error creating course: $e');
      return null;
    }
  }

  /// Update an existing course
  Future<bool> updateCourse({
    required String courseId,
    String? title,
    String? description,
    String? topic,
    String? summary,
    List<Map<String, dynamic>>? content,
    List<Map<String, dynamic>>? quizQuestions,
    List<String>? gradeLevels,
    String? subject,
    String? categoryId,
    int? xpReward,
    double? coinReward,
    String? difficulty,
    int? estimatedDuration,
    String? thumbnailUrl,
    bool? isFeatured,
    DateTime? publishDate,
    DateTime? expiryDate,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (topic != null) updates['topic'] = topic;
      if (summary != null) updates['summary'] = summary;
      if (content != null) updates['content'] = content;
      if (quizQuestions != null) updates['quiz_questions'] = quizQuestions;
      if (gradeLevels != null) updates['grade_levels'] = gradeLevels;
      if (subject != null) updates['subject'] = subject;
      if (categoryId != null) updates['category_id'] = categoryId;
      if (xpReward != null) updates['xp_reward'] = xpReward;
      if (coinReward != null) updates['coin_reward'] = coinReward;
      if (difficulty != null) updates['difficulty'] = difficulty;
      if (estimatedDuration != null) updates['estimated_duration'] = estimatedDuration;
      if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
      if (isFeatured != null) updates['is_featured'] = isFeatured;
      if (publishDate != null) updates['publish_date'] = publishDate.toIso8601String();
      if (expiryDate != null) updates['expiry_date'] = expiryDate.toIso8601String();

      await _client
          .from('school_mini_courses')
          .update(updates)
          .eq('id', courseId);

      debugPrint('Course updated: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error updating course: $e');
      return false;
    }
  }

  /// Submit course for approval (teachers)
  Future<bool> submitForApproval(String courseId) async {
    try {
      await _client
          .from('school_mini_courses')
          .update({
            'status': 'pending_approval',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courseId);

      debugPrint('Course submitted for approval: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error submitting course for approval: $e');
      return false;
    }
  }

  /// Approve a course (school admins only)
  Future<bool> approveCourse(String courseId) async {
    try {
      if (_userId == null) return false;

      await _client
          .from('school_mini_courses')
          .update({
            'status': 'published',
            'approved_by': _userId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courseId);

      debugPrint('Course approved: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error approving course: $e');
      return false;
    }
  }

  /// Reject a course (school admins only)
  Future<bool> rejectCourse(String courseId, String reason) async {
    try {
      await _client
          .from('school_mini_courses')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courseId);

      debugPrint('Course rejected: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error rejecting course: $e');
      return false;
    }
  }

  /// Publish a course directly (school admins only)
  Future<bool> publishCourse(String courseId, {DateTime? publishDate}) async {
    try {
      if (_userId == null) return false;

      await _client
          .from('school_mini_courses')
          .update({
            'status': 'published',
            'publish_date': publishDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'approved_by': _userId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courseId);

      debugPrint('Course published: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error publishing course: $e');
      return false;
    }
  }

  /// Archive a course
  Future<bool> archiveCourse(String courseId) async {
    try {
      await _client
          .from('school_mini_courses')
          .update({
            'status': 'archived',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courseId);

      debugPrint('Course archived: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error archiving course: $e');
      return false;
    }
  }

  /// Delete a course
  Future<bool> deleteCourse(String courseId) async {
    try {
      await _client
          .from('school_mini_courses')
          .delete()
          .eq('id', courseId);

      debugPrint('Course deleted: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error deleting course: $e');
      return false;
    }
  }

  // =====================================================
  // STUDENT PROGRESS METHODS
  // =====================================================

  /// Get student's progress on a course
  Future<Map<String, dynamic>?> getCourseProgress(String courseId) async {
    try {
      if (_userId == null) return null;

      final response = await _client
          .from('school_course_progress')
          .select('*')
          .eq('user_id', _userId!)
          .eq('course_id', courseId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting course progress: $e');
      return null;
    }
  }

  /// Start a course (create progress record)
  Future<Map<String, dynamic>?> startCourse(String courseId, String schoolId) async {
    try {
      if (_userId == null) return null;

      // Check if already started
      final existing = await getCourseProgress(courseId);
      if (existing != null) {
        // Update last accessed
        await _client
            .from('school_course_progress')
            .update({'last_accessed_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
        return existing;
      }

      final response = await _client
          .from('school_course_progress')
          .insert({
            'user_id': _userId,
            'course_id': courseId,
            'school_id': schoolId,
          })
          .select()
          .single();

      debugPrint('Course started: $courseId');
      return response;
    } catch (e) {
      debugPrint('Error starting course: $e');
      return null;
    }
  }

  /// Complete a course and award rewards
  Future<Map<String, dynamic>?> completeCourse({
    required String courseId,
    required int quizScore,
    required int timeSpentSeconds,
  }) async {
    try {
      if (_userId == null) return null;

      final progress = await getCourseProgress(courseId);
      if (progress == null) return null;

      // Get course details for rewards
      final course = await getCourseById(courseId);
      if (course == null) return null;

      final updates = <String, dynamic>{
        'completed_at': DateTime.now().toIso8601String(),
        'quiz_score': quizScore,
        'quiz_attempts': (progress['quiz_attempts'] ?? 0) + 1,
        'time_spent_seconds': timeSpentSeconds,
        'last_accessed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Track best score
      final bestScore = progress['best_quiz_score'] as int?;
      if (bestScore == null || quizScore > bestScore) {
        updates['best_quiz_score'] = quizScore;
      }

      // Award XP and coins if not already awarded
      if (progress['xp_awarded'] != true) {
        updates['xp_awarded'] = true;
        // XP will be awarded via the provider
      }
      if (progress['coins_awarded'] != true) {
        updates['coins_awarded'] = true;
        // Coins will be awarded via the provider
      }

      final response = await _client
          .from('school_course_progress')
          .update(updates)
          .eq('id', progress['id'])
          .select()
          .single();

      debugPrint('Course completed: $courseId with score $quizScore');
      return response;
    } catch (e) {
      debugPrint('Error completing course: $e');
      return null;
    }
  }

  /// Get all completed courses for current user
  Future<List<Map<String, dynamic>>> getCompletedCourses() async {
    try {
      if (_userId == null) return [];

      final response = await _client
          .from('school_course_progress')
          .select('''
            *,
            course:school_mini_courses(id, title, topic, xp_reward, coin_reward, thumbnail_url)
          ''')
          .eq('user_id', _userId!)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting completed courses: $e');
      return [];
    }
  }

  /// Get in-progress courses for current user
  Future<List<Map<String, dynamic>>> getInProgressCourses() async {
    try {
      if (_userId == null) return [];

      final response = await _client
          .from('school_course_progress')
          .select('''
            *,
            course:school_mini_courses(id, title, topic, xp_reward, coin_reward, thumbnail_url, estimated_duration)
          ''')
          .eq('user_id', _userId!)
          .isFilter('completed_at', null)
          .order('last_accessed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting in-progress courses: $e');
      return [];
    }
  }

  // =====================================================
  // RATINGS & FEEDBACK
  // =====================================================

  /// Rate a course
  Future<bool> rateCourse(String courseId, int rating, {String? feedback}) async {
    try {
      if (_userId == null) return false;

      await _client
          .from('school_course_ratings')
          .upsert({
            'course_id': courseId,
            'user_id': _userId,
            'rating': rating,
            'feedback': feedback,
          }, onConflict: 'course_id,user_id');

      debugPrint('Course rated: $courseId with $rating stars');
      return true;
    } catch (e) {
      debugPrint('Error rating course: $e');
      return false;
    }
  }

  /// Get user's rating for a course
  Future<Map<String, dynamic>?> getUserRating(String courseId) async {
    try {
      if (_userId == null) return null;

      final response = await _client
          .from('school_course_ratings')
          .select('*')
          .eq('course_id', courseId)
          .eq('user_id', _userId!)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting user rating: $e');
      return null;
    }
  }

  // =====================================================
  // ANALYTICS (for school admins)
  // =====================================================

  /// Get course analytics for a school
  Future<Map<String, dynamic>> getSchoolCourseAnalytics(String schoolId) async {
    try {
      // Get total courses
      final coursesResponse = await _client
          .from('school_mini_courses')
          .select('id, status, view_count, completion_count')
          .eq('school_id', schoolId);

      final courses = List<Map<String, dynamic>>.from(coursesResponse);

      // Calculate stats
      final totalCourses = courses.length;
      final publishedCourses = courses.where((c) => c['status'] == 'published').length;
      final pendingCourses = courses.where((c) => c['status'] == 'pending_approval').length;
      final totalViews = courses.fold<int>(0, (sum, c) => sum + (c['view_count'] as int? ?? 0));
      final totalCompletions = courses.fold<int>(0, (sum, c) => sum + (c['completion_count'] as int? ?? 0));

      // Get unique students who completed courses
      final progressResponse = await _client
          .from('school_course_progress')
          .select('user_id')
          .eq('school_id', schoolId)
          .not('completed_at', 'is', null);

      final uniqueStudents = Set<String>.from(
        List<Map<String, dynamic>>.from(progressResponse).map((p) => p['user_id'] as String)
      ).length;

      return {
        'total_courses': totalCourses,
        'published_courses': publishedCourses,
        'pending_courses': pendingCourses,
        'draft_courses': courses.where((c) => c['status'] == 'draft').length,
        'total_views': totalViews,
        'total_completions': totalCompletions,
        'unique_students': uniqueStudents,
        'avg_completion_rate': totalViews > 0 ? (totalCompletions / totalViews * 100).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      debugPrint('Error getting school course analytics: $e');
      return {
        'total_courses': 0,
        'published_courses': 0,
        'pending_courses': 0,
        'draft_courses': 0,
        'total_views': 0,
        'total_completions': 0,
        'unique_students': 0,
        'avg_completion_rate': '0',
      };
    }
  }

  /// Get progress data for a specific course (for teachers/admins)
  Future<List<Map<String, dynamic>>> getCourseProgressData(String courseId) async {
    try {
      final response = await _client
          .from('school_course_progress')
          .select('''
            *,
            student:profiles(id, name, avatar_url, grade_level)
          ''')
          .eq('course_id', courseId)
          .order('completed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting course progress data: $e');
      return [];
    }
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  /// Optimize image for upload
  Future<Uint8List> _optimizeImage(Uint8List imageBytes) async {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Resize if too large (max 512x512 for logos)
      if (image.width > 512 || image.height > 512) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height > image.width ? 512 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      final optimizedBytes = img.encodePng(image, level: 6);
      debugPrint('Image optimized: ${imageBytes.length} -> ${optimizedBytes.length} bytes');
      return Uint8List.fromList(optimizedBytes);
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      return imageBytes;
    }
  }

  /// Upload course thumbnail
  Future<String?> uploadCourseThumbnail(String schoolId, Uint8List imageBytes, String fileName) async {
    try {
      final optimizedBytes = await _optimizeImage(imageBytes);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName).toLowerCase();
      final uniqueFileName = 'course_thumb_${schoolId}_$timestamp$extension';

      final uploadPath = 'course-thumbnails/$uniqueFileName';
      await _client.storage
          .from('organization-assets')
          .uploadBinary(uploadPath, optimizedBytes);

      final publicUrl = _client.storage
          .from('organization-assets')
          .getPublicUrl(uploadPath);

      debugPrint('Course thumbnail uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading course thumbnail: $e');
      return null;
    }
  }
}
