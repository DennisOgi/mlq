import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';

import '../theme/app_theme.dart';
import 'quest_progress_indicator.dart';

class GoalCard extends StatelessWidget {
  final MainGoalModel goal;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool showActions;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onEdit,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = _getCategoryColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: AppTheme.getNeumorphicDecoration(
          borderRadius: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _getCategoryIcon(),
                      const SizedBox(width: 8),
                      Text(
                        goal.categoryName,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: _getCategoryTextColor(),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    goal.timelineText,
                    style: AppTextStyles.caption.copyWith(
                      color: _getCategoryTextColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Goal content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: AppTextStyles.heading3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (goal.description != null)
                    Text(
                      goal.description!,
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),

                  // Date range
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${goal.formattedStartDate} - ${goal.formattedEndDate}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress indicator area that reacts to provider updates
                  Selector<GoalProvider, MainGoalModel?>(
                    selector: (context, provider) =>
                        provider.getMainGoalById(goal.id),
                    builder: (context, latestGoal, _) {
                      final displayGoal = latestGoal ?? goal;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress indicator with XP text
                          QuestProgressIndicator(
                            progress: displayGoal.progressPercentage,
                            color: categoryColor,
                            showPercentage: true,
                            label:
                                'Progress: ${displayGoal.currentXp}/${displayGoal.totalXpRequired} XP',
                          ),
                        ],
                      );
                    },
                  ),

                  // Actions
                  if (showActions)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Add daily goal button (only for active goals)
                          if (!goal.isCompleted && !goal.isExpired)
                            IconButton(
                              onPressed: () => _addDailyGoal(context),
                              icon: const Icon(Icons.add_task),
                              color: AppColors.secondary,
                              tooltip: 'Add Daily Goal',
                            ),
                          // Archive button for completed or expired goals
                          if (goal.canBeArchived)
                            TextButton.icon(
                              onPressed: () => _showArchiveDialog(context),
                              icon: const Icon(Icons.archive, size: 18),
                              label: const Text('Archive'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          // Status indicator for completed/expired goals
                          if (goal.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.tertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 16, color: AppColors.tertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Completed',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.tertiary),
                                  ),
                                ],
                              ),
                            )
                          else if (goal.isExpired)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_off,
                                      size: 16, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Expired',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Color _getCategoryColor() {
    switch (goal.category) {
      case GoalCategory.academic:
        return AppColors.academic;
      case GoalCategory.social:
        return AppColors.social;
      case GoalCategory.health:
        return AppColors.health;
    }
  }

  Color _getCategoryTextColor() {
    switch (goal.category) {
      case GoalCategory.academic:
      case GoalCategory.social:
        return Colors.white;
      case GoalCategory.health:
        return Colors.black;
    }
  }

  Widget _getCategoryIcon() {
    IconData iconData;

    switch (goal.category) {
      case GoalCategory.academic:
        iconData = Icons.school;
        break;
      case GoalCategory.social:
        iconData = Icons.people;
        break;
      case GoalCategory.health:
        iconData = Icons.fitness_center;
        break;
    }

    return Icon(
      iconData,
      color: _getCategoryTextColor(),
      size: 20,
    );
  }

  void _addDailyGoal(BuildContext context) {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Check if goal is still valid for adding daily goals
    if (goal.isCompleted || goal.isExpired || goal.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot add daily goals to ${goal.isCompleted ? "completed" : goal.isExpired ? "expired" : "archived"} goals.',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show dialog to add daily goal
    showDialog(
      context: context,
      builder: (context) {
        String dailyGoalTitle = '';
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Daily Goal', style: AppTextStyles.heading3),
              content: TextField(
                decoration: const InputDecoration(
                  hintText: 'Enter daily goal',
                  labelText: 'Goal Title',
                ),
                onChanged: (value) {
                  dailyGoalTitle = value;
                },
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
                          if (dailyGoalTitle.isEmpty) {
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

                          final dailyGoal = DailyGoalModel.createDailyGoal(
                            userId: userProvider.user!.id,
                            mainGoalId: goal.id,
                            title: dailyGoalTitle,
                          );

                          setState(() => isSubmitting = true);
                          final status =
                              await goalProvider.addDailyGoal(dailyGoal);
                          setState(() => isSubmitting = false);

                          switch (status) {
                            case AddDailyGoalStatus.createdOnline:
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
                                      'Daily goal saved offline. It will sync when online.',
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

  void _showArchiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              goal.isCompleted ? Icons.celebration : Icons.archive,
              color: goal.isCompleted ? AppColors.tertiary : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                goal.isCompleted
                    ? 'Archive Completed Goal'
                    : 'Archive Expired Goal',
                style: AppTextStyles.heading3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.isCompleted
                  ? 'Congratulations on completing "${goal.title}"!'
                  : 'The goal "${goal.title}" has expired.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            Text(
              'Archiving will move this goal to your Goal History and free up a slot for a new goal.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final goalProvider =
                  Provider.of<GoalProvider>(dialogContext, listen: false);
              final success = await goalProvider.archiveMainGoal(goal.id);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Goal archived! You can now set a new goal.'
                          : 'Failed to archive goal. Please try again.',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.archive),
            label: const Text('Archive'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
