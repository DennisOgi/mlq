import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../main.dart';
import '../../services/badge_service.dart';
import '../../services/badge_notification_service.dart';
import '../../services/challenge_evaluator.dart';

class MiniCourseQuizScreen extends StatefulWidget {
  final String courseId;

  const MiniCourseQuizScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<MiniCourseQuizScreen> createState() => _MiniCourseQuizScreenState();
}

class _MiniCourseQuizScreenState extends State<MiniCourseQuizScreen> {
  int _currentQuestionIndex = 0;
  List<int> _selectedAnswers = [];
  bool _quizCompleted = false;
  int _score = 0; // number of correct answers for display
  bool _isSubmitting = false; // Track submission state

  // Track if rewards were granted by server
  bool _rewardsGranted = false;

  // Handle next/submit button press
  Future<void> _handleNextButtonPress() async {
    final course = Provider.of<MiniCourseProvider>(context, listen: false).getCourseById(widget.courseId);
    if (course == null) return;
    
    // PREVENT DUPLICATE SUBMISSION: Block if quiz already completed or currently submitting
    if (course.quiz.isCompleted || _isSubmitting) {
      debugPrint('[QuizScreen] ⚠️ Attempted to submit already completed quiz or already submitting - blocked');
      return;
    }
    
    final questions = course.quiz.questions;
    
    if (_currentQuestionIndex == questions.length - 1) {
      // Set submitting state to show loading indicator
      setState(() {
        _isSubmitting = true;
      });
      // Calculate correct count locally for display
      int correct = 0;
      for (int i = 0; i < questions.length; i++) {
        if (_selectedAnswers[i] == questions[i].correctAnswerIndex) correct++;
      }

      // Persist submission via provider using global deterministic marker
      final miniCourseProvider = Provider.of<MiniCourseProvider>(context, listen: false);
      debugPrint('[QuizScreen] 🎯 About to submit quiz answers for course: ${widget.courseId}');
      debugPrint('[QuizScreen] Selected answers: $_selectedAnswers');
      // Derive courseIndex from today's trio if available; fallback to 0
      int courseIndex = 0;
      try {
        final today = miniCourseProvider.todayCourses;
        final idx = today.indexWhere((c) => c.id == widget.courseId);
        if (idx >= 0) courseIndex = idx;
      } catch (_) {}
      // Compute percentage from local correct count
      final percentScore = ((correct / questions.length) * 100).round();
      
      bool rewardsGranted = false;
      try {
        final user = Provider.of<UserProvider>(context, listen: false).user;
        if (user?.id != null) {
          debugPrint('[QuizScreen] 💾 Submitting quiz for course index $courseIndex, user ${user?.id}');
          // Server handles rewards atomically - no client-side reward awarding
          final result = await miniCourseProvider.submitQuizForCourse(
            course: course,
            userId: user!.id,
            courseIndex: courseIndex,
            uiContext: context,
            overrideScore: percentScore,
          );
          debugPrint('[QuizScreen] ✅ Quiz submission completed: $result');
          
          // Check if server granted rewards (first-time completion)
          rewardsGranted = result['rewards_granted'] == true;
          
          // Refresh user data to get updated coin/XP balances from server
          if (rewardsGranted) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.reinitializeUser();
            debugPrint('[QuizScreen] 🎯 Rewards granted by server - refreshed user data');
          } else if (result['already_completed'] == true) {
            debugPrint('[QuizScreen] ⚠️ Quiz already completed - no rewards granted');
          }
        } else {
          debugPrint('[QuizScreen] ❌ Cannot submit quiz - user is null');
        }
      } catch (e) {
        debugPrint('[QuizScreen] ❌ ERROR submitting quiz: $e');
      }
      
      final isPassed = percentScore >= 70;
      debugPrint('[QuizScreen] 📊 Quiz submitted, score: $percentScore%, passed: $isPassed, rewards: $rewardsGranted');
      
      // Mark quiz as completed and show results
      if (mounted) {
        setState(() {
          _quizCompleted = true;
          _score = correct;
          _isSubmitting = false;
          _rewardsGranted = rewardsGranted;
        });
      }
    } else {
      // Move to next question
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize selected answers list with -1 (no selection)
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context, listen: false);
    final course = miniCourseProvider.getCourseById(widget.courseId);
    if (course != null) {
      _selectedAnswers = List.filled(course.quiz.questions.length, -1);
      // PREVENT DUPLICATE ATTEMPTS: If quiz already completed or attempted, show results immediately
      if (course.quiz.isCompleted || miniCourseProvider.hasAttemptedQuiz(widget.courseId)) {
        final questions = course.quiz.questions;
        for (int i = 0; i < questions.length; i++) {
          _selectedAnswers[i] = questions[i].selectedOptionIndex ?? -1;
        }
        int correct = 0;
        for (int i = 0; i < questions.length; i++) {
          if (_selectedAnswers[i] == questions[i].correctAnswerIndex) correct++;
        }
        _score = correct;
        _quizCompleted = true; // BLOCK retaking quiz
        debugPrint('[QuizScreen] ⚠️ Quiz already attempted/completed - showing results only');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final course = miniCourseProvider.getCourseById(widget.courseId);

    if (course == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Not Found'),
        ),
        body: const Center(
          child: Text('The requested quiz could not be found.'),
        ),
      );
    }

    final quiz = course.quiz;
    final questions = quiz.questions;
    
    // Get the color based on the course topic
    Color getCourseColor(String title) {
      if (title.contains('Goal Setting')) return AppColors.primary;
      if (title.contains('Leadership')) return AppColors.secondary;
      if (title.contains('Teamwork')) return AppColors.tertiary;
      if (title.contains('Communication')) return AppColors.accent1;
      if (title.contains('Problem Solving')) return AppColors.accent2;
      if (title.contains('Time Management')) return AppColors.social;
      if (title.contains('Public Speaking')) return AppColors.health;
      if (title.contains('Conflict Resolution')) return Color(0xFF9C27B0);
      if (title.contains('Critical Thinking')) return Color(0xFF3F51B5);
      if (title.contains('Emotional Intelligence')) return Color(0xFFE91E63);
      if (title.contains('Decision Making')) return Color(0xFF009688);
      if (title.contains('Creativity')) return Color(0xFFFF5722);
      return AppColors.primary;
    }

    final courseColor = getCourseColor(course.title);
    final topic = course.title.replaceAll('Mini-Course: ', '');

    // Quiz results screen
    if (_quizCompleted) {
      final percentage = (_score / questions.length) * 100;
      final isPassed = percentage >= 70; // 70% passing threshold
      
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
          backgroundColor: isPassed ? Colors.green : courseColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Results header
              Icon(
                isPassed ? Icons.emoji_events : Icons.school,
                size: 80,
                color: isPassed ? Colors.amber : courseColor,
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              
              const SizedBox(height: 24),
              
              Text(
                isPassed ? 'Congratulations!' : 'Good Effort!',
                style: AppTextStyles.heading1.copyWith(
                  color: isPassed ? Colors.green : courseColor,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms),
              
              const SizedBox(height: 16),
              
              Text(
                isPassed
                    ? 'You\'ve successfully completed the $topic quiz!'
                    : 'You\'ve completed the $topic quiz.',
                style: AppTextStyles.bodyBold,
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              
              const SizedBox(height: 40),
              
              // Score display
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_score',
                          style: AppTextStyles.heading1.copyWith(
                            color: isPassed ? Colors.green : courseColor,
                            fontSize: 48,
                          ),
                        ),
                        Text(
                          '/${questions.length}',
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: AppTextStyles.heading3.copyWith(
                        color: isPassed ? Colors.green : courseColor,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      isPassed ? 'Excellent work!' : 'Keep learning!',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              
              const SizedBox(height: 24),
              
              // Reward message - only show if rewards were actually granted by server
              if (isPassed && _rewardsGranted)
                Column(
                  children: [
                    // Coins reward
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amber,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You earned 5 coins!',
                                  style: AppTextStyles.bodyBold,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use coins to unlock avatars and rewards.',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                    
                    const SizedBox(height: 12),
                    
                    // XP reward
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.stars,
                            color: AppColors.primary,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You earned 20 XP!',
                                  style: AppTextStyles.bodyBold,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Earn XP to level up and climb the leaderboard.',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                  ],
                )
              else if (isPassed && !_rewardsGranted)
                // Already completed message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.grey,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiz Already Completed',
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You\'ve already earned rewards for this quiz.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              
              const SizedBox(height: 40),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QuestButton(
                    text: 'Review Lessons',
                    type: QuestButtonType.outline,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 16),
                  QuestButton(
                    text: 'Home',
                    type: QuestButtonType.primary,
                    onPressed: () {
                      // Navigate back to main navigation screen with tabs
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                        (route) => false, // Remove all previous routes
                      );
                    },
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
              
              const SizedBox(height: 16),
              
              // Note about quiz retake
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This quiz cannot be retaken, but you can review the lessons anytime.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
            ],
          ),
        ),
      );
    }

    // Current question
    final question = questions[_currentQuestionIndex];
    final options = question.options;
    final selectedAnswer = _selectedAnswers[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: $topic'),
        backgroundColor: courseColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Quiz progress indicator
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.grey.shade200,
            color: courseColor,
            minHeight: 8,
          ),
          
          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question counter
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: courseColor,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Question text
                  Text(
                    question.text,
                    style: AppTextStyles.heading2,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Answer options
                  ...List.generate(
                    options.length,
                    (index) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentQuestionIndex] = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedAnswer == index
                              ? courseColor.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedAnswer == index
                                ? courseColor
                                : Colors.grey.shade300,
                            width: selectedAnswer == index ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: selectedAnswer == index
                                    ? courseColor
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: selectedAnswer == index
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : Text(
                                        String.fromCharCode(65 + index), // A, B, C, D...
                                        style: AppTextStyles.bodyBold.copyWith(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                options[index],
                                style: AppTextStyles.body.copyWith(
                                  color: selectedAnswer == index
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: selectedAnswer == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button (if not first question)
                if (_currentQuestionIndex > 0)
                  QuestButton(
                    text: 'Previous',
                    type: QuestButtonType.outline,
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                  )
                else
                  const SizedBox(width: 100),
                
                // Question number indicator
                Text(
                  '${_currentQuestionIndex + 1}/${questions.length}',
                  style: AppTextStyles.bodyBold,
                ),
                
                // Next/Submit button
                QuestButton(
                  text: _currentQuestionIndex == questions.length - 1
                      ? (_isSubmitting ? 'Submitting...' : 'Submit')
                      : 'Next',
                  type: QuestButtonType.primary,
                  isLoading: _isSubmitting,
                  onPressed: (selectedAnswer == -1 || _isSubmitting)
                      ? null // Disable if no answer selected or submitting
                      : _handleNextButtonPress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
