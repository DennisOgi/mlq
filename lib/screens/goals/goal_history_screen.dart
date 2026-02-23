import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class GoalHistoryScreen extends StatelessWidget {
  const GoalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Goal History',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<GoalProvider>(
        builder: (context, goalProvider, child) {
          final archivedGoals = goalProvider.archivedGoals;
          
          if (archivedGoals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 100, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No Archived Goals Yet',
                    style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete and archive goals to see them here',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          // Group goals by completion date
          final groupedGoals = _groupGoalsByMonth(archivedGoals);
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedGoals.length,
            itemBuilder: (context, index) {
              final entry = groupedGoals.entries.elementAt(index);
              final monthYear = entry.key;
              final goals = entry.value;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      monthYear,
                      style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                    ),
                  ),
                  ...goals.map((goal) => _buildArchivedGoalCard(context, goal, goalProvider)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<MainGoalModel>> _groupGoalsByMonth(List<MainGoalModel> goals) {
    final Map<String, List<MainGoalModel>> grouped = {};
    
    for (final goal in goals) {
      final date = goal.completedAt ?? goal.archivedAt ?? goal.endDate;
      final monthYear = '${_getMonthName(date.month)} ${date.year}';
      
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(goal);
    }
    
    return grouped;
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildArchivedGoalCard(BuildContext context, MainGoalModel goal, GoalProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getCategoryIcon(goal.category), color: _getCategoryColor(goal.category)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(goal.title, style: AppTextStyles.bodyBold),
                ),
                if (goal.isCompleted)
                  const Icon(Icons.check_circle, color: AppColors.tertiary, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip('${goal.currentXp}/${goal.totalXpRequired} XP', Icons.star, Colors.amber),
                const SizedBox(width: 8),
                _buildInfoChip(goal.timelineText, Icons.calendar_today, AppColors.primary),
              ],
            ),
            if (goal.completedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Completed: ${_formatDate(goal.completedAt!)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.tertiary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final success = await provider.unarchiveMainGoal(goal.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success 
                                ? 'Goal restored to active list' 
                                : 'Cannot restore: active goal limit reached (3/3)',
                            style: AppTextStyles.body.copyWith(color: Colors.white),
                          ),
                          backgroundColor: success ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.unarchive, size: 18),
                  label: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
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

  String _formatDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }
}
