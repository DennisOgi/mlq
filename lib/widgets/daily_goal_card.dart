import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';

import '../utils/date_utils.dart';

class DailyGoalCard extends StatelessWidget {
  final DailyGoalModel goal;
  final MainGoalModel? mainGoal;
  final bool showMainGoal;
  final VoidCallback? onDelete;

  const DailyGoalCard({
    super.key,
    required this.goal,
    this.mainGoal,
    this.showMainGoal = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final goalProvider = Provider.of<GoalProvider>(context);

    // If mainGoal is not provided, try to get it from the provider
    // Use getArchivedGoalById to also find archived goals for orphaned daily goals
    final relatedMainGoal = mainGoal ??
        goalProvider.getMainGoalById(goal.mainGoalId) ??
        goalProvider.getArchivedGoalById(goal.mainGoalId);

    // Check if the main goal is in a blocked state (archived, expired, or completed)
    final isMainGoalBlocked = relatedMainGoal != null &&
        (relatedMainGoal.isArchived || relatedMainGoal.isExpired);
    final blockedReason = goalProvider.getDailyGoalBlockedReason(goal.id);
    final canComplete = !goal.isCompleted && !isMainGoalBlocked;

    final categoryColor = relatedMainGoal != null
        ? _getCategoryColor(relatedMainGoal.category)
        : AppColors.primary;

    // Use muted color if blocked
    final displayColor = isMainGoalBlocked ? Colors.grey : categoryColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isMainGoalBlocked ? Colors.grey.shade100 : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neumorphicDark,
            offset: const Offset(3, 3),
            blurRadius: 6,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.neumorphicHighlight,
            offset: const Offset(-3, -3),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show blocked indicator if main goal is archived/expired
          if (isMainGoalBlocked && !goal.isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    relatedMainGoal?.isArchived == true
                        ? Icons.archive_outlined
                        : Icons.timer_off_outlined,
                    size: 14,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      relatedMainGoal?.isArchived == true
                          ? 'Parent goal archived'
                          : 'Parent goal expired',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: goal.isCompleted
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: displayColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : Checkbox(
                    value: goal.isCompleted,
                    activeColor: displayColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: canComplete
                        ? (value) async {
                            // Use secure goal completion
                            if (value == true && !goal.isCompleted) {
                              final success = await goalProvider
                                  .toggleDailyGoalCompletion(goal.id);
                              if (!context.mounted) return;

                              if (success) {
                                // Show success message (coins are awarded server-side)
                                ScaffoldMessenger.maybeOf(context)
                                    ?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Goal completed! (+${goal.xpValue} XP, +0.5 coins)',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );

                                // Badge checking is now handled by SecureGoalService to prevent duplicates
                                // No need to check here anymore
                              } else {
                                // Show error message with specific reason
                                final reason = goalProvider
                                    .getDailyGoalBlockedReason(goal.id);
                                ScaffoldMessenger.maybeOf(context)
                                    ?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      reason ??
                                          'Goal completion failed. Please try again.',
                                      style: AppTextStyles.body
                                          .copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        : (value) {
                            // Show why completion is blocked
                            if (blockedReason != null) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    blockedReason,
                                    style: AppTextStyles.body
                                        .copyWith(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                  ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(
                        relatedMainGoal?.category ?? GoalCategory.academic),
                    size: 16,
                    color: displayColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.title,
                    style: AppTextStyles.body.copyWith(
                      decoration:
                          goal.isCompleted ? TextDecoration.lineThrough : null,
                      // Force solid line-through to avoid platform-specific dashed rendering
                      decorationStyle:
                          goal.isCompleted ? TextDecorationStyle.solid : null,
                      decorationThickness: goal.isCompleted ? 2.0 : null,
                      decorationColor:
                          goal.isCompleted ? AppColors.textSecondary : null,
                      fontWeight: FontWeight.w600,
                      // Use theme text colors so title is visible on light surfaces
                      color: goal.isCompleted || isMainGoalBlocked
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (showMainGoal && relatedMainGoal != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(relatedMainGoal.category),
                          size: 14,
                          color: displayColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            relatedMainGoal.title,
                            style: AppTextStyles.caption.copyWith(
                              color: displayColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  AppDateUtils.getFriendlyDateString(goal.date),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+${goal.xpValue} XP',
                    style: AppTextStyles.caption.copyWith(
                      color: displayColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return AppColors.academic;
      case GoalCategory.social:
        return AppColors.social;
      case GoalCategory.health:
        return AppColors.health;
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return Icons.school;
      case GoalCategory.social:
        return Icons.people;
      case GoalCategory.health:
        return Icons.fitness_center;
    }
  }
}
