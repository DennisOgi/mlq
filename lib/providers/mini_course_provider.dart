import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/ai_course_generator_service.dart';
import '../services/supabase_daily_course_service.dart';
import '../services/local_course_cache.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../services/challenge_evaluator.dart';
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
  bool _isMaintenance = false; // true when AI generation has explicitly failed

  List<MiniCourseModel> get courses => _courses;
  MiniCourseModel? get currentCourse => _currentCourse;
  DailyCourseState get dailyState => _dailyState;
  bool get isInitializingCourses => _isInitializingCourses;
  bool get isRegenerating => _isRegenerating;
  List<MiniCourseModel> get todayCourses => _todayCourses;
  List<CommunityMiniCourse> get communityCourses => _communityCourses;
  String? get lastError => _lastError;
  bool get isMaintenance => _isMaintenance;

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

  void _syncAttemptedQuizzesFromTodayCourses() {
    final todayIds = _todayCourses.map((c) => c.id).toSet();
    _attemptedQuizCourseIds.removeWhere(todayIds.contains);
    for (final course in _todayCourses) {
      if (course.quiz.isCompleted) {
        _attemptedQuizCourseIds.add(course.id);
      }
    }
  }

  bool hasAttemptedQuiz(String courseId) {
    return _attemptedQuizCourseIds.contains(courseId);
  }

  void markQuizAttempted(String courseId) {
    if (_attemptedQuizCourseIds.add(courseId)) {
      notifyListeners();
    }
  }

  // ================= Global Daily Courses (shared trio) =================
  /// Load today's 3 global mini-courses (shared across all users).
  /// Always prefers live server data so quiz answer indices stay accurate.
  Future<void> loadTodayCourses() async {
    // Prevent concurrent loads
    if (_dailyState == DailyCourseState.generating ||
        _dailyState == DailyCourseState.fetchingServer) {
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      _dailyState = DailyCourseState.fetchingServer;
      notifyListeners();

      final supabase = SupabaseService();
      final uid = supabase.currentUser?.id;
      if (supabase.isAuthenticated && uid != null) {
        _todayCourses = await _globalService.getTodayCoursesForUser(userId: uid);
        _syncAttemptedQuizzesFromTodayCourses();
      } else {
        _todayCourses = await _globalService.getTodayCourses();
      }
      await _cache.saveDailyCourses(today, _todayCourses);
      _dailyState = DailyCourseState.ready;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[MiniCourse] Server load failed, trying cache: $e');

      try {
        _dailyState = DailyCourseState.checkingCache;
        notifyListeners();
        final cached = await _cache.getDailyCourses(today);
        if (cached != null && cached.length == 3) {
          _todayCourses = cached;
          try {
            final cacheSupabase = SupabaseService();
            final cacheUid = cacheSupabase.currentUser?.id;
            if (cacheSupabase.isAuthenticated && cacheUid != null) {
              _todayCourses = await _globalService.hydrateCourseCompletion(
                courses: _todayCourses,
                userId: cacheUid,
              );
            }
          } catch (hydrateErr) {
            debugPrint('[MiniCourse] Cache hydrate failed: $hydrateErr');
          }
          _syncAttemptedQuizzesFromTodayCourses();
          _dailyState = DailyCourseState.offlineCached;
          _lastError = null;
          _isMaintenance = false;
          notifyListeners();
          return;
        }
      } catch (cacheErr) {
        debugPrint('[MiniCourse] Cache fallback failed: $cacheErr');
      }

      debugPrint('[MiniCourse] ❌ Error loading global daily courses: $e');

      // Determine error type for better user feedback
      String errorMessage;
      final eStr = e.toString();
      if (eStr.contains('MAINTENANCE:')) {
        errorMessage = eStr.replaceFirst('Exception: MAINTENANCE:', '').trim();
        _isMaintenance = true;
      } else if (eStr.contains('SocketException') ||
          eStr.contains('NetworkException') ||
          eStr.contains('Failed host lookup')) {
        errorMessage =
            'No internet connection. Please check your network and try again.';
        _isMaintenance = false;
      } else if (eStr.contains('TimeoutException')) {
        errorMessage =
            'Connection timeout. Please check your internet and try again.';
        _isMaintenance = false;
      } else if (eStr.contains('not available')) {
        errorMessage =
            'Courses are being generated. Please try again in a moment.';
        _isMaintenance = false;
      } else {
        errorMessage = 'Failed to load courses. Please try again.';
        _isMaintenance = false;
      }

      _lastError = errorMessage;
      _dailyState = DailyCourseState.error;
      notifyListeners();
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

      // Update local state only after a real pass.
      if (score >= 70 || result['already_completed'] == true) {
        final index = _communityCourses.indexWhere((c) => c.id == course.id);
        if (index != -1) {
          _communityCourses[index] = _communityCourses[index].copyWith(
            isCompleted: true,
            score: score,
          );
          notifyListeners();
        }
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
    String? courseDate,
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

    Map<String, dynamic> result = {
      'score': score,
      'rewards_granted': false,
      'coins_awarded': 0,
      'xp_awarded': 0,
      'already_attempted': false,
      'already_completed': false,
    };

    try {
      // Prefer date from course id / caller; fall back to local today
      final dateStr = courseDate ??
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      final serverResult = await _globalService.submitQuizSecure(
        userId: userId,
        courseDate: dateStr,
        courseIndex: courseIndex,
        score: score,
      );

      if (serverResult['success'] != true) {
        debugPrint('[MiniCourse] ❌ Server rejected quiz submit: $serverResult');
        try {
          if (uiContext != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(uiContext).showSnackBar(
              const SnackBar(
                content: Text(
                    'Failed to save quiz attempt. Please check your connection and retry.'),
              ),
            );
          }
        } catch (_) {}
        return result;
      }

      final recordedScore =
          (serverResult['score'] as num?)?.toInt() ?? score;
      final passed = recordedScore >= 70 ||
          serverResult['already_completed'] == true;
      debugPrint(
        '[MiniCourse] quiz submit course=${course.id} index=$courseIndex '
        'score=$recordedScore passed=$passed reason=${serverResult['reason']}',
      );
      if (passed) {
        markQuizAttempted(course.id);
        _markQuizCompletedLocally(course.id, recordedScore);
      }

      result['score'] = recordedScore;
      result['rewards_granted'] = serverResult['rewards_granted'] ?? false;
      result['coins_awarded'] = serverResult['coins_awarded'] ?? 0;
      result['xp_awarded'] = serverResult['xp_awarded'] ?? 0;
      result['new_coin_balance'] = serverResult['new_coin_balance'];
      result['new_xp'] = serverResult['new_xp'];
      result['already_completed'] = serverResult['already_completed'] ?? false;
      result['already_attempted'] = serverResult['already_attempted'] ?? false;
      result['reason'] = serverResult['reason'];

      debugPrint('[MiniCourse] ✅ Server quiz submit result: $serverResult');

      if (result['rewards_granted'] == true) {
        await ChallengeEvaluator.instance.evaluateMiniCourseChallenges();
      }
    } catch (e) {
      debugPrint('[MiniCourse] ❌ Failed to submit quiz: $e');
      try {
        if (uiContext != null) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(uiContext).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to save mini-course quiz. Please retry.'),
            ),
          );
        }
      } catch (_) {}
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
      _todayCourses[todayIndex] = course.copyWith(
        quiz: updatedQuiz,
        status: MiniCourseStatus.completed,
        completedAt: DateTime.now(),
      );
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
      _courses[courseIndex] = course.copyWith(
        quiz: updatedQuiz,
        status: MiniCourseStatus.completed,
        completedAt: DateTime.now(),
      );

      // Update current course if this is the current course
      if (_currentCourse != null && _currentCourse!.id == courseId) {
        _currentCourse = _courses[courseIndex];
      }

      notifyListeners();
      debugPrint(
          '[MiniCourse] ✅ Quiz marked as completed locally (regular courses)');
    }
  }

  // Combined leadership + health topics (sync with mini_course_topic_pool.json)
  final List<String> _availableTopics = [
    'Leadership',
    'Personal Growth',
    'Confidence',
    'Communication',
    'Motivation',
    'Emotional Intelligence',
    'Self-Discipline',
    'Mindset',
    'Productivity',
    'Creativity',
    'Goal Setting',
    'Decision Making',
    'Resilience',
    'Problem Solving',
    'Influence',
    'Time Management',
    'Conflict Resolution',
    'Teamwork & Collaboration',
    'Water First',
    'How Much Water Do I Need?',
    'Signs You\'re Thirsty',
    'Water vs Soda and Juice',
    'Eat the Rainbow',
    'Protein Power',
    'Smart Snacks',
    'Breakfast Wins',
    'Sugar Check',
    'Move Every Day',
    'Posture Power',
    'Screen Breaks',
    'Sleep Equals Strength',
    'Handwashing Like a Pro',
    'Teeth and Smile Care',
    'Rest and Reset',
    'Breathe to Calm',
    'Gratitude Journal',
    'Faith and Health',
  ];

  // Initialize with empty courses - use loadTodayCourses() for global daily courses
  MiniCourseProvider() {
    // Courses are loaded via loadTodayCourses() when needed.
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
    _isMaintenance = false;
    _isRegenerating = false;
    _isInitializingCourses = true;
    notifyListeners();
    debugPrint('🧹 MiniCourseProvider state cleared');
  }

  /// Clear in-memory attempted quiz state (server remains source of truth).
  Future<void> clearAttemptedQuizzesCache() async {
    _attemptedQuizCourseIds.clear();
    debugPrint('🧹 Attempted quizzes memory cleared');
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
