import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../utils/date_utils.dart';
import '../../utils/app_tab_navigation.dart';
import '../../utils/course_visuals.dart';
import '../onboarding/goal_onboarding_screen.dart';
import 'daily_goal_grid_screen.dart';

class GoalsScreen extends StatefulWidget {
  final bool isInHomeScreen;

  const GoalsScreen({super.key, this.isInHomeScreen = false});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  DateTime _selectedDate = DateTime.now();
  int _categoryIndex = 0;

  static const _categoryLabels = ['All', 'Academic', 'Social', 'Health'];
  static const _categories = <GoalCategory?>[
    null,
    GoalCategory.academic,
    GoalCategory.social,
    GoalCategory.health,
  ];

  GoalCategory? get _category => _categories[_categoryIndex];

  bool _inCategory(GoalCategory? c) => _category == null || c == _category;

  @override
  Widget build(BuildContext context) {
    final content = Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        if (goalProvider.isLoading && !goalProvider.isInitialized) {
          return const SafeArea(
            child: MlqLoadingState(message: 'Loading your goals...'),
          );
        }

        final user = Provider.of<UserProvider>(context).user;
        final todayGoals = goalProvider.getDailyGoalsForDate(DateTime.now());
        final doneToday = todayGoals.where((g) => g.isCompleted).length;
        final mainGoals = [
          ...goalProvider.mainGoals,
          ...goalProvider.expiredGoals,
        ].where((g) => _inCategory(g.category)).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            final maxWidth = isDesktop ? 1080.0 : double.infinity;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  MlqHeroHeader(
                    title: 'My',
                    highlight: 'Goals',
                    subtitle: todayGoals.isEmpty
                        ? 'Plan today with up to 3 daily goals'
                        : '$doneToday of ${todayGoals.length} daily goals done today',
                    showBack:
                        !widget.isInHomeScreen && Navigator.of(context).canPop(),
                    bottom: MlqHeroStats(
                      items: [
                        (
                          value: '$doneToday/${todayGoals.length}',
                          label: 'Today',
                          icon: Icons.task_alt_rounded,
                        ),
                        (
                          value: '${user?.currentStreak ?? 0}',
                          label: 'Day streak',
                          icon: Icons.local_fire_department_rounded,
                        ),
                        (
                          value: '${goalProvider.activeGoalsCount}',
                          label: 'Main goals',
                          icon: Icons.flag_rounded,
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            MlqSegmentTabs(
                              labels: _categoryLabels,
                              selected: _categoryIndex,
                              onChanged: (i) =>
                                  setState(() => _categoryIndex = i),
                            ),
                            const SizedBox(height: 16),
                            _buildMainGoals(mainGoals, goalProvider),
                            const SizedBox(height: 24),
                            _buildDateSelector(),
                            const SizedBox(height: 14),
                            _buildDailyGoalsList(goalProvider),
                            const SizedBox(height: 16),
                            if (AppDateUtils.isToday(_selectedDate))
                              _buildAddDailyGoalButton(todayGoals.length),
                            const SizedBox(height: 28),
                            const MlqSectionHeader(
                              title: 'This week',
                              icon: Icons.insights_rounded,
                            ),
                            const SizedBox(height: 12),
                            const WeeklyProgressGraph(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (widget.isInHomeScreen) {
      return content;
    }

    return Scaffold(body: content);
  }

  // ── Main goals ──────────────────────────────────────────────

  Widget _buildMainGoals(
      List<MainGoalModel> goals, GoalProvider goalProvider) {
    if (goals.isEmpty) {
      final hasAny = goalProvider.mainGoals.isNotEmpty ||
          goalProvider.expiredGoals.isNotEmpty;
      final label = _categoryLabels[_categoryIndex].toLowerCase();
      return _GoalEmptyCard(
        cover: MlqCourseVisuals.goalCoverFor(
          _category?.name ?? 'academic',
          gender: context.read<UserProvider>().user?.gender,
        ),
        title: hasAny ? 'No $label goal yet' : 'Set your main goals',
        message: hasAny
            ? 'Add a $label main goal from the Home screen to balance your quest.'
            : 'Pick one academic, social and health goal to start your quest.',
        actionLabel: hasAny ? 'Go to Home' : 'Set goals',
        onAction: () {
          if (hasAny) {
            AppTabNavigation.goToTab(0);
            if (!widget.isInHomeScreen) Navigator.of(context).maybePop();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoalOnboardingScreen()),
            );
          }
        },
      );
    }

    final featured = goals.first;
    final rest = goals.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeaturedGoalCard(goal: featured, onOpen: () => _openGoal(featured)),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final g in rest) ...[
            _GoalRow(goal: g, onTap: () => _openGoal(g)),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  void _openGoal(MainGoalModel goal) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DailyGoalGridScreen(mainGoal: goal)),
    );
  }

  // ── Daily goals ─────────────────────────────────────────────

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates = List.generate(7, (index) {
      return DateTime(now.year, now.month, now.day - 3 + index);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MlqSectionHeader(
          title: 'Daily check-in',
          icon: Icons.today_rounded,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = AppDateUtils.isSameDay(date, _selectedDate);
              final isToday = AppDateUtils.isToday(date);

              return Material(
                color: isSelected ? AppColors.plum : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.plum
                            : isToday
                                ? AppColors.secondary
                                : AppColors.border,
                        width: isToday && !isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isSelected
                                ? Colors.white.withOpacity(0.75)
                                : AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalsList(GoalProvider goalProvider) {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    final categoryById = {
      for (final g in [...goalProvider.mainGoals, ...goalProvider.expiredGoals])
        g.id: g.category,
    };

    final goalsForDay = goalProvider.dailyGoals.where((goal) {
      final inDay = (goal.date.isAtSameMomentAs(startOfDay) ||
              goal.date.isAfter(startOfDay)) &&
          (goal.date.isBefore(endOfDay) ||
              goal.date.isAtSameMomentAs(endOfDay));
      return inDay && _inCategory(categoryById[goal.mainGoalId]);
    }).toList();

    if (goalsForDay.isEmpty) {
      return MlqSurface(
        child: MlqEmptyState(
          title: AppDateUtils.isToday(_selectedDate)
              ? 'No Goals for Today'
              : 'No Goals for ${AppDateUtils.formatMonthAndDay(_selectedDate)}',
          message: 'Add a daily goal to keep your leadership streak going.',
          icon: Icons.task_alt_rounded,
          actionLabel:
              AppDateUtils.isToday(_selectedDate) ? 'Add Daily Goal' : null,
          onAction: () => _showAddDailyGoalDialog(context),
        ),
      );
    }

    final completedCount = goalsForDay.where((g) => g.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppDateUtils.isToday(_selectedDate)
                    ? "Today's goals"
                    : 'Goals for ${AppDateUtils.formatMonthAndDay(_selectedDate)}',
                style: AppTextStyles.bodyBold,
              ),
            ),
            Text(
              '$completedCount/${goalsForDay.length} done',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MlqProgressBar(value: completedCount / goalsForDay.length),
        const SizedBox(height: 12),
        ...goalsForDay.map((goal) => DailyGoalCard(
              goal: goal,
              showMainGoal: true,
              onDelete: goal.isCompleted
                  ? null
                  : () => _showDeleteDailyGoalDialog(context, goal),
            )),
      ],
    );
  }

  Widget _buildAddDailyGoalButton(int todayCount) {
    final canAddMoreGoals = todayCount < 3;
    return QuestButton(
      text: canAddMoreGoals
          ? 'Add Daily Goal ($todayCount/3)'
          : 'Daily Goal Limit Reached (3/3)',
      icon: canAddMoreGoals ? Icons.add : Icons.check_circle,
      type: canAddMoreGoals ? QuestButtonType.primary : QuestButtonType.outline,
      isFullWidth: true,
      onPressed: canAddMoreGoals
          ? () => _showAddDailyGoalDialog(context)
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You can only set 3 daily goals per day. Delete an existing goal to add another.',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
    );
  }

  void _showAddDailyGoalDialog(BuildContext context) {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Use activeMainGoalsForDailyGoals to filter out completed/expired/archived goals
    final activeMainGoals = goalProvider.activeMainGoalsForDailyGoals;

    // Check if there are any active main goals
    if (activeMainGoals.isEmpty) {
      // Check if user has any main goals at all
      final allMainGoals = goalProvider.mainGoals;
      String message;
      if (allMainGoals.isEmpty) {
        message = 'You need to set a main goal first!';
      } else {
        // User has goals but they're all completed/expired
        message =
            'All your main goals are completed or expired. Archive them and create a new goal to continue.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    String title = '';
    String selectedMainGoalId = activeMainGoals.first.id;

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false; // persist within the dialog scope
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Daily Goal', style: AppTextStyles.heading3),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'Enter your daily goal',
                      ),
                      onChanged: (value) {
                        title = value;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Main goal selection - only show active goals
                    Text('Related to Main Goal', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedMainGoalId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: activeMainGoals.map((goal) {
                        return DropdownMenuItem<String>(
                          value: goal.id,
                          child: Text(goal.title),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedMainGoalId = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date selection (default to selected date)
                    Text('Date', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    Text(
                      AppDateUtils.formatFullDate(_selectedDate),
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a goal title',
                                  style: AppTextStyles.body
                                      .copyWith(color: Colors.white),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          // Create and add the daily goal
                          final dailyGoal = DailyGoalModel.createDailyGoal(
                            userId: userProvider.user!.id,
                            mainGoalId: selectedMainGoalId,
                            title: title,
                            date: _selectedDate,
                          );

                          setState(() {
                            isSubmitting = true;
                          });
                          final status =
                              await goalProvider.addDailyGoal(dailyGoal);
                          setState(() {
                            isSubmitting = false;
                          });

                          switch (status) {
                            case AddDailyGoalStatus.createdOnline:
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Daily goal added! (+0.5 coins)',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                              break;
                            case AddDailyGoalStatus.queuedOffline:
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Daily goal saved offline. It will sync when you are online.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.secondary,
                                  ),
                                );
                              }
                              break;
                            case AddDailyGoalStatus.limitReached:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      goalProvider.lastDailyGoalError ??
                                          'You can only set 3 daily goals per day.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                              break;
                            case AddDailyGoalStatus.unrelated:
                            case AddDailyGoalStatus.failed:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      goalProvider.lastDailyGoalError ??
                                          'Failed to add daily goal. Please try again.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                              break;
                            case AddDailyGoalStatus.cloned:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      goalProvider.lastDailyGoalError ??
                                          'You already used that same daily goal under a different main goal today. Write a different task.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                              break;
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpgradePrompt(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Upgrade to Premium'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock $feature and get access to:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✨ Premium Benefits:', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  Text('• Detailed goal analytics', style: AppTextStyles.body),
                  Text('• Progress insights & trends',
                      style: AppTextStyles.body),
                  Text('• Advanced goal templates', style: AppTextStyles.body),
                  Text('• Unlimited goal tracking', style: AppTextStyles.body),
                  Text('• Priority support', style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/subscription-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDailyGoalDialog(BuildContext context, DailyGoalModel goal) {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Goal', style: AppTextStyles.heading3),
          content: Text(
            'Are you sure you want to delete this daily goal?\n\n${goal.title}',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () async {
                await goalProvider.deleteDailyGoal(goal.id);

                if (context.mounted) {
                  Navigator.pop(context);

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Daily goal deleted',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

IconData _categoryIcon(GoalCategory c) {
  switch (c) {
    case GoalCategory.academic:
      return Icons.school_rounded;
    case GoalCategory.social:
      return Icons.people_rounded;
    case GoalCategory.health:
      return Icons.favorite_rounded;
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.plum.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );

class _FeaturedGoalCard extends StatelessWidget {
  final MainGoalModel goal;
  final VoidCallback onOpen;

  const _FeaturedGoalCard({required this.goal, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final pct = goal.progressPercentage;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final art = Stack(
      fit: StackFit.expand,
      children: [
        MlqCoverImage(
          asset: MlqCourseVisuals.goalCoverFor(
            goal.category.name,
            seed: goal.id,
            gender: context.read<UserProvider>().user?.gender,
          ),
          fallbackIcon: _categoryIcon(goal.category),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: MlqPill(
            label: goal.categoryName,
            icon: _categoryIcon(goal.category),
            background: Colors.white,
          ),
        ),
        if (goal.isCompleted || goal.isExpired)
          Positioned(
            right: 12,
            top: 12,
            child: MlqPill(
              label: goal.isCompleted ? 'Completed' : 'Expired',
              icon: goal.isCompleted
                  ? Icons.check_rounded
                  : Icons.schedule_rounded,
              background:
                  goal.isCompleted ? AppColors.success : AppColors.error,
              foreground: Colors.white,
            ),
          ),
      ],
    );
    final details = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.heading3.copyWith(height: 1.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${goal.currentXp} / ${goal.totalXpRequired} XP',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.goldText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MlqProgressBar(value: pct),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${goal.timelineText} · Ends ${DateFormat('MMM d').format(goal.endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          QuestButton(
            text: goal.isCompleted || goal.isExpired
                ? 'View goal'
                : 'Update progress',
            type: QuestButtonType.secondary,
            height: 44,
            isFullWidth: true,
            onPressed: onOpen,
          ),
        ],
      ),
    );

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 280, height: 210, child: art),
                    Expanded(child: details),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(aspectRatio: 16 / 10, child: art),
                    details,
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final MainGoalModel goal;
  final VoidCallback onTap;

  const _GoalRow({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: MlqCoverImage(
                      asset:
                          MlqCourseVisuals.goalCoverFor(
                            goal.category.name,
                            seed: goal.id,
                            gender: context.read<UserProvider>().user?.gender,
                          ),
                      fallbackIcon: _categoryIcon(goal.category),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.categoryName.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.goldText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold,
                      ),
                      const SizedBox(height: 8),
                      MlqProgressBar(value: goal.progressPercentage, height: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

class _GoalEmptyCard extends StatelessWidget {
  final String cover;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _GoalEmptyCard({
    required this.cover,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: MlqCoverImage(asset: cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading3),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                QuestButton(
                  text: actionLabel,
                  type: QuestButtonType.primary,
                  height: 44,
                  onPressed: onAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
