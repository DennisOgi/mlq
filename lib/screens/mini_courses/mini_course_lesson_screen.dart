import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/course_visuals.dart';
import '../../widgets/widgets.dart';
import 'mini_course_quiz_screen.dart';

class MiniCourseLessonScreen extends StatefulWidget {
  final String courseId;
  final int lessonIndex;

  const MiniCourseLessonScreen({
    super.key,
    required this.courseId,
    required this.lessonIndex,
  });

  @override
  State<MiniCourseLessonScreen> createState() => _MiniCourseLessonScreenState();
}

enum _SlideKind { hook, idea, takeaways, reflect }

class _Slide {
  final _SlideKind kind;
  final String headline;
  final String body;

  const _Slide(this.kind, {this.headline = '', this.body = ''});
}

/// Builds slides from a lesson's existing text: a hook, 1–2 sentence idea
/// slides, the key takeaways (if any), and a reflection prompt.
List<_Slide> _buildSlides(MiniCourseLessonModel lesson) {
  final text = lesson.content.replaceAll(RegExp(r'\s*\n+\s*'), ' ').trim();
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final ideas = <_Slide>[];
  var i = 0;
  while (i < sentences.length) {
    final headline = sentences[i];
    var body = '';
    if (i + 1 < sentences.length &&
        headline.length + sentences[i + 1].length <= 220) {
      body = sentences[i + 1];
      i += 2;
    } else {
      i += 1;
    }
    ideas.add(_Slide(_SlideKind.idea, headline: headline, body: body));
  }

  return [
    _Slide(_SlideKind.hook, headline: lesson.title),
    ...ideas,
    if (lesson.keyTakeaways.isNotEmpty) const _Slide(_SlideKind.takeaways),
    const _Slide(_SlideKind.reflect),
  ];
}

class _MiniCourseLessonScreenState extends State<MiniCourseLessonScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<_Slide>? _slides;
  String? _reflection;

  static const _reflectionChoices = ['This morning', 'After school', 'Tonight'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    final slides = _slides!;
    if (_currentPage < slides.length - 1) {
      _goTo(_currentPage + 1);
    } else {
      _completeLesson();
    }
  }

  void _completeLesson() {
    final miniCourseProvider =
        Provider.of<MiniCourseProvider>(context, listen: false);
    final course = miniCourseProvider.getCourseById(widget.courseId);
    if (course == null) return;

    final isLastLesson = widget.lessonIndex == course.lessons.length - 1;
    final attempted = miniCourseProvider.hasAttemptedQuiz(widget.courseId);

    if (isLastLesson && (course.quiz.isCompleted || attempted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz already completed!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
      return;
    }

    miniCourseProvider.completeLesson(widget.courseId);

    if (isLastLesson) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MiniCourseQuizScreen(courseId: widget.courseId),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MiniCourseLessonScreen(
            courseId: widget.courseId,
            lessonIndex: widget.lessonIndex + 1,
          ),
        ),
      );
    }
  }

  void _showFullLesson(MiniCourseLessonModel lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(lesson.title, style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            Text(
              lesson.content,
              style: AppTextStyles.body.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final miniCourseProvider = Provider.of<MiniCourseProvider>(context);
    final course = miniCourseProvider.getCourseById(widget.courseId);

    if (course == null || widget.lessonIndex >= course.lessons.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson Not Found')),
        body: const Center(
            child: Text('The requested lesson could not be found.')),
      );
    }

    final lesson = course.lessons[widget.lessonIndex];
    final slides = _slides ??= _buildSlides(lesson);
    final cover = MlqCourseVisuals.courseCover(
      course.id,
      course.topic,
      course.title,
      gender: context.read<UserProvider>().user?.gender,
    );
    final icon = MlqCourseVisuals.iconFor(course.topic);
    final isLast = _currentPage == slides.length - 1;
    final isLastLesson = widget.lessonIndex == course.lessons.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Lesson ${widget.lessonIndex + 1} of ${course.lessons.length}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showFullLesson(lesson),
                    child: const Text('Full text'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? AppColors.secondary
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  final Widget child;
                  switch (slide.kind) {
                    case _SlideKind.hook:
                      child = _HookSlide(
                        title: slide.headline,
                        topic: course.topic,
                        cover: cover,
                        icon: icon,
                        lessonLabel:
                            'Lesson ${widget.lessonIndex + 1} of ${course.lessons.length}',
                      );
                      break;
                    case _SlideKind.idea:
                      final ideaNo = slides
                              .take(index + 1)
                              .where((s) => s.kind == _SlideKind.idea)
                              .length;
                      child = _IdeaSlide(
                        eyebrow: 'IDEA $ideaNo',
                        headline: slide.headline,
                        body: slide.body,
                        icon: icon,
                      );
                      break;
                    case _SlideKind.takeaways:
                      child = _TakeawaysSlide(items: lesson.keyTakeaways);
                      break;
                    case _SlideKind.reflect:
                      child = _ReflectSlide(
                        choices: _reflectionChoices,
                        selected: _reflection,
                        onSelect: (c) => setState(() => _reflection = c),
                      );
                      break;
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _goTo(_currentPage - 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                              color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.textOnGold,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast
                                  ? (isLastLesson
                                      ? 'Finish · take the quiz'
                                      : 'Finish lesson')
                                  : (_currentPage == 0 ? 'Start' : 'Next'),
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
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
    );
  }
}

class _HookSlide extends StatelessWidget {
  final String title;
  final String topic;
  final String? cover;
  final IconData icon;
  final String lessonLabel;

  const _HookSlide({
    required this.title,
    required this.topic,
    required this.cover,
    required this.icon,
    required this.lessonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 360),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  child: MlqCoverImage(asset: cover, fallbackIcon: icon),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 350.ms),
        const SizedBox(height: 20),
        Text(
          topic.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.goldText,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          lessonLabel,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _IdeaSlide extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final String body;
  final IconData icon;

  const _IdeaSlide({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                eyebrow,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.goldText,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15, end: 0),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  body,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 17,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeawaysSlide extends StatelessWidget {
  final List<String> items;

  const _TakeawaysSlide({required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY TAKEAWAYS',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.goldText,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Remember these',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        color: AppColors.textOnGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: AppTextStyles.body.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (120 * i).ms, duration: 300.ms)
                .slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

class _ReflectSlide extends StatelessWidget {
  final List<String> choices;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ReflectSlide({
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: Image.asset(AppAssets.questorThinking,
                  fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              'TRY IT',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.goldText,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'When will you put this into action today?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in choices)
                  ChoiceChip(
                    label: Text(c),
                    selected: selected == c,
                    onSelected: (_) => onSelect(c),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: selected == c
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    selectedColor: AppColors.plum,
                    backgroundColor: AppColors.primarySoft,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              Text(
                'Great — a plan makes it happen.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
