import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'mini_course_quiz_screen.dart';

class MiniCourseLessonScreen extends StatelessWidget {
  final String courseId;
  final int lessonIndex;

  const MiniCourseLessonScreen({
    super.key,
    required this.courseId,
    required this.lessonIndex,
  });

  @override
  Widget build(BuildContext context) {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final course = miniCourseProvider.getCourseById(courseId);

    if (course == null || lessonIndex >= course.lessons.length) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lesson Not Found'),
        ),
        body: const Center(
          child: Text('The requested lesson could not be found.'),
        ),
      );
    }

    final lesson = course.lessons[lessonIndex];
    final isLastLesson = lessonIndex == course.lessons.length - 1;
    final attempted = miniCourseProvider.hasAttemptedQuiz(courseId);
    
    // Extract the topic from the title
    final topic = course.title.replaceAll('Mini-Course: ', '');

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Lesson ${lessonIndex + 1}'),
        backgroundColor: courseColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Lesson progress indicator
          LinearProgressIndicator(
            value: (lessonIndex + 1) / (course.lessons.length + 1), // +1 for quiz
            backgroundColor: Colors.grey.shade200,
            color: courseColor,
            minHeight: 8,
          ),
          
          // Lesson content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lesson title
                  Text(
                    lesson.title,
                    style: AppTextStyles.heading1,
                  ).animate().fadeIn(duration: 500.ms),
                  
                  const SizedBox(height: 8),
                  
                  // Course topic
                  Text(
                    topic,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: courseColor,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Lesson content
                  Text(
                    lesson.content,
                    style: AppTextStyles.body.copyWith(
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  
                  const SizedBox(height: 40),
                  
                  // Key takeaways
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: courseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: courseColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: courseColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Key Takeaways',
                              style: AppTextStyles.heading3.copyWith(
                                color: courseColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...lesson.keyTakeaways.map((takeaway) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: courseColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  takeaway,
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  
                  const SizedBox(height: 40),
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
                // Back button (if not first lesson)
                if (lessonIndex > 0)
                  QuestButton(
                    text: 'Previous',
                    type: QuestButtonType.outline,
                    icon: Icons.arrow_back,
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MiniCourseLessonScreen(
                            courseId: courseId,
                            lessonIndex: lessonIndex - 1,
                          ),
                        ),
                      );
                    },
                  )
                else
                  const SizedBox(width: 100),
                
                // Lesson number indicator
                Text(
                  '${lessonIndex + 1}/${course.lessons.length}',
                  style: AppTextStyles.bodyBold,
                ),
                
                // Next button
                QuestButton(
                  text: isLastLesson 
                      ? ((course.quiz.isCompleted || attempted) ? 'Completed ✓' : 'Quiz') 
                      : 'Next',
                  type: (isLastLesson && (course.quiz.isCompleted || attempted)) 
                      ? QuestButtonType.secondary 
                      : QuestButtonType.primary,
                  icon: isLastLesson ? Icons.quiz : Icons.arrow_forward,
                  onPressed: (isLastLesson && (course.quiz.isCompleted || attempted))
                      ? null // Disable when already attempted/completed
                      : () {
                          // Double-check quiz completion/attempted status before allowing navigation
                          final currentCourse = miniCourseProvider.getCourseById(courseId);
                          if (currentCourse == null) return;

                          if (isLastLesson && (currentCourse.quiz.isCompleted || miniCourseProvider.hasAttemptedQuiz(courseId))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Quiz already completed! You cannot retake it.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return; // Exit early, don't navigate
                          }

                          // Mark the current lesson as completed
                          miniCourseProvider.completeLesson(courseId);

                          if (isLastLesson) {
                            // Navigate to quiz only if not completed/attempted
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MiniCourseQuizScreen(
                                  courseId: courseId,
                                ),
                              ),
                            );
                          } else {
                            // Navigate to next lesson
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MiniCourseLessonScreen(
                                  courseId: courseId,
                                  lessonIndex: lessonIndex + 1,
                                ),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


