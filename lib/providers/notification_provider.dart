import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isInitialized = false;
  StreamSubscription? _notificationSubscription;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;
  Stream<NotificationModel> get inAppNotifications => _notificationService.inAppNotifications;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize the notification service
    await _notificationService.initialize();
    
    // Subscribe to notification updates
    _notificationSubscription = _notificationService.notificationStream.listen((notifications) {
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    });
    
    _isInitialized = true;
    notifyListeners();
  }

  // Create a new notification
  Future<void> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
  }) async {
    await _notificationService.createNotification(
      title: title,
      message: message,
      type: type,
      relatedId: relatedId,
    );
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
  }

  // Show notification in UI
  void showNotificationInUI(BuildContext context, NotificationModel notification) {
    _notificationService.showNotificationInUI(context, notification);
  }

  // Notify about new challenge
  Future<void> notifyNewChallenge(String challengeName) async {
    await createNotification(
      title: 'New Challenge Available!',
      message: 'Check out the new "$challengeName" challenge!',
      type: NotificationType.challenge,
    );
  }

  // Notify about leaderboard change
  Future<void> notifyLeaderboardChange(int oldRank, int newRank) async {
    String message;
    
    if (newRank < oldRank) {
      message = 'You moved up from #$oldRank to #$newRank on the leaderboard!';
    } else {
      message = 'Your rank changed from #$oldRank to #$newRank on the leaderboard.';
    }
    
    await createNotification(
      title: 'Leaderboard Update',
      message: message,
      type: NotificationType.leaderboard,
    );
  }

  // Notify about goal reminder
  Future<void> notifyGoalReminder(String goalTitle) async {
    await createNotification(
      title: 'Goal Reminder',
      message: 'Don\'t forget to complete your goal: "$goalTitle"',
      type: NotificationType.goal,
    );
  }

  // Dispose resources
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
