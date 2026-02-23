import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';

class WeeklyProgressGraph extends StatelessWidget {
  const WeeklyProgressGraph({super.key});

  @override
  Widget build(BuildContext context) {
    final goalProvider = Provider.of<GoalProvider>(context);
    final weeklyCompletionRates = goalProvider.weeklyCompletionRates;
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neumorphicDark,
            offset: const Offset(4, 4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.neumorphicHighlight,
            offset: const Offset(-4, -4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (weeklyCompletionRates.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_calculateAverageCompletion(weeklyCompletionRates).toStringAsFixed(0)}% avg',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                minY: 0,
                groupsSpace: 12,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: AppColors.surface,
                    tooltipRoundedRadius: 8,
                    tooltipBorder: const BorderSide(
                      color: AppColors.secondary,
                      width: 1,
                    ),
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = _getDateForIndex(weeklyCompletionRates.keys.toList(), groupIndex);
                      final percentage = (rod.toY * 100).toInt();
                      return BarTooltipItem(
                        '${AppDateUtils.formatShortDayOfWeek(date)}\n$percentage% completed',
                        AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dates = weeklyCompletionRates.keys.toList();
                        if (value.toInt() >= 0 && value.toInt() < dates.length) {
                          final date = dates[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppDateUtils.formatShortDayOfWeek(date),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == 0.5 || value == 1.0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${(value * 100).toInt()}%',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: _getBarGroups(weeklyCompletionRates),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups(Map<DateTime, double> completionRates) {
    final List<BarChartGroupData> barGroups = [];
    final dates = completionRates.keys.toList();
    dates.sort((a, b) => a.compareTo(b));
    
    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final rate = completionRates[date] ?? 0.0;
      
      // Determine bar color based on completion rate
      Color barColor;
      if (rate >= 0.8) {
        barColor = AppColors.tertiary; // Green for high completion
      } else if (rate >= 0.5) {
        barColor = AppColors.primary; // Yellow for medium completion
      } else if (rate > 0) {
        barColor = AppColors.secondary; // Blue for some completion
      } else {
        barColor = Colors.grey.shade300; // Grey for no completion
      }
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rate,
              color: barColor,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  DateTime _getDateForIndex(List<DateTime> dates, int index) {
    dates.sort((a, b) => a.compareTo(b));
    if (index >= 0 && index < dates.length) {
      return dates[index];
    }
    return DateTime.now();
  }

  double _calculateAverageCompletion(Map<DateTime, double> completionRates) {
    if (completionRates.isEmpty) return 0;
    final total = completionRates.values
        .fold<double>(0, (sum, value) => sum + value.clamp(0.0, 1.0));
    final avg = total / completionRates.length;
    return (avg * 100).clamp(0, 100);
  }
}
