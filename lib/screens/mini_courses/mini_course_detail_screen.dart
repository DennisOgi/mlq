import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'mini_course_lesson_screen.dart';
import 'mini_course_quiz_screen.dart';
import '../../services/global_daily_courses_service.dart';
import '../../providers/user_provider.dart';

class MiniCourseDetailScreen extends StatelessWidget {
  final String courseId;

  const MiniCourseDetailScreen({
    super.key,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Try to find by ID in courses list or todayCourses (global daily)
    MiniCourseModel? course = miniCourseProvider.getCourseById(courseId);
    
    // If not in courses list, check todayCourses (global daily trio)
    if (course == null) {
      try {
        course = miniCourseProvider.todayCourses.firstWhere((c) => c.id == courseId);
      } catch (_) {
        // Not found in todayCourses either
      }
    }

    if (course == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course Not Found'),
        ),
        body: const Center(
          child: Text('The requested course could not be found.'),
        ),
      );
    }

    // After null-check above, ensure a non-nullable reference
    final MiniCourseModel nonNullCourse = course;

    // Determine if this is a global daily course (id format: yyyy-MM-dd_course_{index})
    String? dateKey;
    int? dailyIndex;
    final id = nonNullCourse.id;
    if (id.contains('_course_')) {
      final parts = id.split('_course_');
      if (parts.length == 2) {
        dateKey = parts.first; // yyyy-MM-dd
        final idx = int.tryParse(parts.last);
        if (idx != null) dailyIndex = idx;
      }
    }

    Future<bool> checkLocked() async {
      // Lock only applies to global daily courses for the given day
      final uid = userProvider.user?.id;
      if (uid == null || dateKey == null || dailyIndex == null) return false;
      try {
        return await GlobalDailyCoursesService().isCompleted(
          userId: uid,
          courseDate: dateKey!,
          courseIndex: dailyIndex!,
        );
      } catch (_) {
        return false;
      }
    }

    // Extract the topic from the title
    final topic = nonNullCourse.title.replaceAll('Mini-Course: ', '');

    // Get the color and icon based on the course topic
    Color getCourseColor(String title) {
      if (title.contains('Goal Setting')) return AppColors.primary;
      if (title.contains('Leadership')) return AppColors.secondary;
      if (title.contains('Teamwork')) return AppColors.tertiary;
      if (title.contains('Communication')) return AppColors.accent1;
      if (title.contains('Problem Solving')) return AppColors.accent2;
      if (title.contains('Time Management')) return AppColors.social;
      if (title.contains('Public Speaking')) return AppColors.health;
      if (title.contains('Conflict Resolution')) return const Color(0xFF9C27B0);
      if (title.contains('Critical Thinking')) return const Color(0xFF3F51B5);
      if (title.contains('Emotional Intelligence')) return const Color(0xFFE91E63);
      if (title.contains('Decision Making')) return const Color(0xFF009688);
      if (title.contains('Creativity')) return const Color(0xFFFF5722);
      return AppColors.primary;
    }
    
    IconData getCourseIcon(String title) {
      if (title.contains('Goal Setting')) return Icons.flag;
      if (title.contains('Leadership')) return Icons.people;
      if (title.contains('Teamwork')) return Icons.group_work;
      if (title.contains('Communication')) return Icons.chat;
      if (title.contains('Problem Solving')) return Icons.lightbulb;
      if (title.contains('Time Management')) return Icons.schedule;
      if (title.contains('Public Speaking')) return Icons.record_voice_over;
      if (title.contains('Conflict Resolution')) return Icons.psychology;
      if (title.contains('Critical Thinking')) return Icons.psychology_alt;
      if (title.contains('Emotional Intelligence')) return Icons.favorite;
      if (title.contains('Decision Making')) return Icons.how_to_vote;
      if (title.contains('Creativity')) return Icons.brush;
      return Icons.school;
    }

    final courseColor = getCourseColor(nonNullCourse.title);
    final courseIcon = getCourseIcon(nonNullCourse.title);
    final attempted = miniCourseProvider.hasAttemptedQuiz(nonNullCourse.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(topic),
        backgroundColor: courseColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<bool>(
        future: checkLocked(),
        builder: (context, snapshot) {
          final isLockedToday = snapshot.data == true;
          return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: courseColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isLockedToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Completed today', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  // Show the course icon
                  Icon(
                    courseIcon,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    topic,
                    style: AppTextStyles.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nonNullCourse.description,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Course content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lessons section
                  Text(
                    'Lessons',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 12),
                  
                  // Lesson list
                  ...nonNullCourse.lessons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final lesson = entry.value;
                    final isCompleted = lesson.isCompleted;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.green : courseColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          lesson.title,
                          style: AppTextStyles.bodyBold,
                        ),
                        subtitle: Text(
                          isCompleted ? 'Completed' : 'Tap to start',
                          style: AppTextStyles.caption.copyWith(
                            color: isCompleted ? Colors.green : AppColors.textSecondary,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: courseColor,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MiniCourseLessonScreen(
                                courseId: nonNullCourse.id,
                                lessonIndex: index,
                              ),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * index));
                  }).toList(),

                  const SizedBox(height: 24),

                  // Quiz section
                  Text(
                    'Final Quiz',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 12),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: (nonNullCourse.quiz.isCompleted || attempted)
                              ? Colors.green 
                              : nonNullCourse.allLessonsCompleted
                                  ? (isLockedToday ? Colors.grey : courseColor)
                                  : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: (nonNullCourse.quiz.isCompleted || attempted)
                              ? const Icon(Icons.check, color: Colors.white, size: 30)
                              : const Icon(Icons.quiz, color: Colors.white, size: 30),
                        ),
                      ),
                      title: Text(
                        'Final Quiz',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: nonNullCourse.allLessonsCompleted
                              ? (isLockedToday ? Colors.grey : AppColors.textPrimary)
                              : AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        (nonNullCourse.quiz.isCompleted || attempted)
                            ? (isLockedToday ? 'Completed! Quiz cannot be retaken.' : 'Completed! Quiz cannot be retaken.')
                            : nonNullCourse.allLessonsCompleted
                                ? 'Test your knowledge and earn 5 coins!'
                                : 'Complete all lessons to unlock',
                        style: AppTextStyles.caption.copyWith(
                          color: (nonNullCourse.quiz.isCompleted || attempted)
                              ? (isLockedToday ? Colors.orange : Colors.green)
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: nonNullCourse.allLessonsCompleted && !isLockedToday && !(nonNullCourse.quiz.isCompleted || attempted)
                          ? Icon(
                              Icons.arrow_forward_ios,
                              color: courseColor,
                              size: 16,
                            )
                          : null,
                      onTap: nonNullCourse.allLessonsCompleted && !isLockedToday && !(nonNullCourse.quiz.isCompleted || attempted)
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MiniCourseQuizScreen(
                                    courseId: nonNullCourse.id,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * (nonNullCourse.lessons.length + 1))),
                ],
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}
