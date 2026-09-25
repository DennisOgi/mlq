import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/course_visuals.dart';
import 'mini_course_lesson_screen.dart';
import 'mini_course_quiz_screen.dart';
import '../../services/global_daily_courses_service.dart';
import '../../providers/user_provider.dart';
import '../../utils/entitlements.dart';
import '../../widgets/feature_lock_card.dart';
import '../../widgets/mlq_ui_primitives.dart';

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
        final locked = await GlobalDailyCoursesService().hasAttempted(
          userId: uid,
          courseDate: dateKey,
          courseIndex: dailyIndex,
        );
        debugPrint(
          '[MiniCourseDetail] lock check id=$id date=$dateKey index=$dailyIndex locked=$locked',
        );
        return locked;
      } catch (e) {
        debugPrint('[MiniCourseDetail] lock check failed: $e');
        return false;
      }
    }

    // Extract the topic from the title
    final topic = nonNullCourse.title.replaceAll('Mini-Course: ', '');

    // Get the color and icon based on the course topic
    final courseIcon = MlqCourseVisuals.iconFor(nonNullCourse.title);
    final attempted = miniCourseProvider.hasAttemptedQuiz(nonNullCourse.id);

    if (!Entitlements.canUseMiniCourses(userProvider.user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mini-Course')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: FeatureLockCard(
            title: 'Mini-Courses',
            description:
                'Free accounts include mini-courses for 7 days. Subscribe to keep learning every day.',
            icon: Icons.school_rounded,
          ),
        ),
      );
    }

    final cover =
        MlqCourseVisuals.courseCover(
          nonNullCourse.id,
          nonNullCourse.topic,
          nonNullCourse.title,
          gender: context.read<UserProvider>().user?.gender,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<bool>(
        future: checkLocked(),
        builder: (context, snapshot) {
          final isLockedToday = snapshot.data == true;
          final lessons = nonNullCourse.lessons;
          final doneCount = lessons.where((l) => l.isCompleted).length;
          final quizDone = nonNullCourse.quiz.isCompleted || attempted;
          final allLessonsDone = nonNullCourse.allLessonsCompleted;
          final nextIndex = lessons.indexWhere((l) => !l.isCompleted);

          void openLesson(int index) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MiniCourseLessonScreen(
                  courseId: nonNullCourse.id,
                  lessonIndex: index,
                ),
              ),
            );
          }

          void openQuiz() {
            if (!allLessonsDone) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please complete all lessons first.'),
                  backgroundColor: AppColors.primary,
                ),
              );
              return;
            }
            if (isLockedToday || quizDone) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You already passed this quiz today.'),
                  backgroundColor: AppColors.primary,
                ),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    MiniCourseQuizScreen(courseId: nonNullCourse.id),
              ),
            );
          }

          final String ctaLabel;
          final VoidCallback? ctaAction;
          if (quizDone || isLockedToday) {
            ctaLabel = 'Completed today';
            ctaAction = null;
          } else if (!allLessonsDone && nextIndex >= 0) {
            ctaLabel = doneCount == 0
                ? 'Start lesson 1'
                : 'Continue · lesson ${nextIndex + 1}';
            ctaAction = () => openLesson(nextIndex);
          } else {
            ctaLabel = 'Take the quiz';
            ctaAction = openQuiz;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverHeader(
                  cover: cover,
                  icon: courseIcon,
                  eyebrow: nonNullCourse.topic,
                  title: topic,
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (nonNullCourse.description.trim().isNotEmpty)
                            Text(
                              nonNullCourse.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MlqPill(
                                label: '${lessons.length} lessons',
                                icon: Icons.menu_book_rounded,
                              ),
                              MlqPill(
                                label: 'Quiz · 5 coins',
                                icon: Icons.monetization_on_rounded,
                                background:
                                    AppColors.secondary.withOpacity(0.3),
                                foreground: AppColors.goldText,
                              ),
                              if (quizDone || isLockedToday)
                                const MlqPill(
                                  label: 'Completed today',
                                  icon: Icons.check_rounded,
                                  background: AppColors.success,
                                  foreground: Colors.white,
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$doneCount of ${lessons.length} lessons done',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          MlqProgressBar(
                            value: lessons.isEmpty
                                ? 0
                                : doneCount / lessons.length,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: ctaAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: AppColors.textOnGold,
                                disabledBackgroundColor: AppColors.primarySoft,
                                disabledForegroundColor: AppColors.textSecondary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                ctaLabel,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const MlqSectionHeader(
                            title: 'Lessons',
                            icon: Icons.format_list_numbered_rounded,
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < lessons.length; i++)
                            Builder(builder: (context) {
                              final lesson = lessons[i];
                              final isNext = !lesson.isCompleted &&
                                  (i == 0 || lessons[i - 1].isCompleted);
                              final isLocked = !lesson.isCompleted && !isNext;
                              return _StepRow(
                                number: '${i + 1}',
                                title: lesson.title,
                                subtitle: lesson.isCompleted
                                    ? 'Done'
                                    : isNext
                                        ? 'Up next'
                                        : 'Locked',
                                state: lesson.isCompleted
                                    ? _StepState.done
                                    : isNext
                                        ? _StepState.next
                                        : _StepState.locked,
                                onTap: isLocked ? null : () => openLesson(i),
                              ).animate().fadeIn(
                                    delay: (60 * i).ms,
                                    duration: 300.ms,
                                  );
                            }),
                          _StepRow(
                            number: '',
                            icon: Icons.emoji_events_rounded,
                            title: 'Final quiz',
                            subtitle: quizDone
                                ? 'Passed today · cannot be retaken'
                                : allLessonsDone
                                    ? (isLockedToday
                                        ? 'Already attempted today'
                                        : 'Test yourself and earn 5 coins')
                                    : 'Finish all lessons to unlock',
                            state: quizDone
                                ? _StepState.done
                                : (allLessonsDone && !isLockedToday)
                                    ? _StepState.next
                                    : _StepState.locked,
                            onTap: openQuiz,
                          ),
                        ],
                      ),
                    ),
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

class _CoverHeader extends StatelessWidget {
  final String? cover;
  final IconData icon;
  final String eyebrow;
  final String title;

  const _CoverHeader({
    required this.cover,
    required this.icon,
    required this.eyebrow,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SizedBox(
        height: (desktop ? 320 : 220) + top,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MlqCoverImage(asset: cover, fallbackIcon: icon),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 1],
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0xE67A0270),
                  ],
                ),
              ),
            ),
            Positioned(
              top: top + 6,
              left: 8,
              child: Material(
                color: Colors.black.withOpacity(0.25),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, next, locked }

class _StepRow extends StatelessWidget {
  final String number;
  final IconData? icon;
  final String title;
  final String subtitle;
  final _StepState state;
  final VoidCallback? onTap;

  const _StepRow({
    required this.number,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeBg;
    final Widget badgeChild;
    switch (state) {
      case _StepState.done:
        badgeBg = AppColors.success;
        badgeChild =
            const Icon(Icons.check_rounded, color: Colors.white, size: 20);
        break;
      case _StepState.next:
        badgeBg = AppColors.secondary;
        badgeChild = icon != null
            ? Icon(icon, color: AppColors.textOnGold, size: 20)
            : Text(
                number,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: AppColors.textOnGold,
                ),
              );
        break;
      case _StepState.locked:
        badgeBg = AppColors.primarySoft;
        badgeChild = const Icon(Icons.lock_rounded,
            color: AppColors.textHint, size: 18);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state == _StepState.next
                    ? AppColors.secondary
                    : AppColors.border,
                width: state == _StepState.next ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                  child: badgeChild,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: state == _StepState.locked
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: state == _StepState.done
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null && state != _StepState.locked)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
