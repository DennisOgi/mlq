import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/enhanced_app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications if not already done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EnhancedAppBar(
        title: 'Notifications',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              Provider.of<NotificationProvider>(context, listen: false).markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          final notifications = notificationProvider.notifications;
          
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }
          
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: AppTextStyles.heading.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll be notified about new challenges,\nleaderboard changes, and goal reminders.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final backgroundColor = notification.isRead
        ? Colors.white
        : AppColors.primary.withOpacity(0.05);
    
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        Provider.of<NotificationProvider>(context, listen: false)
            .deleteNotification(notification.id);
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            Provider.of<NotificationProvider>(context, listen: false)
                .markAsRead(notification.id);
          }
          
          // Handle navigation based on notification type
          _handleNotificationTap(notification);
        },
        child: Container(
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon based on notification type
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.getIcon(),
                    color: _getNotificationColor(notification.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Notification content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.subtitle.copyWith(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            notification.getFormattedTime(),
                            style: AppTextStyles.subtitle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: AppTextStyles.body,
                      ),
                      if (!notification.isRead)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getNotificationColor(notification.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // Handle notification tap based on type
  void _handleNotificationTap(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.challenge:
        // Navigate to challenges screen
        Navigator.pushReplacementNamed(context, '/challenges');
        break;
      case NotificationType.leaderboard:
        // Navigate to leaderboard screen
        Navigator.pushReplacementNamed(context, '/leaderboard');
        break;
      case NotificationType.goal:
        // Navigate to goals screen
        Navigator.pushReplacementNamed(context, '/goals');
        break;
      case NotificationType.badge:
        // Navigate to badges/profile screen
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case NotificationType.course:
        // Navigate to courses screen
        Navigator.pushReplacementNamed(context, '/courses');
        break;
      case NotificationType.system:
        // Just mark as read, no navigation
        break;
    }
  }
}
