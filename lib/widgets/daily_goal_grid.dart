import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class DailyGoalGrid extends StatelessWidget {
  final MainGoalModel mainGoal;
  final List<DailyGoalModel> dailyGoals;
  final Function(DateTime date, List<DailyGoalModel> goals) onDateSelected;

  const DailyGoalGrid({
    super.key,
    required this.mainGoal,
    required this.dailyGoals,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels and grid with month labels scrolling together
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day of week labels
            _buildDayLabels(),
            const SizedBox(width: 8),
            
            // Scrollable grid
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthLabels(),
                    const SizedBox(height: 8),
                    _buildGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthLabels() {
    final weeks = _generateWeeks();
    final months = <String>[];
    String? currentMonth;
    
    for (final week in weeks) {
      final monthName = DateFormat('MMM').format(week.first);
      if (monthName != currentMonth) {
        months.add(monthName);
        currentMonth = monthName;
      } else {
        months.add('');
      }
    }

    return Row(
      children: months.map((month) => SizedBox(
        width: 126, // 7 days * (14px cell + 2px margins both sides)
        child: Text(
          month,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDayLabels() {
    const dayLabels = ['Mon', 'Wed', 'Fri'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 2), // Align with first row
        ...dayLabels.map((day) => Container(
          height: 18, // ~14px cell + ~4px spacing
          width: 28,
          alignment: Alignment.centerRight,
          child: Text(
            day,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildGrid() {
    final weeks = _generateWeeks();
    
    return Column(
      children: [
        // Grid rows (7 days of the week)
        for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
          Row(
            children: weeks.map((week) {
              if (dayOfWeek < week.length) {
                final date = week[dayOfWeek];
                return _buildGridCell(date);
              } else {
                return const SizedBox(width: 8, height: 8);
              }
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildGridCell(DateTime date) {
    final goalsForDate = dailyGoals.where((goal) => 
      goal.date.year == date.year &&
      goal.date.month == date.month &&
      goal.date.day == date.day
    ).toList();

    final completedGoals = goalsForDate.where((goal) => goal.isCompleted).length;
    final totalGoals = goalsForDate.length;
    
    Color cellColor;
    if (totalGoals == 0) {
      cellColor = Colors.grey.shade300; // Gray for empty days
    } else {
      // Green intensity based on completion ratio
      final completionRatio = completedGoals / totalGoals;
      if (completionRatio == 0) {
        cellColor = Colors.green.shade100;
      } else if (completionRatio <= 0.25) {
        cellColor = Colors.green.shade200;
      } else if (completionRatio <= 0.5) {
        cellColor = Colors.green.shade300;
      } else if (completionRatio <= 0.75) {
        cellColor = Colors.green.shade500;
      } else {
        cellColor = Colors.green.shade700;
      }
    }

    return GestureDetector(
      onTap: () {
        if (goalsForDate.isNotEmpty) {
          onDateSelected(date, goalsForDate);
        }
      },
      child: Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: Colors.grey.shade400,
            width: 0.6,
          ),
        ),
        child: totalGoals > 0 
          ? Tooltip(
              message: '${DateFormat('MMM d, yyyy').format(date)}\n'
                      '$completedGoals of $totalGoals goals completed',
              child: const SizedBox.expand(),
            )
          : null,
      ),
    );
  }

  List<List<DateTime>> _generateWeeks() {
    final startDate = mainGoal.startDate;
    final endDate = mainGoal.endDate;
    
    // Find the Monday of the week containing startDate
    final firstMonday = startDate.subtract(Duration(days: startDate.weekday - 1));
    
    // Find the Sunday of the week containing endDate
    final lastSunday = endDate.add(Duration(days: 7 - endDate.weekday));
    
    final weeks = <List<DateTime>>[];
    var currentDate = firstMonday;
    
    while (currentDate.isBefore(lastSunday) || currentDate.isAtSameMomentAs(lastSunday)) {
      final week = <DateTime>[];
      
      // Add 7 days to the week
      for (int i = 0; i < 7; i++) {
        week.add(currentDate);
        currentDate = currentDate.add(const Duration(days: 1));
      }
      
      weeks.add(week);
    }
    
    return weeks;
  }
}
