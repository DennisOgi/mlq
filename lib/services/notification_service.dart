import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  final List<NotificationModel> _notifications = [];
  final _notificationStreamController = StreamController<List<NotificationModel>>.broadcast();
  final _inAppNotificationController = StreamController<NotificationModel>.broadcast();
  
  Stream<List<NotificationModel>> get notificationStream => _notificationStreamController.stream;
  Stream<NotificationModel> get inAppNotifications => _inAppNotificationController.stream;
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  bool _isInitialized = false;
  late final SupabaseClient _supabase;
  RealtimeChannel? _notificationsChannel;
  
  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _supabase = Supabase.instance.client;
    await _loadNotifications();
    _setupRealtimeSubscription();
    
    _isInitialized = true;
  }
  
  // Load notifications from Supabase
  Future<void> _loadNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('User not authenticated, using local notifications only');
        await _loadLocalNotifications();
        return;
      }
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      
      _notifications.clear();
      _notifications.addAll(
        (response as List<dynamic>).map((data) => NotificationModel.fromJson(data)).toList()
      );
      
      // Save to local storage for offline access
      await _saveLocalNotifications();
      
      // Broadcast updated notifications
      _notificationStreamController.add(_notifications);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      // Fallback to local storage
      await _loadLocalNotifications();
    }
  }
  
  // Setup realtime subscription for new notifications
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    _notificationsChannel = _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final rec = payload.newRecord;
              // Guard: only process current user's notifications
              if (rec['user_id'] != userId) return;
              final newNotification = NotificationModel.fromJson(rec);
              _addNotification(newNotification);
            } catch (e) {
              debugPrint('Realtime notification parse error: $e');
            }
          },
        )
        .subscribe();
  }
  
  // Add a new notification
  void _addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    _saveLocalNotifications();
    _notificationStreamController.add(_notifications);
    // Emit for in-app UX listeners
    _inAppNotificationController.add(notification);
  }
  
  // Create a new notification
  Future<void> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // Create notification object
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId ?? 'local-user',
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      // If online, save to Supabase
      if (userId != null) {
        final insertData = Map<String, dynamic>.from(notification.toJson())..remove('id');
        await _supabase.from('notifications').insert(insertData);
      } else {
        // If offline, just add to local list
        _addNotification(notification);
      }
      
      // Show in-app notification
      _showInAppNotification(notification);
    } catch (e) {
      debugPrint('Error creating notification: $e');
      // Create local notification as fallback
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'local-user',
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
        isRead: false,
      );
      
      _addNotification(notification);
      _showInAppNotification(notification);
    }
  }
  
  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;
    
    // Update local notification
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    _notificationStreamController.add(_notifications);
    
    // Update in Supabase if online
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      }
      
      // Update local storage
      await _saveLocalNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
  
  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    // Update all local notifications
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _notificationStreamController.add(_notifications);
    
    // Update in Supabase if online
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      }
      
      // Update local storage
      await _saveLocalNotifications();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
  
  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    // Remove from local list
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationStreamController.add(_notifications);
    
    // Remove from Supabase if online
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('notifications')
            .delete()
            .eq('id', notificationId);
      }
      
      // Update local storage
      await _saveLocalNotifications();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
  
  // Save notifications to local storage
  Future<void> _saveLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString('local_notifications', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving local notifications: $e');
    }
  }
  
  // Load notifications from local storage
  Future<void> _loadLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('local_notifications');
      
      if (notificationsJson != null && notificationsJson.isNotEmpty) {
        final parsed = jsonDecode(notificationsJson);
        if (parsed is List) {
          _notifications
            ..clear()
            ..addAll(parsed.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)));
        }
      }
      
      _notificationStreamController.add(_notifications);
    } catch (e) {
      debugPrint('Error loading local notifications: $e');
    }
  }
  
  // Show in-app notification
  void _showInAppNotification(NotificationModel notification) {
    // Push to the in-app stream; UI can listen and render toast/snackbar
    try {
      _inAppNotificationController.add(notification);
    } catch (e) {
      debugPrint('In-app notification emit error: $e');
    }
  }
  
  // Show notification in UI
  void showNotificationInUI(BuildContext context, NotificationModel notification) {
    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.title,
            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            notification.message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: _getNotificationColor(notification.type),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
        onPressed: () {
          // Navigate to notification detail or related screen
          // This will be implemented based on notification type
        },
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  // Get color based on notification type
  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.challenge:
        return AppColors.primary;
      case NotificationType.leaderboard:
        return AppColors.accent;
      case NotificationType.goal:
        return Colors.green;
      case NotificationType.badge:
        return Colors.amber;
      case NotificationType.course:
        return Colors.indigo;
      case NotificationType.system:
        return Colors.blueGrey;
    }
  }
  
  // Dispose resources
  void dispose() {
    _notificationStreamController.close();
    _notificationsChannel?.unsubscribe();
    _inAppNotificationController.close();
  }
}
