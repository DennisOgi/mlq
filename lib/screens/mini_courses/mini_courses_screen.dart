import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../models/school_course_model.dart';
import '../../providers/providers.dart';
import '../../providers/school_course_provider.dart';
import '../../services/global_daily_courses_service.dart';
import '../../utils/course_visuals.dart';
import '../../widgets/mlq_ui_primitives.dart';
import 'mini_course_detail_screen.dart';
import 'school_course_viewer_screen.dart';
import 'school_courses_screen.dart';

typedef _PastCourse = ({String date, MiniCourseModel course});

/// Today's three daily mini courses as large visual cards, followed by the
/// student's school courses and a read-only list of the past week's courses.
class MiniCoursesScreen extends StatefulWidget {
  const MiniCoursesScreen({super.key});

  @override
  State<MiniCoursesScreen> createState() => _MiniCoursesScreenState();
}

class _MiniCoursesScreenState extends State<MiniCoursesScreen> {
  final _service = GlobalDailyCoursesService();
  List<_PastCourse> _past = const [];
  bool _pastLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPast();
  }

  Future<void> _loadPast() async {
    try {
      final past = await _service.getRecentPastCourses();
      if (mounted) setState(() => _past = past);
    } catch (e) {
      debugPrint('[MiniCourses] past courses failed: $e');
    } finally {
      if (mounted) setState(() => _pastLoading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<MiniCourseProvider>().loadTodayCourses(),
      _loadPast(),
    ]);
  }

  Widget _constrain(Widget child, {EdgeInsets? padding}) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MiniCourseProvider>(context);
    final schoolProvider = Provider.of<SchoolCourseProvider>(context);
    final courses = provider.todayCourses;
    final done = courses
        .where((c) =>
            c.status == MiniCourseStatus.completed || c.quiz.isCompleted)
        .length;
    final schoolCourses = schoolProvider.hasSchool && schoolProvider.hasPremium
        ? schoolProvider.publishedCourses
        : const <SchoolCourse>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            MlqHeroHeader(
              title: "Today's",
              highlight: 'Quests',
              subtitle: courses.isEmpty
                  ? 'New courses arrive every day'
                  : '$done of ${courses.length} courses done · each one earns XP',
              showBack: Navigator.of(context).canPop(),
            ),
            const SizedBox(height: 16),
            if (courses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: MlqEmptyState(
                  title: 'No courses yet today',
                  message: 'Pull down to refresh, or check back soon.',
                  icon: Icons.menu_book_rounded,
                ),
              )
            else
              for (var i = 0; i < courses.length; i++)
                _constrain(
                  _CourseCard(course: courses[i])
                      .animate()
                      .fadeIn(delay: (80 * i).ms, duration: 350.ms)
                      .slideY(begin: 0.08, end: 0),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                ),
            if (schoolCourses.isNotEmpty) ...[
              const SizedBox(height: 8),
              _constrain(
                MlqSectionHeader(
                  title: 'School courses',
                  icon: Icons.account_balance_rounded,
                  trailing: _SeeAllButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SchoolCoursesScreen()),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              SizedBox(
                height: 184,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: schoolCourses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _SchoolCourseTile(course: schoolCourses[i]),
                ),
              ),
            ],
            if (_pastLoading || _past.isNotEmpty) ...[
              const SizedBox(height: 16),
              _constrain(
                const MlqSectionHeader(
                  title: 'Past courses',
                  icon: Icons.history_rounded,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              if (_pastLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                for (final p in _past.take(12))
                  _constrain(
                    _PastCourseRow(item: p),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _SchoolCourseTile extends StatelessWidget {
  final SchoolCourse course;
  const _SchoolCourseTile({required this.course});

  @override
  Widget build(BuildContext context) {
    final thumb = course.thumbnailUrl;
    return SizedBox(
      width: 200,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SchoolCourseViewerScreen(courseId: course.id),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 108,
                  width: double.infinity,
                  child: thumb != null && thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => MlqCoverImage(
                            asset: MlqCourseVisuals.coverFor(course.title),
                            fallbackIcon: Icons.account_balance_rounded,
                          ),
                        )
                      : MlqCoverImage(
                          asset: MlqCourseVisuals.coverFor(course.title),
                          fallbackIcon: Icons.account_balance_rounded,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold.copyWith(height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PastCourseRow extends StatelessWidget {
  final _PastCourse item;
  const _PastCourseRow({required this.item});

  String get _dateLabel {
    final d = DateTime.tryParse(item.date);
    if (d == null) return item.date;
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final course = item.course;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PastCourseReviewScreen(item: item),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: MlqCoverImage(
                    asset: MlqCourseVisuals.courseCover(
                      course.id,
                      course.topic,
                      course.title,
                      gender: context.read<UserProvider>().user?.gender,
                    ),
                    fallbackIcon: MlqCourseVisuals.iconFor(course.topic),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.topic.toUpperCase()} · $_dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.goldText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold.copyWith(height: 1.2),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only lessons for a past course. No quiz or progress writes.
class _PastCourseReviewScreen extends StatelessWidget {
  final _PastCourse item;
  const _PastCourseReviewScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final course = item.course;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MlqHeroHeader(
            title: course.title,
            subtitle: '${course.topic} · review only',
            showBack: true,
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Past courses are for reading. Quizzes and XP are for today\'s courses.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (course.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        course.description,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                    for (var i = 0; i < course.lessons.length; i++) ...[
                      const SizedBox(height: 16),
                      _LessonBlock(index: i, lesson: course.lessons[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonBlock extends StatelessWidget {
  final int index;
  final MiniCourseLessonModel lesson;
  const _LessonBlock({required this.index, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LESSON ${index + 1}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.goldText,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(lesson.title, style: AppTextStyles.heading3),
          const SizedBox(height: 10),
          Text(
            lesson.content,
            style: AppTextStyles.body.copyWith(height: 1.55),
          ),
          if (lesson.keyTakeaways.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final t in lesson.keyTakeaways)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.star_rounded,
                          size: 16, color: AppColors.goldPressed),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t,
                        style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final MiniCourseModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final done = course.status == MiniCourseStatus.completed ||
        course.quiz.isCompleted;
    final total = course.lessons.length;
    final completed = course.lessons.where((l) => l.isCompleted).length;
    final started = !done && (completed > 0 ||
        course.status == MiniCourseStatus.inProgress);
    final cover = MlqCourseVisuals.courseCover(
      course.id,
      course.topic,
      course.title,
      gender: context.read<UserProvider>().user?.gender,
    );

    void open() => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MiniCourseDetailScreen(courseId: course.id),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MlqCoverImage(
                      asset: cover,
                      fallbackIcon: MlqCourseVisuals.iconFor(course.topic),
                    ),
                    if (done)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: MlqPill(
                          label: 'Completed',
                          icon: Icons.check_rounded,
                          background: AppColors.success,
                          foreground: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.topic.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.goldText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '$completed of $total lessons',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MlqProgressBar(
                      value: done ? 1 : (total == 0 ? 0 : completed / total),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: done
                          ? OutlinedButton(
                              onPressed: open,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                    color: AppColors.border, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Review'),
                            )
                          : ElevatedButton(
                              onPressed: open,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: AppColors.textOnGold,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                started ? 'Continue' : 'Start',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
