import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/school_course_model.dart';
import '../services/school_course_service.dart';

/// Provider for managing school-specific mini courses
/// This is a PREMIUM feature for schools
class SchoolCourseProvider extends ChangeNotifier {
  final SchoolCourseService _service = SchoolCourseService.instance;

  // State
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _currentSchool;
  bool _isSchoolAdmin = false;
  bool _isTeacher = false;
  bool _hasPremium = false;

  // Course lists
  List<SchoolCourse> _allCourses = [];
  List<SchoolCourse> _publishedCourses = [];
  List<SchoolCourse> _pendingCourses = [];
  List<SchoolCourse> _myCourses = [];
  List<SchoolCourseCategory> _categories = [];

  // Progress
  List<SchoolCourseProgress> _completedCourses = [];
  List<SchoolCourseProgress> _inProgressCourses = [];

  // Analytics
  Map<String, dynamic> _analytics = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get currentSchool => _currentSchool;
  bool get isSchoolAdmin => _isSchoolAdmin;
  bool get isTeacher => _isTeacher;
  bool get hasPremium => _hasPremium;
  bool get hasSchool => _currentSchool != null;
  String? get schoolId => _currentSchool?['id'] as String?;
  String? get schoolName => _currentSchool?['name'] as String?;
  String? get schoolLogo => _currentSchool?['logo_url'] as String?;
  String? get schoolPrimaryColor => _currentSchool?['primary_color'] as String?;

  List<SchoolCourse> get allCourses => _allCourses;
  List<SchoolCourse> get publishedCourses => _publishedCourses;
  List<SchoolCourse> get pendingCourses => _pendingCourses;
  List<SchoolCourse> get myCourses => _myCourses;
  List<SchoolCourseCategory> get categories => _categories;
  List<SchoolCourse> get featuredCourses =>
      _publishedCourses.where((c) => c.isFeatured).toList();

  List<SchoolCourseProgress> get completedCourses => _completedCourses;
  List<SchoolCourseProgress> get inProgressCourses => _inProgressCourses;
  Map<String, dynamic> get analytics => _analytics;

  /// Initialize the provider - call this when user logs in
  Future<void> initialize() async {
    _setLoading(true);
    _error = null;

    try {
      // Get user's school
      _currentSchool = await _service.getCurrentUserSchool();

      if (_currentSchool != null) {
        final schoolId = _currentSchool!['id'] as String;

        // Check roles
        _isSchoolAdmin = await _service.isSchoolAdmin();
        _isTeacher = await _service.isSchoolTeacher();
        _hasPremium = await _service.schoolHasPremium(schoolId);

        // Load categories
        await loadCategories();

        // Load courses based on role
        if (_isSchoolAdmin) {
          await loadAllCoursesForAdmin();
          await loadPendingCourses();
          await loadAnalytics();
        } else if (_isTeacher) {
          await loadMyCourses();
        }

        // Load published courses for all users
        await loadPublishedCourses();

        // Load user's progress
        await loadUserProgress();
      }

      debugPrint('SchoolCourseProvider initialized: school=${_currentSchool?['name']}, admin=$_isSchoolAdmin, teacher=$_isTeacher, premium=$_hasPremium');
    } catch (e) {
      _error = 'Failed to initialize: $e';
      debugPrint('Error initializing SchoolCourseProvider: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    await initialize();
  }

  // =====================================================
  // CATEGORY METHODS
  // =====================================================

  Future<void> loadCategories() async {
    if (schoolId == null) return;

    try {
      final data = await _service.getSchoolCategories(schoolId!);
      _categories = data.map((e) => SchoolCourseCategory.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<SchoolCourseCategory?> createCategory({
    required String name,
    String? description,
    String icon = 'book',
    String color = '#00C4FF',
  }) async {
    if (schoolId == null || !_isSchoolAdmin) return null;

    try {
      final data = await _service.createCategory(
        schoolId: schoolId!,
        name: name,
        description: description,
        icon: icon,
        color: color,
      );

      if (data != null) {
        final category = SchoolCourseCategory.fromJson(data);
        _categories.add(category);
        notifyListeners();
        return category;
      }
    } catch (e) {
      _error = 'Failed to create category: $e';
      debugPrint('Error creating category: $e');
    }
    return null;
  }

  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? icon,
    String? color,
  }) async {
    if (!_isSchoolAdmin) return false;

    try {
      final success = await _service.updateCategory(
        categoryId: categoryId,
        name: name,
        description: description,
        icon: icon,
        color: color,
      );

      if (success) {
        await loadCategories();
      }
      return success;
    } catch (e) {
      _error = 'Failed to update category: $e';
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    if (!_isSchoolAdmin) return false;

    try {
      final success = await _service.deleteCategory(categoryId);
      if (success) {
        _categories.removeWhere((c) => c.id == categoryId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Failed to delete category: $e';
      return false;
    }
  }

  // =====================================================
  // COURSE LOADING METHODS
  // =====================================================

  Future<void> loadAllCoursesForAdmin() async {
    if (schoolId == null || !_isSchoolAdmin) return;

    try {
      final data = await _service.getSchoolCoursesForAdmin(schoolId!);
      _allCourses = data.map((e) => SchoolCourse.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all courses: $e');
    }
  }

  Future<void> loadPublishedCourses({String? gradeLevel}) async {
    if (schoolId == null) return;

    try {
      final data = await _service.getPublishedCourses(schoolId!, gradeLevel: gradeLevel);
      _publishedCourses = data.map((e) => SchoolCourse.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading published courses: $e');
    }
  }

  Future<void> loadPendingCourses() async {
    if (schoolId == null || !_isSchoolAdmin) return;

    try {
      final data = await _service.getPendingApprovalCourses(schoolId!);
      _pendingCourses = data.map((e) => SchoolCourse.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending courses: $e');
    }
  }

  Future<void> loadMyCourses() async {
    try {
      final data = await _service.getMyCourses();
      _myCourses = data.map((e) => SchoolCourse.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading my courses: $e');
    }
  }

  Future<SchoolCourse?> getCourseById(String courseId) async {
    try {
      final data = await _service.getCourseById(courseId);
      if (data != null) {
        return SchoolCourse.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error getting course: $e');
    }
    return null;
  }

  // =====================================================
  // COURSE CRUD METHODS
  // =====================================================

  Future<SchoolCourse?> createCourse({
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
    if (schoolId == null) return null;
    if (!_isTeacher && !_isSchoolAdmin) return null;

    _setLoading(true);
    try {
      final data = await _service.createCourse(
        schoolId: schoolId!,
        title: title,
        description: description,
        topic: topic,
        summary: summary,
        content: content,
        quizQuestions: quizQuestions,
        gradeLevels: gradeLevels,
        subject: subject,
        categoryId: categoryId,
        xpReward: xpReward,
        coinReward: coinReward,
        difficulty: difficulty,
        estimatedDuration: estimatedDuration,
        thumbnailUrl: thumbnailUrl,
        submitForApproval: submitForApproval,
      );

      if (data != null) {
        final course = SchoolCourse.fromJson(data);

        // Add to appropriate lists
        if (_isSchoolAdmin) {
          _allCourses.insert(0, course);
        }
        _myCourses.insert(0, course);

        notifyListeners();
        return course;
      }
    } catch (e) {
      _error = 'Failed to create course: $e';
      debugPrint('Error creating course: $e');
    } finally {
      _setLoading(false);
    }
    return null;
  }

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
    _setLoading(true);
    try {
      final success = await _service.updateCourse(
        courseId: courseId,
        title: title,
        description: description,
        topic: topic,
        summary: summary,
        content: content,
        quizQuestions: quizQuestions,
        gradeLevels: gradeLevels,
        subject: subject,
        categoryId: categoryId,
        xpReward: xpReward,
        coinReward: coinReward,
        difficulty: difficulty,
        estimatedDuration: estimatedDuration,
        thumbnailUrl: thumbnailUrl,
        isFeatured: isFeatured,
        publishDate: publishDate,
        expiryDate: expiryDate,
      );

      if (success) {
        // Refresh course lists
        await refresh();
      }
      return success;
    } catch (e) {
      _error = 'Failed to update course: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitCourseForApproval(String courseId) async {
    try {
      final success = await _service.submitForApproval(courseId);
      if (success) {
        // Update local state
        final index = _myCourses.indexWhere((c) => c.id == courseId);
        if (index != -1) {
          _myCourses[index] = _myCourses[index].copyWith(
            status: SchoolCourseStatus.pendingApproval,
          );
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      _error = 'Failed to submit course: $e';
      return false;
    }
  }

  Future<bool> approveCourse(String courseId) async {
    if (!_isSchoolAdmin) return false;

    try {
      final success = await _service.approveCourse(courseId);
      if (success) {
        await loadPendingCourses();
        await loadPublishedCourses();
        await loadAllCoursesForAdmin();
      }
      return success;
    } catch (e) {
      _error = 'Failed to approve course: $e';
      return false;
    }
  }

  Future<bool> rejectCourse(String courseId, String reason) async {
    if (!_isSchoolAdmin) return false;

    try {
      final success = await _service.rejectCourse(courseId, reason);
      if (success) {
        await loadPendingCourses();
        await loadAllCoursesForAdmin();
      }
      return success;
    } catch (e) {
      _error = 'Failed to reject course: $e';
      return false;
    }
  }

  Future<bool> publishCourse(String courseId, {DateTime? publishDate}) async {
    if (!_isSchoolAdmin) return false;

    try {
      final success = await _service.publishCourse(courseId, publishDate: publishDate);
      if (success) {
        await loadAllCoursesForAdmin();
        await loadPublishedCourses();
      }
      return success;
    } catch (e) {
      _error = 'Failed to publish course: $e';
      return false;
    }
  }

  Future<bool> archiveCourse(String courseId) async {
    try {
      final success = await _service.archiveCourse(courseId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      _error = 'Failed to archive course: $e';
      return false;
    }
  }

  Future<bool> deleteCourse(String courseId) async {
    try {
      final success = await _service.deleteCourse(courseId);
      if (success) {
        _allCourses.removeWhere((c) => c.id == courseId);
        _myCourses.removeWhere((c) => c.id == courseId);
        _publishedCourses.removeWhere((c) => c.id == courseId);
        _pendingCourses.removeWhere((c) => c.id == courseId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Failed to delete course: $e';
      return false;
    }
  }

  // =====================================================
  // STUDENT PROGRESS METHODS
  // =====================================================

  Future<void> loadUserProgress() async {
    try {
      final completed = await _service.getCompletedCourses();
      _completedCourses = completed.map((e) => SchoolCourseProgress.fromJson(e)).toList();

      final inProgress = await _service.getInProgressCourses();
      _inProgressCourses = inProgress.map((e) => SchoolCourseProgress.fromJson(e)).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user progress: $e');
    }
  }

  Future<SchoolCourseProgress?> startCourse(String courseId) async {
    if (schoolId == null) return null;

    try {
      final data = await _service.startCourse(courseId, schoolId!);
      if (data != null) {
        final progress = SchoolCourseProgress.fromJson(data);

        // Add to in-progress if not already there
        if (!_inProgressCourses.any((p) => p.courseId == courseId)) {
          _inProgressCourses.insert(0, progress);
          notifyListeners();
        }

        return progress;
      }
    } catch (e) {
      debugPrint('Error starting course: $e');
    }
    return null;
  }

  Future<SchoolCourseProgress?> completeCourse({
    required String courseId,
    required int quizScore,
    required int timeSpentSeconds,
  }) async {
    try {
      final data = await _service.completeCourse(
        courseId: courseId,
        quizScore: quizScore,
        timeSpentSeconds: timeSpentSeconds,
      );

      if (data != null) {
        final progress = SchoolCourseProgress.fromJson(data);

        // Move from in-progress to completed
        _inProgressCourses.removeWhere((p) => p.courseId == courseId);
        _completedCourses.insert(0, progress);

        notifyListeners();
        return progress;
      }
    } catch (e) {
      debugPrint('Error completing course: $e');
    }
    return null;
  }

  SchoolCourseProgress? getProgressForCourse(String courseId) {
    // Check completed first
    final completed = _completedCourses.where((p) => p.courseId == courseId).firstOrNull;
    if (completed != null) return completed;

    // Then check in-progress
    return _inProgressCourses.where((p) => p.courseId == courseId).firstOrNull;
  }

  bool isCourseCompleted(String courseId) {
    return _completedCourses.any((p) => p.courseId == courseId);
  }

  bool isCourseStarted(String courseId) {
    return _inProgressCourses.any((p) => p.courseId == courseId) ||
        _completedCourses.any((p) => p.courseId == courseId);
  }

  // =====================================================
  // RATINGS
  // =====================================================

  Future<bool> rateCourse(String courseId, int rating, {String? feedback}) async {
    try {
      return await _service.rateCourse(courseId, rating, feedback: feedback);
    } catch (e) {
      debugPrint('Error rating course: $e');
      return false;
    }
  }

  // =====================================================
  // SCHOOL BRANDING
  // =====================================================

  Future<String?> uploadSchoolLogo(Uint8List imageBytes, String fileName) async {
    if (schoolId == null || !_isSchoolAdmin) return null;

    _setLoading(true);
    try {
      final url = await _service.uploadSchoolLogo(schoolId!, imageBytes, fileName);
      if (url != null) {
        _currentSchool?['logo_url'] = url;
        notifyListeners();
      }
      return url;
    } catch (e) {
      _error = 'Failed to upload logo: $e';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateSchoolBranding({
    String? primaryColor,
    String? secondaryColor,
  }) async {
    if (schoolId == null || !_isSchoolAdmin) return false;

    try {
      final success = await _service.updateSchoolBranding(
        schoolId: schoolId!,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      );

      if (success) {
        if (primaryColor != null) _currentSchool?['primary_color'] = primaryColor;
        if (secondaryColor != null) _currentSchool?['secondary_color'] = secondaryColor;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Failed to update branding: $e';
      return false;
    }
  }

  // =====================================================
  // ANALYTICS
  // =====================================================

  Future<void> loadAnalytics() async {
    if (schoolId == null || !_isSchoolAdmin) return;

    try {
      _analytics = await _service.getSchoolCourseAnalytics(schoolId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCourseProgressData(String courseId) async {
    try {
      return await _service.getCourseProgressData(courseId);
    } catch (e) {
      debugPrint('Error getting course progress data: $e');
      return [];
    }
  }

  // =====================================================
  // THUMBNAIL UPLOAD
  // =====================================================

  Future<String?> uploadCourseThumbnail(Uint8List imageBytes, String fileName) async {
    if (schoolId == null) return null;

    try {
      return await _service.uploadCourseThumbnail(schoolId!, imageBytes, fileName);
    } catch (e) {
      debugPrint('Error uploading thumbnail: $e');
      return null;
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data (call on logout)
  void clear() {
    _currentSchool = null;
    _isSchoolAdmin = false;
    _isTeacher = false;
    _hasPremium = false;
    _allCourses = [];
    _publishedCourses = [];
    _pendingCourses = [];
    _myCourses = [];
    _categories = [];
    _completedCourses = [];
    _inProgressCourses = [];
    _analytics = {};
    _error = null;
    notifyListeners();
  }

  /// Get courses filtered by category
  List<SchoolCourse> getCoursesByCategory(String categoryId) {
    return _publishedCourses.where((c) => c.categoryId == categoryId).toList();
  }

  /// Get courses filtered by difficulty
  List<SchoolCourse> getCoursesByDifficulty(String difficulty) {
    return _publishedCourses.where((c) => c.difficulty == difficulty).toList();
  }

  /// Search courses by title or topic
  List<SchoolCourse> searchCourses(String query) {
    final lowerQuery = query.toLowerCase();
    return _publishedCourses.where((c) {
      return c.title.toLowerCase().contains(lowerQuery) ||
          c.topic.toLowerCase().contains(lowerQuery) ||
          (c.subject?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
