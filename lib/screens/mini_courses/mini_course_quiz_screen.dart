import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../utils/quiz_sound_effects.dart';
import '../../utils/course_visuals.dart';
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
  int _score = 0; 
  bool _isSubmitting = false; 
  bool _rewardsGranted = false;
  int _xpAwarded = 0;
  String? _submitReason;
  bool _alreadyCompleted = false;
  bool _alreadyAttempted = false;

  // Gamification Variables
  late ConfettiController _confettiController;
  Timer? _timer;
  int _timeLeft = 15; // 15 seconds per question
  bool _isAnswerRevealed = false;
  int? _revealedCorrectIndex;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    QuizSoundEffects.init();

    final miniCourseProvider = Provider.of<MiniCourseProvider>(context, listen: false);
    final course = miniCourseProvider.getCourseById(widget.courseId);
    if (course != null) {
      _selectedAnswers = List.filled(course.quiz.questions.length, -1);
      
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
        _quizCompleted = true; 
      } else {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = 15;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          // Time ran out! Mark wrong and move next
          _handleTimeOut();
        }
      });
    });
  }

  void _showExitBlockedMessage() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quiz in progress'),
        content: const Text(
          'Please finish all questions before leaving. Your progress will not be saved if you exit early.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue quiz'),
          ),
        ],
      ),
    );
  }

  void _handleTimeOut() {
    _timer?.cancel();
    setState(() {
      _isAnswerRevealed = true;
      final course = Provider.of<MiniCourseProvider>(context, listen: false).getCourseById(widget.courseId);
      _revealedCorrectIndex = course?.quiz.questions[_currentQuestionIndex].correctAnswerIndex;
    });
    QuizSoundEffects.playWrong();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _moveToNextQuestion();
    });
  }

  void _handleOptionSelected(int index) {
    if (_isAnswerRevealed) return;
    
    _timer?.cancel();
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = index;
      _isAnswerRevealed = true;
    });

    final course = Provider.of<MiniCourseProvider>(context, listen: false).getCourseById(widget.courseId);
    final question = course!.quiz.questions[_currentQuestionIndex];
    _revealedCorrectIndex = question.correctAnswerIndex;

    if (index == question.correctAnswerIndex) {
      QuizSoundEffects.playCorrect();
    } else {
      QuizSoundEffects.playWrong();
    }

    // Wait a moment then move to next
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _moveToNextQuestion();
    });
  }

  Future<void> _moveToNextQuestion() async {
    final course = Provider.of<MiniCourseProvider>(context, listen: false).getCourseById(widget.courseId);
    if (course == null) return;
    final questions = course.quiz.questions;

    if (_currentQuestionIndex == questions.length - 1) {
      await _submitQuiz();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _isAnswerRevealed = false;
        _revealedCorrectIndex = null;
      });
      _startTimer();
    }
  }

  Future<void> _submitQuiz() async {
    final miniCourseProvider =
        Provider.of<MiniCourseProvider>(context, listen: false);
    final course = miniCourseProvider.getCourseById(widget.courseId);
    if (course == null) return;

    if (course.quiz.isCompleted ||
        miniCourseProvider.hasAttemptedQuiz(widget.courseId) ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    final questions = course.quiz.questions;
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers[i] == questions[i].correctAnswerIndex) correct++;
    }

    // Parse date + index from course id (yyyy-MM-dd_course_{index}).
    // Never default to index 0 — that collides with another course's progress.
    String courseDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int? courseIndex;
    final id = widget.courseId;
    if (id.contains('_course_')) {
      final parts = id.split('_course_');
      if (parts.length == 2) {
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parts.first)) {
          courseDate = parts.first;
        }
        courseIndex = int.tryParse(parts.last);
      }
    }
    if (courseIndex == null) {
      try {
        final today = miniCourseProvider.todayCourses;
        final idx = today.indexWhere((c) => c.id == widget.courseId);
        if (idx >= 0) courseIndex = idx;
      } catch (_) {}
    }
    if (courseIndex == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not identify this course. Please reopen it from Today\'s courses.'),
          ),
        );
      }
      return;
    }

    final percentScore = ((correct / questions.length) * 100).round();
    bool rewardsGranted = false;
    int xpAwarded = 0;
    String? submitReason;
    bool alreadyCompleted = false;
    bool alreadyAttempted = false;
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user?.id != null) {
        final result = await miniCourseProvider.submitQuizForCourse(
          course: course,
          userId: user!.id,
          courseIndex: courseIndex,
          courseDate: courseDate,
          uiContext: context,
          overrideScore: percentScore,
        );
        rewardsGranted = result['rewards_granted'] == true ||
            ((result['xp_awarded'] as num?) ?? 0) > 0 ||
            ((result['coins_awarded'] as num?) ?? 0) > 0;
        submitReason = result['reason']?.toString();
        alreadyCompleted = result['already_completed'] == true;
        alreadyAttempted = result['already_attempted'] == true;
        xpAwarded = ((result['xp_awarded'] as num?) ?? 0).toInt();
        if (rewardsGranted) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          await userProvider.reinitializeUser();
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _quizCompleted = true;
        _score = correct;
        _isSubmitting = false;
        _rewardsGranted = rewardsGranted;
        _xpAwarded = xpAwarded;
        _submitReason = submitReason;
        _alreadyCompleted = alreadyCompleted;
        _alreadyAttempted = alreadyAttempted;
      });

      if (percentScore >= 70) {
        QuizSoundEffects.playWin();
        _confettiController.play();
      }
    }
  }

  void _retryQuiz() {
    final course = Provider.of<MiniCourseProvider>(context, listen: false)
        .getCourseById(widget.courseId);
    if (course == null) return;
    _timer?.cancel();
    setState(() {
      _quizCompleted = false;
      _score = 0;
      _currentQuestionIndex = 0;
      _selectedAnswers = List.filled(course.quiz.questions.length, -1);
      _isAnswerRevealed = false;
      _revealedCorrectIndex = null;
      _isSubmitting = false;
      _rewardsGranted = false;
      _xpAwarded = 0;
      _submitReason = null;
      _alreadyCompleted = false;
      _alreadyAttempted = false;
    });
    _startTimer();
  }

  Color getCourseColor(String title) => MlqCourseVisuals.colorFor(title);

  @override
  Widget build(BuildContext context) {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final course = miniCourseProvider.getCourseById(widget.courseId);

    if (course == null) {
      return Scaffold(appBar: AppBar(title: const Text('Quiz Not Found')));
    }

    final quiz = course.quiz;
    final questions = quiz.questions;
    final courseColor = getCourseColor(course.title);
    final topic = course.title.replaceAll('Mini-Course: ', '');

    if (_quizCompleted) {
      return _buildResultsScreen(questions.length, topic, courseColor);
    }

    if (_isSubmitting) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: courseColor),
                const SizedBox(height: 16),
                const Text('Evaluating results...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final question = questions[_currentQuestionIndex];
    final options = question.options;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitBlockedMessage();
      },
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Quiz: $topic'),
        backgroundColor: courseColor,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _timeLeft / 15,
                    color: _timeLeft < 5 ? Colors.red : Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                  Text(
                    '$_timeLeft',
                    style: TextStyle(
                      color: _timeLeft < 5 ? Colors.red : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            backgroundColor: Colors.grey.shade200,
            color: courseColor,
            minHeight: 8,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                    style: AppTextStyles.bodyBold.copyWith(color: courseColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.text,
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 32),
                  
                  ...List.generate(options.length, (index) {
                    // Gamified Option Cards
                    Color cardColor = Colors.white;
                    Color borderColor = Colors.grey.shade300;
                    Widget? trailingIcon;
                    
                    if (_isAnswerRevealed) {
                      if (index == _revealedCorrectIndex) {
                        cardColor = Colors.green.shade100;
                        borderColor = Colors.green;
                        trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
                      } else if (index == _selectedAnswers[_currentQuestionIndex]) {
                        cardColor = Colors.red.shade100;
                        borderColor = Colors.red;
                        trailingIcon = const Icon(Icons.cancel, color: Colors.red);
                      }
                    } else {
                      if (_selectedAnswers[_currentQuestionIndex] == index) {
                        cardColor = courseColor.withOpacity(0.1);
                        borderColor = courseColor;
                      }
                    }

                    Widget optionCard = GestureDetector(
                      onTap: () => _handleOptionSelected(index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 2),
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
                                color: borderColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index), 
                                  style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                options[index],
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (trailingIcon != null) trailingIcon,
                          ],
                        ),
                      ),
                    );

                    // Add shake animation for wrong selected answer
                    if (_isAnswerRevealed && index == _selectedAnswers[_currentQuestionIndex] && index != _revealedCorrectIndex) {
                      optionCard = optionCard.animate().shakeX();
                    }
                    
                    return optionCard;
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildResultsScreen(int totalQuestions, String topic, Color courseColor) {
    final percentage = (_score / totalQuestions) * 100;
    final isPassed = percentage >= 70; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: isPassed ? Colors.green : courseColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                      : 'You need 70% to complete this course. You can try again now.',
                  style: AppTextStyles.bodyBold,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                
                const SizedBox(height: 40),
                
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
                            '/$totalQuestions',
                            style: AppTextStyles.heading2.copyWith(color: AppColors.textSecondary),
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
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                
                const SizedBox(height: 24),
                
                if (isPassed && _rewardsGranted)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.green, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _xpAwarded > 0
                                        ? 'You earned $_xpAwarded XP!'
                                        : 'Quiz complete!',
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _xpAwarded >= 20
                                        ? 'Perfect score — maximum quiz XP!'
                                        : _xpAwarded >= 15
                                            ? 'Great score — keep pushing for 100% next time.'
                                            : 'Pass XP unlocked. Score higher for more XP (up to 20).',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('You earned 5 coins!', style: AppTextStyles.bodyBold),
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
                      ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                    ],
                  )
                else if (isPassed && !_rewardsGranted)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.grey, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _alreadyCompleted
                                    ? 'Rewards Already Earned'
                                    : 'Rewards Not Applied',
                                style: AppTextStyles.bodyBold,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _alreadyCompleted
                                    ? 'You already earned XP and coins for this quiz today.'
                                    : (_submitReason == 'already_awarded'
                                        ? 'This quiz was already rewarded earlier today.'
                                        : 'Your pass was saved. If XP did not update, reopen the course and try again.'),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                
                const SizedBox(height: 40),

                if (!isPassed) ...[
                  QuestButton(
                    text: 'Try again',
                    type: QuestButtonType.primary,
                    onPressed: _retryQuiz,
                  ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
                  const SizedBox(height: 16),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QuestButton(
                      text: 'Review Lessons',
                      type: QuestButtonType.outline,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    QuestButton(
                      text: 'Home',
                      type: QuestButtonType.primary,
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
              ],
            ),
          ),
          
          if (isPassed)
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.tertiary,
                AppColors.academic,
                AppColors.accent1,
                AppColors.accent2,
                AppColors.primary,
              ],
            ),
        ],
      ),
    );
  }
}
