import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/school_course_model.dart';
import '../../providers/school_course_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

/// Screen for viewing and completing a school course
class SchoolCourseViewerScreen extends StatefulWidget {
  final String courseId;

  const SchoolCourseViewerScreen({super.key, required this.courseId});

  @override
  State<SchoolCourseViewerScreen> createState() => _SchoolCourseViewerScreenState();
}

class _SchoolCourseViewerScreenState extends State<SchoolCourseViewerScreen> {
  SchoolCourse? _course;
  bool _isLoading = true;
  int _currentStep = 0; // 0 = content, 1+ = quiz questions
  bool _showingQuiz = false;
  int _quizScore = 0;
  List<int?> _selectedAnswers = [];
  bool _quizCompleted = false;
  DateTime? _startTime;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<SchoolCourseProvider>();
      final course = await provider.getCourseById(widget.courseId);

      if (course != null) {
        // Start the course
        await provider.startCourse(course.id);
        _startTime = DateTime.now();
        _stopwatch.start();

        setState(() {
          _course = course;
          _selectedAnswers = List.filled(course.quizQuestions.length, null);
        });
      }
    } catch (e) {
      debugPrint('Error loading course: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_course == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Course Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Course not found or unavailable'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_course!.title),
        actions: [
          if (_course!.school?.logoUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(_course!.school!.logoUrl!),
              ),
            ),
        ],
      ),
      body: _quizCompleted ? _buildCompletionView() : _buildCourseContent(),
      bottomNavigationBar: _quizCompleted ? null : _buildBottomBar(),
    );
  }

  Widget _buildCourseContent() {
    if (_showingQuiz) {
      return _buildQuizView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course header
          _buildCourseHeader(),
          const SizedBox(height: 24),

          // Content blocks
          ..._course!.content.map((block) => _buildContentBlock(block)),

          const SizedBox(height: 32),

          // Start quiz button
          if (_course!.quizQuestions.isNotEmpty)
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _showingQuiz = true);
                },
                icon: const Icon(Icons.quiz),
                label: const Text('Take Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            )
          else
            Center(
              child: ElevatedButton.icon(
                onPressed: _completeCourse,
                icon: const Icon(Icons.check),
                label: const Text('Complete Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCourseHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (_course!.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _course!.thumbnailUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.school, size: 64, color: AppColors.primary),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Title and topic
          Text(
            _course!.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _course!.topic,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Meta info
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaChip(Icons.timer, '${_course!.estimatedDuration} min'),
              _buildMetaChip(Icons.monetization_on, '${_course!.coinReward} coins'),
              _buildMetaChip(Icons.signal_cellular_alt, _course!.difficultyDisplay),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            _course!.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),

          // Creator info
          if (_course!.creator != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _course!.creator!.avatarUrl != null
                      ? NetworkImage(_course!.creator!.avatarUrl!)
                      : null,
                  child: _course!.creator!.avatarUrl == null
                      ? Text(_course!.creator!.name[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'By ${_course!.creator!.name}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildContentBlock(CourseContentBlock block) {
    switch (block.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Text(
            block.content,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case 'text':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            block.content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        );

      case 'bullet_list':
        final items = block.content.split('\n').where((s) => s.trim().isNotEmpty);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 12),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.trim(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      case 'image':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              block.content,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 150,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(block.content),
        );
    }
  }

  // =====================================================
  // QUIZ VIEW
  // =====================================================

  Widget _buildQuizView() {
    if (_currentStep >= _course!.quizQuestions.length) {
      return _buildQuizResults();
    }

    final question = _course!.quizQuestions[_currentStep];
    final selectedAnswer = _selectedAnswers[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _course!.quizQuestions.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Question ${_currentStep + 1} of ${_course!.quizQuestions.length}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Question
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.getNeumorphicDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // Options
                ...question.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = selectedAnswer == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAnswers[_currentStep] = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[400]!,
                              ),
                            ),
                            child: Center(
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : Text(
                                      String.fromCharCode(65 + index),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 15,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizResults() {
    // Calculate score
    int correctCount = 0;
    for (int i = 0; i < _course!.quizQuestions.length; i++) {
      if (_selectedAnswers[i] == _course!.quizQuestions[i].correctIndex) {
        correctCount++;
      }
    }

    final percentage = (correctCount / _course!.quizQuestions.length * 100).round();
    final passed = percentage >= 70;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AppTheme.getNeumorphicDecoration(),
            child: Column(
              children: [
                Icon(
                  passed ? Icons.emoji_events : Icons.refresh,
                  size: 64,
                  color: passed ? Colors.amber : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  passed ? 'Great Job!' : 'Keep Trying!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You scored $correctCount out of ${_course!.quizQuestions.length}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Review answers
          const Text(
            'Review Answers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...List.generate(_course!.quizQuestions.length, (index) {
            final question = _course!.quizQuestions[index];
            final selected = _selectedAnswers[index];
            final isCorrect = selected == question.correctIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Q${index + 1}: ${question.question}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isCorrect) ...[
                    Text(
                      'Your answer: ${selected != null ? question.options[selected] : "Not answered"}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  Text(
                    'Correct answer: ${question.options[question.correctIndex]}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  if (question.explanation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      question.explanation!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              if (!passed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentStep = 0;
                        _selectedAnswers =
                            List.filled(_course!.quizQuestions.length, null);
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Quiz'),
                  ),
                ),
              if (!passed) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _quizScore = percentage;
                    _completeCourse();
                  },
                  icon: const Icon(Icons.check),
                  label: Text(passed ? 'Complete Course' : 'Finish Anyway'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: passed ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // =====================================================
  // COMPLETION VIEW
  // =====================================================

  Widget _buildCompletionView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Celebration animation
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Course Completed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _course!.title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Rewards earned
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.getNeumorphicDecoration(),
              child: Column(
                children: [
                  const Text(
                    'Rewards Earned',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRewardItem(
                        Icons.monetization_on,
                        '+${_course!.coinReward.toInt()}',
                        'Coins',
                        Colors.orange,
                      ),
                    ],
                  ),
                  if (_quizScore > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Quiz Score: $_quizScore%',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Rate course
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getNeumorphicDecoration(),
              child: Column(
                children: [
                  const Text(
                    'How was this course?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          Icons.star,
                          color: Colors.grey[300],
                          size: 32,
                        ),
                        onPressed: () async {
                          final provider = context.read<SchoolCourseProvider>();
                          await provider.rateCourse(_course!.id, index + 1);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thanks for your feedback!')),
                            );
                          }
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Back button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back to Courses'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // =====================================================
  // BOTTOM BAR
  // =====================================================

  Widget _buildBottomBar() {
    if (!_showingQuiz) return const SizedBox.shrink();

    final questionCount = _course?.quizQuestions.length ?? 0;
    if (questionCount == 0) return const SizedBox.shrink();

    // When showing results, _currentStep == questionCount. In that state we must not
    // index into _selectedAnswers, and the bottom bar should be hidden.
    if (_currentStep >= questionCount) return const SizedBox.shrink();

    final hasAnswer = _selectedAnswers.length > _currentStep && _selectedAnswers[_currentStep] != null;
    final isLastQuestion = _currentStep >= questionCount - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep--);
                  },
                  child: const Text('Previous'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: hasAnswer
                    ? () {
                        setState(() {
                          if (isLastQuestion) {
                            _currentStep = questionCount; // show results
                          } else {
                            _currentStep++;
                          }
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(isLastQuestion ? 'See Results' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  Future<void> _completeCourse() async {
    _stopwatch.stop();
    final timeSpent = _stopwatch.elapsed.inSeconds;

    try {
      final provider = context.read<SchoolCourseProvider>();
      final userProvider = context.read<UserProvider>();

      // Complete the course
      final progress = await provider.completeCourse(
        courseId: _course!.id,
        quizScore: _quizScore,
        timeSpentSeconds: timeSpent,
      );

      if (progress != null) {
        // Award coins only (no XP for school courses)
        if (!progress.coinsAwarded) {
          await userProvider.addCoins(_course!.coinReward);
        }
      }

      setState(() => _quizCompleted = true);
    } catch (e) {
      debugPrint('Error completing course: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing course: $e')),
        );
      }
    }
  }
}
