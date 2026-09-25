/// Summer Daily Lessons — tips shown on the VAS home / SMS prompt rotation.
class VasDailyTip {
  const VasDailyTip({
    required this.title,
    required this.habit,
    required this.prompt,
    required this.taskHint,
  });

  final String title;
  final String habit;
  final String prompt;
  final String taskHint;
}

class VasDailyTips {
  VasDailyTips._();

  static const List<VasDailyTip> summer = [
    VasDailyTip(
      title: 'My Morning Routine',
      habit: 'Discipline',
      prompt:
          'Plan your day before school starts. Wake, pray or read, then write 3 tasks.',
      taskHint: 'Set 3 daily goals for tomorrow morning.',
    ),
    VasDailyTip(
      title: 'The Power of "One More Time"',
      habit: 'Resilience',
      prompt:
          'Top students don\'t quit. Practice one difficult subject for 10 minutes today.',
      taskHint: 'Add a goal: 10 minutes on your hardest subject.',
    ),
    VasDailyTip(
      title: 'Leader of the House',
      habit: 'Responsibility',
      prompt:
          'Take charge of one small task at home today — and do it well.',
      taskHint: 'Log a home responsibility as today\'s goal.',
    ),
    VasDailyTip(
      title: 'Speak Up, Speak Well',
      habit: 'Communication',
      prompt:
          'Practice introducing yourself, asking a question, or sharing one idea clearly.',
      taskHint: 'Write a gratitude note about someone who listened to you.',
    ),
    VasDailyTip(
      title: 'My Learning Planner',
      habit: 'Organization',
      prompt: 'Plan reading + homework so next term isn\'t stressful.',
      taskHint: 'Create goals for reading and homework this week.',
    ),
    VasDailyTip(
      title: 'Kindness is Leadership',
      habit: 'Character',
      prompt:
          'Three ways to help classmates and be the leader everyone trusts.',
      taskHint: 'Add a gratitude entry for a kind act you gave or received.',
    ),
    VasDailyTip(
      title: 'Focus Muscle',
      habit: 'Concentration',
      prompt:
          'Try a 10-minute no-phone study challenge. Beat distractions.',
      taskHint: 'Set a 10-minute focus goal and complete it.',
    ),
    VasDailyTip(
      title: 'Money & Choices',
      habit: 'Decision Making',
      prompt:
          'If you had ₦500, what\'s the smartest way to spend, save, or invest it?',
      taskHint: 'Write a goal about saving or spending wisely.',
    ),
    VasDailyTip(
      title: 'Mistake to Lesson',
      habit: 'Growth Mindset',
      prompt:
          'Turn one mistake from last term into a lesson for next term.',
      taskHint: 'Journal gratitude for a lesson a mistake taught you.',
    ),
    VasDailyTip(
      title: 'Future Me Speech',
      habit: 'Vision',
      prompt:
          'Write a 1-minute speech: "The kind of student I\'ll be next term."',
      taskHint: 'Set a goal that matches the student you want to become.',
    ),
  ];

  static VasDailyTip forToday([DateTime? now]) {
    final day =
        (now ?? DateTime.now()).difference(DateTime(2026, 1, 1)).inDays;
    return summer[day.abs() % summer.length];
  }
}
