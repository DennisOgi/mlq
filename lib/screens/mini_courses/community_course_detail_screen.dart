import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/mini_course_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/community_course_service.dart';
import '../../widgets/widgets.dart';

/// Detail screen for viewing and completing a community mini course
class CommunityCourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CommunityCourseDetailScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<CommunityCourseDetailScreen> createState() =>
      _CommunityCourseDetailScreenState();
}

class _CommunityCourseDetailScreenState
    extends State<CommunityCourseDetailScreen> {
  int _currentContentIndex = 0;
  bool _showQuiz = false;
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  bool _quizSubmitted = false;
  int _quizScore = 0;
  bool _isSubmitting = false;

  CommunityMiniCourse? get _course {
    final provider = Provider.of<MiniCourseProvider>(context, listen: false);
    return provider.getCommunityCourseById(widget.courseId);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final course = _course;
      if (course != null && course.quizQuestions.isNotEmpty) {
        _selectedAnswers = List.filled(course.quizQuestions.length, null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MiniCourseProvider>(
      builder: (context, provider, _) {
        final course = provider.getCommunityCourseById(widget.courseId);

        if (course == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Course Not Found'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('This course is no longer available.'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(course),
          body: _showQuiz
              ? _buildQuizView(course)
              : _buildContentView(course),
          bottomNavigationBar: _buildBottomBar(course),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(CommunityMiniCourse course) {
    return AppBar(
      backgroundColor: const Color(0xFFFF6B00),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            style: AppTextStyles.heading3.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  course.communityName,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (!_showQuiz && course.hasQuiz && !course.isCompleted)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showQuiz = true;
                _currentQuestionIndex = 0;
              });
            },
            icon: const Icon(Icons.quiz_rounded, color: Colors.white),
            label: Text(
              'Take Quiz',
              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildContentView(CommunityMiniCourse course) {
    final content = course.content;
    
    if (content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No content available yet',
                style: AppTextStyles.heading3.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The community owner hasn\'t added content to this course yet.',
                style: AppTextStyles.body.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: (_currentContentIndex + 1) / content.length,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
        ),
        
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary if available
                if (course.summary != null && _currentContentIndex == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6B00).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFFF6B00),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            course.summary!,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                ],
                
                // Current content item
                _buildContentItem(content[_currentContentIndex]),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentItem(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'text';
    final content = item['content'] as String? ?? '';

    switch (type) {
      case 'bullet':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, right: 12),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                content,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);

      case 'tip':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates, color: Colors.amber[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  content,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    color: Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));

      case 'heading':
        return Text(
          content,
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.primary,
          ),
        ).animate().fadeIn(duration: 400.ms);

      default: // text
        return Text(
          content,
          style: AppTextStyles.body.copyWith(
            fontSize: 16,
            height: 1.7,
          ),
        ).animate().fadeIn(duration: 400.ms);
    }
  }

  Widget _buildQuizView(CommunityMiniCourse course) {
    if (_quizSubmitted) {
      return _buildQuizResults(course);
    }

    final questions = course.quizQuestions;
    if (questions.isEmpty) {
      return const Center(child: Text('No quiz questions available.'));
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final options = List<String>.from(currentQuestion['options'] ?? []);

    final bool isLastQuestion = _currentQuestionIndex >= questions.length - 1;
    final bool canGoNext = _selectedAnswers[_currentQuestionIndex] != null;
    final bool canSubmit = _selectedAnswers.every((a) => a != null);

    return Column(
      children: [
        // Progress
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / questions.length,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question number
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFFF6B00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Question text
                Text(
                  currentQuestion['question'] as String? ?? '',
                  style: AppTextStyles.heading3.copyWith(
                    fontSize: 18,
                  ),
                ).animate().fadeIn(duration: 300.ms),
                
                const SizedBox(height: 24),
                
                // Options
                ...options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentQuestionIndex] = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF6B00).withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF6B00)
                                : Colors.grey[300]!,
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
                                    ? const Color(0xFFFF6B00)
                                    : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index), // A, B, C, D
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizResults(CommunityMiniCourse course) {
    final passed = _quizScore >= 70;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // Result icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: passed
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              size: 64,
              color: passed ? Colors.green : Colors.orange,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          
          const SizedBox(height: 24),
          
          Text(
            passed ? 'Great Job!' : 'Keep Learning!',
            style: AppTextStyles.heading1.copyWith(
              color: passed ? Colors.green : Colors.orange,
            ),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 8),
          
          Text(
            'You scored $_quizScore%',
            style: AppTextStyles.heading2,
          ).animate().fadeIn(delay: 300.ms),
          
          const SizedBox(height: 16),
          
          if (passed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Course Completed!',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ] else ...[
            Text(
              'You need 70% to pass. Review the content and try again!',
              style: AppTextStyles.body.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
          ],
          
          const SizedBox(height: 32),
          
          QuestButton(
            text: 'Back to Home',
            icon: Icons.home,
            type: QuestButtonType.primary,
            isFullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ).animate().fadeIn(delay: 500.ms),
          
          if (!passed) ...[
            const SizedBox(height: 12),
            QuestButton(
              text: 'Review Content',
              icon: Icons.menu_book,
              type: QuestButtonType.secondary,
              isFullWidth: true,
              onPressed: () {
                setState(() {
                  _showQuiz = false;
                  _quizSubmitted = false;
                  _currentContentIndex = 0;
                });
              },
            ).animate().fadeIn(delay: 600.ms),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(CommunityMiniCourse course) {
    // Hide bottom bar when showing final results
    if (_showQuiz && _quizSubmitted) {
      return const SizedBox.shrink();
    }

    if (_showQuiz) {
      final questions = course.quizQuestions;
      if (questions.isEmpty) {
        return const SizedBox.shrink();
      }

      final bool isLastQuestion = _currentQuestionIndex >= questions.length - 1;
      final bool canGoNext = _selectedAnswers.isNotEmpty &&
          _currentQuestionIndex < _selectedAnswers.length &&
          _selectedAnswers[_currentQuestionIndex] != null;
      final bool canSubmit = _selectedAnswers.every((a) => a != null);

      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: QuestButton(
                    text: 'Previous',
                    icon: Icons.arrow_back,
                    type: QuestButtonType.secondary,
                    isFullWidth: true,
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 12),

              Expanded(
                child: QuestButton(
                  text: isLastQuestion
                      ? (_isSubmitting ? 'Submitting...' : 'Submit Quiz')
                      : 'Next',
                  icon: isLastQuestion ? Icons.check_circle : Icons.arrow_forward,
                  type: QuestButtonType.primary,
                  isFullWidth: true,
                  isLoading: isLastQuestion && _isSubmitting,
                  onPressed: (!isLastQuestion && !canGoNext) || (isLastQuestion && !canSubmit)
                      ? null
                      : () {
                          if (!isLastQuestion) {
                            setState(() {
                              _currentQuestionIndex++;
                            });
                          } else {
                            _submitQuiz(course);
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Content navigation
    final content = course.content;
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentContentIndex > 0)
              Expanded(
                child: QuestButton(
                  text: 'Previous',
                  icon: Icons.arrow_back,
                  type: QuestButtonType.secondary,
                  isFullWidth: true,
                  onPressed: () {
                    setState(() {
                      _currentContentIndex--;
                    });
                  },
                ),
              )
            else
              const Spacer(),

            const SizedBox(width: 12),

            Expanded(
              child: QuestButton(
                text: _currentContentIndex < content.length - 1
                    ? 'Next'
                    : (course.hasQuiz && !course.isCompleted
                        ? 'Take Quiz'
                        : (course.isCompleted ? 'Completed!' : 'Finish')),
                icon: _currentContentIndex < content.length - 1
                    ? Icons.arrow_forward
                    : (course.hasQuiz && !course.isCompleted
                        ? Icons.quiz_rounded
                        : Icons.check_circle),
                type: QuestButtonType.primary,
                isFullWidth: true,
                onPressed: course.isCompleted && _currentContentIndex >= content.length - 1
                    ? null
                    : () {
                        if (_currentContentIndex < content.length - 1) {
                          setState(() {
                            _currentContentIndex++;
                          });
                        } else if (course.hasQuiz && !course.isCompleted) {
                          setState(() {
                            _showQuiz = true;
                            _currentQuestionIndex = 0;
                          });
                        } else if (!course.isCompleted) {
                          _completeCourseWithoutQuiz(course);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz(CommunityMiniCourse course) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Calculate score
      int correct = 0;
      for (int i = 0; i < course.quizQuestions.length; i++) {
        final question = course.quizQuestions[i];
        final correctIndex = question['correct_index'] as int? ?? 0;
        if (_selectedAnswers[i] == correctIndex) {
          correct++;
        }
      }
      
      final score = ((correct / course.quizQuestions.length) * 100).round();
      
      // Submit to server
      final provider = Provider.of<MiniCourseProvider>(context, listen: false);
      await provider.submitCommunityCourseQuiz(
        course: course,
        score: score,
      );

      // Refresh user data if passed
      if (score >= 70) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.reinitializeUser();
      }

      setState(() {
        _quizScore = score;
        _quizSubmitted = true;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit quiz: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeCourseWithoutQuiz(CommunityMiniCourse course) async {
    try {
      final provider = Provider.of<MiniCourseProvider>(context, listen: false);
      await provider.submitCommunityCourseQuiz(
        course: course,
        score: 100, // Full score for courses without quiz
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Course completed!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete course: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
