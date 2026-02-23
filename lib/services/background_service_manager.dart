import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../providers/providers.dart';
import 'email_report_service.dart';

/// The callback dispatcher for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      switch (taskName) {
        case BackgroundServiceManager.weeklyReportTask:
          await _handleWeeklyReportTask();
          break;
        default:
          debugPrint('Unknown task: $taskName');
      }
      return true;
    } catch (e) {
      debugPrint('Error executing task $taskName: $e');
      return false;
    }
  });
}

/// Background service manager for handling scheduled tasks like weekly reports
class BackgroundServiceManager {
  static const String weeklyReportTask = 'com.myleadershipquest.weeklyReport';
  static const Duration checkInterval = Duration(hours: 12);
  
  /// Initialize the background service
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // Set to false in production
    );
    
    // Schedule the weekly report check
    await scheduleWeeklyReportCheck();
  }
  
  /// Schedule the weekly report check task
  static Future<void> scheduleWeeklyReportCheck() async {
    await Workmanager().registerPeriodicTask(
      weeklyReportTask,
      weeklyReportTask,
      frequency: checkInterval,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    debugPrint('Weekly report check scheduled');
  }
  
  /// Cancel all background tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    debugPrint('All background tasks canceled');
  }
}

/// Handle the weekly report task
Future<void> _handleWeeklyReportTask() async {
  debugPrint('Checking if weekly reports should be sent...');
  
  final shouldSend = await EmailReportService.shouldSendWeeklyReport();
  if (!shouldSend) {
    debugPrint('Not time to send weekly reports yet');
    return;
  }
  
  // In a real app, we would access the providers through dependency injection
  // For this implementation, we'll use a simplified approach
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user_data');
  
  if (userJson == null) {
    debugPrint('No user data found');
    return;
  }
  
  // In the real implementation, we would properly initialize providers
  // and access the actual user and goal data
  debugPrint('Weekly report task would send emails now if this was production');
  
  // For demonstration purposes, we'll just log that we would send the report
  // In a real app, we would:
  // 1. Initialize providers with actual data
  // 2. Get the user and goal data
  // 3. Call EmailReportService.generateAndSendWeeklyReport()
}
