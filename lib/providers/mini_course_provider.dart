import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/ai_course_generator_service.dart';
import '../services/supabase_daily_course_service.dart';
import '../services/local_course_cache.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../services/challenge_evaluator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/global_daily_courses_service.dart';
import '../services/community_course_service.dart';

class MiniCourseProvider extends ChangeNotifier {
  List<MiniCourseModel> _courses = [];
  MiniCourseModel? _currentCourse;
  bool _isInitializingCourses = true;
  bool _isRegenerating = false;
  // Global daily (shared) courses
  final GlobalDailyCoursesService _globalService = GlobalDailyCoursesService();
  final CommunityCourseService _communityService = CommunityCourseService.instance;
  final LocalCourseCache _cache = LocalCourseCache.instance;
  List<MiniCourseModel> _todayCourses = [];
  List<CommunityMiniCourse> _communityCourses = [];
  Set<String> _attemptedQuizCourseIds = {};

  // Daily course state for global courses
  DailyCourseState _dailyState = DailyCourseState.initial;
  String? _lastError; // Store last error message for debugging

  List<MiniCourseModel> get courses => _courses;
  MiniCourseModel? get currentCourse => _currentCourse;
  DailyCourseState get dailyState => _dailyState;
  bool get isInitializingCourses => _isInitializingCourses;
  bool get isRegenerating => _isRegenerating;
  List<MiniCourseModel> get todayCourses => _todayCourses;
  List<CommunityMiniCourse> get communityCourses => _communityCourses;
  String? get lastError => _lastError;

  // Get a course by its ID (searches both today's courses and regular courses)
  MiniCourseModel? getCourseById(String courseId) {
    try {
      // First check today's global courses
      final todayCourse = _todayCourses.firstWhere(
        (course) => course.id == courseId,
        orElse: () => throw Exception('Not found'),
      );
      return todayCourse;
    } catch (e) {
      // Fall back to regular courses
      try {
        return _courses.firstWhere((course) => course.id == courseId);
      } catch (e) {
        return null;
      }
    }
  }

  Future<void> _initAttemptedQuizzes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('attempted_quizzes') ?? [];
      _attemptedQuizCourseIds = list.toSet();
    } catch (_) {}
  }

  bool hasAttemptedQuiz(String courseId) {
    return _attemptedQuizCourseIds.contains(courseId);
  }

  Future<void> _persistAttemptedQuizzes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'attempted_quizzes', _attemptedQuizCourseIds.toList());
    } catch (_) {}
  }

  void markQuizAttempted(String courseId) {
    if (_attemptedQuizCourseIds.add(courseId)) {
      _persistAttemptedQuizzes();
      notifyListeners();
    }
  }

  // ================= Global Daily Courses (shared trio) =================
  /// Load today's 3 global mini-courses (shared across all users).
  Future<void> loadTodayCourses() async {
    // Prevent concurrent loads
    if (_dailyState == DailyCourseState.generating ||
        _dailyState == DailyCourseState.fetchingServer) {
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      _dailyState = DailyCourseState.checkingCache;
      notifyListeners();

      final cached = await _cache.getDailyCourses(today);
      if (cached != null && cached.length == 3) {
        _todayCourses = cached;
        _dailyState = DailyCourseState.offlineCached;
        notifyListeners();
        // Soft-verify with server in background
        _verifyAndUpdateFromServer(today);
        return;
      }

      _dailyState = DailyCourseState.fetchingServer;
      notifyListeners();

      // If authenticated, hydrate completion state from server so users can't
      // re-take and re-claim rewards after logout/login.
      final supabase = SupabaseService();
      final uid = supabase.currentUser?.id;
      if (supabase.isAuthenticated && uid != null) {
        _todayCourses = await _globalService.getTodayCoursesForUser(userId: uid);
      } else {
        _todayCourses = await _globalService.getTodayCourses();
      }
      await _cache.saveDailyCourses(today, _todayCourses);
      _dailyState = DailyCourseState.ready;
      _lastError = null; // Clear error on success
      notifyListeners();
    } catch (e) {
      debugPrint('[MiniCourse] ❌ Error loading global daily courses: $e');

      // Determine error type for better user feedback
      String errorMessage;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage =
            'No internet connection. Please check your network and try again.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet and try again.';
      } else if (e.toString().contains('not available')) {
        errorMessage =
            'Courses are being generated. Please try again in a moment.';
      } else {
        errorMessage = 'Failed to load courses. Please try again.';
      }

      _lastError = errorMessage;
      _dailyState = DailyCourseState.error;
      notifyListeners();
    }
  }

  Future<void> _verifyAndUpdateFromServer(String dateKey) async {
    try {
      final supabase = SupabaseService();
      final uid = supabase.currentUser?.id;
      final serverCourses = (supabase.isAuthenticated && uid != null)
          ? await _globalService.getTodayCoursesForUser(userId: uid)
          : await _globalService.getTodayCourses();
      if (serverCourses.length == 3) {
        _todayCourses = serverCourses;
        await _cache.saveDailyCourses(dateKey, serverCourses);
        _dailyState = DailyCourseState.ready;
        notifyListeners();
      }
    } catch (_) {
      // keep cached
    }
  }

  /// Load today's community courses from all communities the user is a member of
  Future<void> loadCommunityCourses() async {
    try {
      _communityCourses = await _communityService.getTodayCommunityCourses();
      notifyListeners();
      debugPrint('[MiniCourse] Loaded ${_communityCourses.length} community courses');
    } catch (e) {
      debugPrint('[MiniCourse] Error loading community courses: $e');
    }
  }

  void upsertCommunityCourse(CommunityMiniCourse course) {
    final index = _communityCourses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _communityCourses[index] = course;
    } else {
      _communityCourses.add(course);
    }
    notifyListeners();
  }

  void removeCommunityCourse(String courseId) {
    _communityCourses.removeWhere((c) => c.id == courseId);
    notifyListeners();
  }

  /// Get a community course by ID
  CommunityMiniCourse? getCommunityCourseById(String courseId) {
    try {
      return _communityCourses.firstWhere((c) => c.id == courseId);
    } catch (e) {
      return null;
    }
  }

  /// Submit quiz for a community course
  Future<Map<String, dynamic>> submitCommunityCourseQuiz({
    required CommunityMiniCourse course,
    required int score,
  }) async {
    try {
      final result = await _communityService.markCompleted(
        courseId: course.id,
        score: score,
      );

      // Update local state
      final index = _communityCourses.indexWhere((c) => c.id == course.id);
      if (index != -1) {
        _communityCourses[index] = _communityCourses[index].copyWith(
          isCompleted: true,
          score: score,
        );
        notifyListeners();
      }

      return {
        'score': score,
        ...result,
      };
    } catch (e) {
      debugPrint('[MiniCourse] Error submitting community course quiz: $e');
      rethrow;
    }
  }

  /// Compute score and mark completion using deterministic marker (date + index)
  /// Returns a map with: { score, rewards_granted, coins_awarded, xp_awarded }
  Future<Map<String, dynamic>> submitQuizForCourse({
    required MiniCourseModel course,
    required String userId,
    required int courseIndex,
    BuildContext? uiContext, // optional for snackbar on error
    int? overrideScore, // if provided, use this percent score from UI
  }) async {
    final questions = course.quiz.questions;
    final correct = questions
        .where((q) => q.selectedOptionIndex == q.correctAnswerIndex)
        .length;
    // Prefer UI-computed score if passed in; otherwise compute from model
    final score = overrideScore ??
        ((correct / (questions.isEmpty ? 1 : questions.length)) * 100).round();

    _markQuizCompletedLocally(course.id, score);
    markQuizAttempted(course.id);

    Map<String, dynamic> result = {
      'score': score,
      'rewards_granted': false,
      'coins_awarded': 0,
      'xp_awarded': 0,
    };

    if (score >= 70) {
      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        // Use secure server-side completion that handles rewards atomically
        final serverResult = await _globalService.markCompletedSecure(
          userId: userId,
          courseDate: dateStr,
          courseIndex: courseIndex,
          score: score,
        );
        
        // Extract reward info from server response
        result['rewards_granted'] = serverResult['rewards_granted'] ?? false;
        result['coins_awarded'] = serverResult['coins_awarded'] ?? 0;
        result['xp_awarded'] = serverResult['xp_awarded'] ?? 0;
        result['new_coin_balance'] = serverResult['new_coin_balance'];
        result['new_xp'] = serverResult['new_xp'];
        result['already_completed'] = serverResult['already_completed'] ?? false;
        
        debugPrint('[MiniCourse] ✅ Server completion result: $serverResult');
        
        await ChallengeEvaluator.instance.evaluateMiniCourseChallenges();
      } catch (e) {
        debugPrint('[MiniCourse] ❌ Failed to mark completion: $e');
        // Optional UX: snackbar
        try {
          if (uiContext != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(uiContext).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Failed to save mini-course completion. Please retry.')),
            );
          }
        } catch (_) {}
      }
    }
    return result;
  }

  /// Mark quiz as completed locally to prevent retakes
  void _markQuizCompletedLocally(String courseId, int score) {
    // Check in today's courses first
    final todayIndex = _todayCourses.indexWhere((c) => c.id == courseId);
    if (todayIndex != -1) {
      final course = _todayCourses[todayIndex];
      final updatedQuiz = course.quiz.copyWith(
        isCompleted: true,
        score: score,
      );
      _todayCourses[todayIndex] = course.copyWith(quiz: updatedQuiz);
      notifyListeners();
      debugPrint(
          '[MiniCourse] ✅ Quiz marked as completed locally (today\'s courses)');
      return;
    }

    // Fall back to regular courses
    final courseIndex = _courses.indexWhere((c) => c.id == courseId);
    if (courseIndex != -1) {
      final course = _courses[courseIndex];
      final updatedQuiz = course.quiz.copyWith(
        isCompleted: true,
        score: score,
      );
      _courses[courseIndex] = course.copyWith(quiz: updatedQuiz);

      // Update current course if this is the current course
      if (_currentCourse != null && _currentCourse!.id == courseId) {
        _currentCourse = _courses[courseIndex];
      }

      notifyListeners();
      debugPrint(
          '[MiniCourse] ✅ Quiz marked as completed locally (regular courses)');
    }
  }

  // Available topics for randomly generating courses
  final List<String> _availableTopics = [
    'Goal Setting',
    'Leadership Skills',
    'Teamwork',
    'Communication',
    'Problem Solving',
    'Time Management',
    'Public Speaking',
    'Conflict Resolution',
    'Critical Thinking',
    'Emotional Intelligence',
    'Decision Making',
    'Creativity',
  ];

  // Initialize with empty courses - use ensureTodayDailyCourse() for daily generation
  MiniCourseProvider() {
    // Don't generate courses in constructor to save API costs
    // Courses will be loaded via ensureTodayDailyCourse() when needed
    _initAttemptedQuizzes();
  }

  // Deprecated methods removed - use loadTodayCourses() for global daily courses

  /// Clear and regenerate a batch of random courses with loading state
  Future<void> regenerateRandomCourses({int count = 4}) async {
    _isRegenerating = true;
    _courses.clear();
    notifyListeners();
    for (int i = 0; i < count; i++) {
      await generateRandomCourse();
    }
    _isRegenerating = false;
    notifyListeners();
    // Trigger mini-course challenge evaluation after manual completion
    try {
      ChallengeEvaluator.instance.evaluateMiniCourseChallenges();
    } catch (_) {}
  }

  // Generate a new random mini-course using AI
  Future<void> generateRandomCourse() async {
    try {
      // Get a random topic that isn't already in the courses list
      final availableTopics = _availableTopics.where((topic) {
        return !_courses.any((course) => course.title.contains(topic));
      }).toList();

      if (availableTopics.isEmpty) {
        // If all topics have been used, clear the courses and start over
        _courses.clear();
        await generateRandomCourse();
        return;
      }

      // Randomly select a topic
      final random =
          DateTime.now().millisecondsSinceEpoch % availableTopics.length;
      final selectedTopic = availableTopics[random];

      debugPrint('Generating AI course for topic: $selectedTopic');

      // Generate a course using AI
      final newCourse = await AiCourseGeneratorService.instance.generateCourse(
        topic: selectedTopic,
        targetAge: 12,
        difficultyLevel: 'beginner',
      );

      if (newCourse != null) {
        // Add to courses list
        _courses.add(newCourse);
        debugPrint('Successfully generated AI course: ${newCourse.title}');
      } else {
        // Fallback to mock generation if AI fails
        final fallbackCourse = MiniCourseModel.generateFromTopic(selectedTopic);
        _courses.add(fallbackCourse);
        debugPrint('Used fallback course generation for: $selectedTopic');
      }
    } catch (e) {
      debugPrint('Error generating random course: $e');

      // Fallback to mock generation
      final availableTopics = _availableTopics.where((topic) {
        return !_courses.any((course) => course.title.contains(topic));
      }).toList();

      if (availableTopics.isNotEmpty) {
        final random =
            DateTime.now().millisecondsSinceEpoch % availableTopics.length;
        final selectedTopic = availableTopics[random];
        final fallbackCourse = MiniCourseModel.generateFromTopic(selectedTopic);
        _courses.add(fallbackCourse);
      }
    }

    notifyListeners();
  }

  // Set the current course being viewed/taken
  void setCurrentCourse(String courseId) {
    _currentCourse = _courses.firstWhere((course) => course.id == courseId);

    // If the course is not started, mark it as in progress
    if (_currentCourse!.status == MiniCourseStatus.notStarted) {
      _updateCourseStatus(courseId, MiniCourseStatus.inProgress,
          startedAt: DateTime.now());
    }

    notifyListeners();
  }

  // Mark a lesson as completed and move to the next lesson
  void completeLesson(String courseId) {
    final courseIndex = _courses.indexWhere((course) => course.id == courseId);
    if (courseIndex == -1) return;

    final course = _courses[courseIndex];
    final currentLessonIndex = course.currentLessonIndex;

    // If we're already at the last lesson, don't increment
    if (currentLessonIndex >= course.lessons.length) return;

    // Mark the current lesson as completed
    final updatedLessons = List<MiniCourseLessonModel>.from(course.lessons);
    updatedLessons[currentLessonIndex] =
        updatedLessons[currentLessonIndex].copyWith(isCompleted: true);

    // Update the course with the next lesson index
    _courses[courseIndex] = course.copyWith(
      lessons: updatedLessons,
      currentLessonIndex: currentLessonIndex + 1,
      status: MiniCourseStatus.inProgress,
    );

    // Update current course if this is the current course
    if (_currentCourse != null && _currentCourse!.id == courseId) {
      _currentCourse = _courses[courseIndex];
    }

    notifyListeners();
  }

  // Mark a lesson as completed by its ID (used in the old implementation)
  void completeLessonInCurrentCourse(String lessonId) {
    if (_currentCourse == null) return;

    final courseId = _currentCourse!.id;
    final courseIndex = _courses.indexWhere((course) => course.id == courseId);
    if (courseIndex == -1) return;

    // Update the lesson
    final updatedLessons =
        List<MiniCourseLessonModel>.from(_currentCourse!.lessons);
    final lessonIndex =
        updatedLessons.indexWhere((lesson) => lesson.id == lessonId);
    if (lessonIndex == -1) return;

    updatedLessons[lessonIndex] =
        updatedLessons[lessonIndex].copyWith(isCompleted: true);

    // Update the course with the updated lessons
    _courses[courseIndex] =
        _courses[courseIndex].copyWith(lessons: updatedLessons);
    _currentCourse = _courses[courseIndex];

    notifyListeners();
  }

  // Legacy submitQuizAnswers removed - use submitQuizForCourse() with deterministic markers

  // Helper method to update course status
  void _updateCourseStatus(String courseId, MiniCourseStatus status,
      {DateTime? startedAt, DateTime? completedAt}) {
    final courseIndex = _courses.indexWhere((course) => course.id == courseId);
    if (courseIndex == -1) return;

    _courses[courseIndex] = _courses[courseIndex].copyWith(
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
    );

    // Update current course if this is the current course
    if (_currentCourse != null && _currentCourse!.id == courseId) {
      _currentCourse = _courses[courseIndex];
    }

    notifyListeners();
  }

  // Mark a course as completed
  void completeCourse(String courseId) {
    final courseIndex = _courses.indexWhere((course) => course.id == courseId);
    if (courseIndex == -1) return;

    // Update the course status to completed
    _courses[courseIndex] = _courses[courseIndex].copyWith(
      status: MiniCourseStatus.completed,
      completedAt: DateTime.now(),
    );

    // Update current course if this is the current course
    if (_currentCourse != null && _currentCourse!.id == courseId) {
      _currentCourse = _courses[courseIndex];
    }

    notifyListeners();
  }

  // Get all completed courses
  List<MiniCourseModel> getCompletedCourses() {
    return _courses
        .where((course) => course.status == MiniCourseStatus.completed)
        .toList();
  }

  // Get all in-progress courses
  List<MiniCourseModel> getInProgressCourses() {
    return _courses
        .where((course) => course.status == MiniCourseStatus.inProgress)
        .toList();
  }

  // Get all not-started courses
  List<MiniCourseModel> getNotStartedCourses() {
    return _courses
        .where((course) => course.status == MiniCourseStatus.notStarted)
        .toList();
  }

  /// Clear all state (call on logout to prevent cross-account leakage)
  void clearState() {
    _courses.clear();
    _currentCourse = null;
    _todayCourses.clear();
    _communityCourses.clear();
    _attemptedQuizCourseIds.clear();
    _dailyState = DailyCourseState.initial;
    _lastError = null;
    _isRegenerating = false;
    _isInitializingCourses = true;
    notifyListeners();
    debugPrint('🧹 MiniCourseProvider state cleared');
  }

  /// Clear SharedPreferences cache for attempted quizzes
  Future<void> clearAttemptedQuizzesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('attempted_quizzes');
      _attemptedQuizCourseIds.clear();
      debugPrint('🧹 Attempted quizzes cache cleared');
    } catch (e) {
      debugPrint('Error clearing attempted quizzes cache: $e');
    }
  }

  // Legacy per-user daily course removed - use loadTodayCourses() for global shared courses
}

/// UI-facing daily state machine for the daily mini-course
enum DailyCourseState {
  initial,
  checkingCache,
  fetchingServer,
  generating,
  polling,
  ready,
  offlineCached,
  error,
}
