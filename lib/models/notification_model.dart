import 'package:flutter/material.dart';

enum NotificationType {
  challenge,
  leaderboard,
  goal,
  badge,
  course,
  system,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String? relatedId;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.createdAt,
    required this.isRead,
  });

  // Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? relatedId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  // Convert notification to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'related_id': relatedId,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  // Create notification from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: _parseNotificationType(json['type']),
      relatedId: json['related_id'],
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
    );
  }

  // Parse notification type from string
  static NotificationType _parseNotificationType(String typeStr) {
    switch (typeStr) {
      case 'challenge':
        return NotificationType.challenge;
      case 'leaderboard':
        return NotificationType.leaderboard;
      case 'goal':
        return NotificationType.goal;
      case 'badge':
        return NotificationType.badge;
      case 'course':
        return NotificationType.course;
      default:
        return NotificationType.system;
    }
  }

  // Get icon for notification type
  IconData getIcon() {
    switch (type) {
      case NotificationType.challenge:
        return Icons.emoji_events;
      case NotificationType.leaderboard:
        return Icons.leaderboard;
      case NotificationType.goal:
        return Icons.check_circle;
      case NotificationType.badge:
        return Icons.military_tech;
      case NotificationType.course:
        return Icons.school;
      case NotificationType.system:
        return Icons.notifications;
    }
  }

  // Get formatted time (e.g., "2 hours ago")
  String getFormattedTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
