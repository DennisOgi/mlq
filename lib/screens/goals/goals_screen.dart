import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../utils/date_utils.dart';

class GoalsScreen extends StatefulWidget {
  final bool isInHomeScreen;

  const GoalsScreen({super.key, this.isInHomeScreen = false});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Create the content widget with loading state
    final content = Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        // Show loading state while goals are being fetched
        if (goalProvider.isLoading && !goalProvider.isInitialized) {
          return const SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading your goals...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show main content when loaded
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly progress graph
                const WeeklyProgressGraph(),
                const SizedBox(height: 24),

                // Date selector
                _buildDateSelector(),
                const SizedBox(height: 16),

                // Daily goals for selected date
                _buildDailyGoalsList(),
                const SizedBox(height: 24),

                // Automatic synchronization happens in initGoals() - no manual button needed

                // Add daily goal button - only for today & limit 3
                if (AppDateUtils.isToday(_selectedDate))
                  Consumer<GoalProvider>(builder: (context, goalProvider, _) {
                    final todaysGoals =
                        goalProvider.getDailyGoalsForDate(DateTime.now());
                    final canAddMoreGoals = todaysGoals.length < 3;

                    return QuestButton(
                      text: canAddMoreGoals
                          ? 'Add Daily Goal (${todaysGoals.length}/3)'
                          : 'Daily Goal Limit Reached (3/3)',
                      icon: canAddMoreGoals ? Icons.add : Icons.check_circle,
                      type: canAddMoreGoals
                          ? QuestButtonType.primary
                          : QuestButtonType.outline,
                      isFullWidth: true,
                      onPressed: canAddMoreGoals
                          ? () => _showAddDailyGoalDialog(context)
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'You can only set 3 daily goals per day. Complete or delete existing goals to add more.',
                                    style: AppTextStyles.body
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: AppColors.secondary,
                                ),
                              );
                            },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );

    // If this screen is displayed within the HomeScreen, return just the content
    // Otherwise, wrap it in a Scaffold with AppBar
    if (widget.isInHomeScreen) {
      return content;
    }

    // Return the full Scaffold when shown as a standalone screen
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.flag_rounded,
                size: 28, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              'My Goals',
              style: AppTextStyles.heading3.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates = List.generate(7, (index) {
      return DateTime(now.year, now.month, now.day - 3 + index);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goals',
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = AppDateUtils.isSameDay(date, _selectedDate);
              final isToday = AppDateUtils.isToday(date);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildDailyGoalsList() {
    final goalProvider = Provider.of<GoalProvider>(context);
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    // Filter goals for the selected date
    final goalsForDay = goalProvider.dailyGoals.where((goal) {
      return (goal.date.isAtSameMomentAs(startOfDay) ||
              goal.date.isAfter(startOfDay)) &&
          (goal.date.isBefore(endOfDay) ||
              goal.date.isAtSameMomentAs(endOfDay));
    }).toList();

    if (goalsForDay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
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
            const Icon(
              Icons.task_alt,
              size: 48,
              color: AppColors.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              AppDateUtils.isToday(_selectedDate)
                  ? 'No Goals for Today'
                  : 'No Goals for ${AppDateUtils.formatMonthAndDay(_selectedDate)}',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add daily goals to make progress on your main goals!',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppDateUtils.isToday(_selectedDate)
              ? "Today's Goals"
              : 'Goals for ${AppDateUtils.formatMonthAndDay(_selectedDate)}',
          style: AppTextStyles.bodyBold,
        ),
        const SizedBox(height: 8),
        ...goalsForDay.map((goal) => DailyGoalCard(
              goal: goal,
              showMainGoal: true,
              onDelete: goal.isCompleted
                  ? null
                  : () => _showDeleteDailyGoalDialog(context, goal),
            )),
        const SizedBox(height: 8),
        // Completion status
        _buildCompletionStatus(goalsForDay),
      ],
    );
  }

  Widget _buildCompletionStatus(List<DailyGoalModel> goals) {
    final completedCount = goals.where((goal) => goal.isCompleted).length;
    final totalCount = goals.length;
    final completionRate = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Completion Status',
                style: AppTextStyles.bodyBold,
              ),
              Text(
                '$completedCount/$totalCount completed',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          QuestProgressIndicator(
            progress: completionRate,
            color: _getProgressColor(completionRate),
            showPercentage: true,
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double rate) {
    if (rate >= 0.8) return AppColors.tertiary;
    if (rate >= 0.5) return AppColors.primary;
    if (rate > 0) return AppColors.secondary;
    return Colors.grey.shade300;
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
                              // Award coins only when created online to prevent farming
                              userProvider.addCoins(0.5);
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
                                      'Daily goal limit reached (3/3).',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                              break;
                            case AddDailyGoalStatus.failed:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to add daily goal. Please try again.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
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
              onPressed: () {
                goalProvider.deleteDailyGoal(goal.id);
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
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
