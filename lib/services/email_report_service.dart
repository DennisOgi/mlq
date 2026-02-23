import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'supabase_service.dart';

class EmailReportService {
  static const String _lastReportSentKey = 'last_weekly_report_sent';
  
  // Server-side email sending via Supabase Edge Function (send-weekly-report)
  // Credentials and cadence are enforced on the server. No secrets in client.
  
  // Check if it's time to send a weekly report
  static Future<bool> shouldSendWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSent = prefs.getInt(_lastReportSentKey);
    
    if (lastSent == null) {
      return true; // First time, should send
    }
    
    final lastSentDate = DateTime.fromMillisecondsSinceEpoch(lastSent);
    final now = DateTime.now();
    
    // Check if it's been at least 7 days since the last report
    return now.difference(lastSentDate).inDays >= 7;
  }
  
  // Update the last sent timestamp
  static Future<void> _updateLastSentTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReportSentKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  // Generate and send weekly report for a user
  static Future<bool> generateAndSendWeeklyReport(
    UserModel user,
    GoalProvider goalProvider,
  ) async {
    // Skip if no parent email or reports not enabled
    if (user.parentEmail == null || !user.weeklyReportsEnabled) {
      debugPrint('Weekly reports not enabled or no parent email set');
      return false;
    }
    
    try {
      // Generate report data
      final reportData = _generateReportData(user, goalProvider);
      
      // Send via Supabase Edge Function (server handles cadence and logging)
      final success = await _sendViaEdgeFunction(user, reportData);
      
      if (success) {
        await _updateLastSentTimestamp();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error generating/sending weekly report: $e');
      return false;
    }
  }
  
  // Generate report data from user and goals
  static Map<String, dynamic> _generateReportData(
    UserModel user,
    GoalProvider goalProvider,
  ) {
    final mainGoals = goalProvider.mainGoals;
    final weeklyGoals = goalProvider.weeklyGoals;
    final completionRates = goalProvider.weeklyCompletionRates;
    
    // Calculate daily goals by day of week
    final dailyGoalsByDay = <String, int>{};
    weeklyGoals.forEach((date, goals) {
      final dayName = DateFormat('EEEE').format(date);
      dailyGoalsByDay[dayName] = goals.length;
    });
    
    // Calculate overall stats
    final totalDailyGoals = goalProvider.dailyGoals.length;
    final completedDailyGoals = goalProvider.dailyGoals.where((g) => g.isCompleted).length;
    final completionRate = totalDailyGoals > 0 
        ? (completedDailyGoals / totalDailyGoals * 100).toStringAsFixed(1) 
        : '0';
    
    // Format dates for the report
    final dateFormat = DateFormat('MMM d');
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    // Generate day-by-day completion data
    final dailyCompletionData = <String, String>{};
    completionRates.forEach((date, rate) {
      final dateStr = dateFormat.format(date);
      final percentage = (rate * 100).toStringAsFixed(0);
      dailyCompletionData[dateStr] = '$percentage%';
    });
    
    // Format main goals progress
    final mainGoalsProgress = mainGoals.map((goal) {
      return {
        'title': goal.title,
        'category': goal.categoryName,
        'progress': '${(goal.progressPercentage * 100).toStringAsFixed(0)}%',
        'timeline': goal.timelineText,
        'endDate': goal.formattedEndDate,
      };
    }).toList();
    
    // Build the report data
    return {
      'userName': user.name,
      'userAge': user.age,
      'reportDate': DateFormat('MMMM d, yyyy').format(now),
      'reportPeriod': '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
      'overallCompletion': '$completionRate%',
      'totalGoals': totalDailyGoals,
      'completedGoals': completedDailyGoals,
      'dailyCompletionData': dailyCompletionData,
      'mainGoalsProgress': mainGoalsProgress,
      'coinsEarned': user.coins.toStringAsFixed(1),
      'strengths': _identifyStrengths(goalProvider),
      'areasForImprovement': _identifyAreasForImprovement(goalProvider),
    };
  }
  
  // Identify strengths based on goal completion patterns
  static List<String> _identifyStrengths(GoalProvider goalProvider) {
    final strengths = <String>[];
    final mainGoals = goalProvider.mainGoals;
    final dailyGoals = goalProvider.dailyGoals;
    
    // Check for consistent daily goal completion
    final recentDailyGoals = dailyGoals
        .where((g) => g.date.isAfter(DateTime.now().subtract(const Duration(days: 14))))
        .toList();
    
    if (recentDailyGoals.isNotEmpty) {
      final completedCount = recentDailyGoals.where((g) => g.isCompleted).length;
      final completionRate = completedCount / recentDailyGoals.length;
      
      if (completionRate >= 0.7) {
        strengths.add('Consistent daily goal completion');
      }
    }
    
    // Check for balanced goal categories
    final categories = mainGoals.map((g) => g.category).toSet();
    if (categories.length >= 2) {
      strengths.add('Working on multiple areas of development');
    }
    
    // Check for long-term planning
    if (mainGoals.any((g) => g.timeline == GoalTimeline.threeMonth)) {
      strengths.add('Setting and working toward long-term goals');
    }
    
    // Default strength if none identified
    if (strengths.isEmpty) {
      strengths.add('Taking initiative to set personal goals');
    }
    
    return strengths;
  }
  
  // Identify areas for improvement
  static List<String> _identifyAreasForImprovement(GoalProvider goalProvider) {
    final improvements = <String>[];
    final mainGoals = goalProvider.mainGoals;
    final dailyGoals = goalProvider.dailyGoals;
    
    // Check for incomplete daily goals
    final recentDailyGoals = dailyGoals
        .where((g) => g.date.isAfter(DateTime.now().subtract(const Duration(days: 14))))
        .toList();
    
    if (recentDailyGoals.isNotEmpty) {
      final completedCount = recentDailyGoals.where((g) => g.isCompleted).length;
      final completionRate = completedCount / recentDailyGoals.length;
      
      if (completionRate < 0.5) {
        improvements.add('Daily goal completion consistency');
      }
    }
    
    // Check for goal diversity
    final categories = mainGoals.map((g) => g.category).toSet();
    if (categories.length < 2 && mainGoals.isNotEmpty) {
      improvements.add('Diversifying goals across different areas');
    }
    
    // Check for stagnant goals
    final stagnantGoals = mainGoals.where((g) => 
      g.progressPercentage < 0.2 && 
      g.startDate.isBefore(DateTime.now().subtract(const Duration(days: 14)))
    ).toList();
    
    if (stagnantGoals.isNotEmpty) {
      improvements.add('Making progress on established goals');
    }
    
    // Default improvement if none identified
    if (improvements.isEmpty) {
      improvements.add('Setting more challenging goals');
    }
    
    return improvements;
  }
  
  // Send email via Supabase Edge Function (send-weekly-report)
  static Future<bool> _sendViaEdgeFunction(
    UserModel user,
    Map<String, dynamic> reportData,
  ) async {
    try {
      final client = SupabaseService.instance.client;
      final subject = 'Weekly Progress Report for ${reportData['userName']}';
      // The Edge Function validates cadence and logs results server-side
      final response = await client.functions.invoke(
        'send-weekly-report',
        body: {
          'subject': subject,
          'reportData': reportData,
        },
      );
      // supabase_flutter returns a response with dynamic data; consider { status: 'sent' }
      final data = response.data;
      if (data is Map && (data['status'] == 'sent' || data['status'] == 'skipped')) {
        // Treat skipped (cadence not met or disabled) as non-error from client perspective
        debugPrint('Weekly report result: ${data['status']}');
        return data['status'] == 'sent';
      }
      // If no data or unexpected, still consider success if no exception
      return true;
    } catch (e) {
      debugPrint('Error invoking send-weekly-report: $e');
      return false;
    }
  }
}
