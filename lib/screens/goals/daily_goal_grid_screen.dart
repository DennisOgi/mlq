import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/daily_goal_grid.dart';
import '../../widgets/animated_goal_stack.dart';

class DailyGoalGridScreen extends StatefulWidget {
  final MainGoalModel mainGoal;

  const DailyGoalGridScreen({
    super.key,
    required this.mainGoal,
  });

  @override
  State<DailyGoalGridScreen> createState() => _DailyGoalGridScreenState();
}

class _DailyGoalGridScreenState extends State<DailyGoalGridScreen> {
  DateTime? selectedDate;
  List<DailyGoalModel> selectedDayGoals = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mainGoal.title,
              style: AppTextStyles.heading3.copyWith(color: Colors.white),
            ),
            Text(
              '${widget.mainGoal.formattedStartDate} - ${widget.mainGoal.formattedEndDate}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: Consumer<GoalProvider>(
        builder: (context, goalProvider, child) {
          final dailyGoals = goalProvider.getDailyGoalsForMainGoal(widget.mainGoal.id);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected day goals display
                if (selectedDate != null && selectedDayGoals.isNotEmpty)
                  AnimatedGoalStack(
                    goals: selectedDayGoals,
                    selectedDate: selectedDate!,
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
                
                const SizedBox(height: 24),
                
                // Grid title and stats (hidden when a day is selected to avoid duplicate info cards)
                if (selectedDate == null || selectedDayGoals.isEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Goals Progress',
                            style: AppTextStyles.heading2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dailyGoals.where((g) => g.isCompleted).length} of ${dailyGoals.length} completed',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getCategoryColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getCategoryColor().withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(),
                              size: 16,
                              color: _getCategoryColor(),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.mainGoal.categoryName,
                              style: AppTextStyles.caption.copyWith(
                                color: _getCategoryColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 20),
                
                // GitHub-style contribution grid
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DailyGoalGrid(
                      mainGoal: widget.mainGoal,
                      dailyGoals: dailyGoals,
                      onDateSelected: (date, goals) {
                        setState(() {
                          selectedDate = date;
                          selectedDayGoals = goals;
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Legend
                _buildLegend(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legend',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Less', style: AppTextStyles.caption),
                const SizedBox(width: 8),
                _buildLegendSquare(Colors.grey.shade300),
                const SizedBox(width: 4),
                _buildLegendSquare(Colors.green.shade100),
                const SizedBox(width: 4),
                _buildLegendSquare(Colors.green.shade300),
                const SizedBox(width: 4),
                _buildLegendSquare(Colors.green.shade500),
                const SizedBox(width: 4),
                _buildLegendSquare(Colors.green.shade700),
                const SizedBox(width: 8),
                Text('More', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 0.5,
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (widget.mainGoal.category) {
      case GoalCategory.academic:
        return AppColors.academic;
      case GoalCategory.social:
        return AppColors.social;
      case GoalCategory.health:
        return AppColors.health;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.mainGoal.category) {
      case GoalCategory.academic:
        return Icons.school;
      case GoalCategory.social:
        return Icons.people;
      case GoalCategory.health:
        return Icons.favorite;
    }
  }
}
