import 'package:flutter/material.dart';

enum MoodType {
  veryHappy,
  happy,
  neutral,
  sad,
  verySad,
  anxious,
  excited,
  tired,
  energetic,
  frustrated,
}

enum MoodTrigger {
  school,
  friends,
  family,
  homework,
  sports,
  health,
  achievement,
  challenge,
  other,
}

class MoodEntryModel {
  final String id;
  final String userId;
  final DateTime timestamp;
  final MoodType mood;
  final String? note;
  final List<MoodTrigger> triggers;
  final bool isMorning; // true for morning check-in, false for evening

  MoodEntryModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.mood,
    this.note,
    required this.triggers,
    required this.isMorning,
  });

  factory MoodEntryModel.fromJson(Map<String, dynamic> json) {
    return MoodEntryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      mood: MoodType.values.firstWhere(
        (e) => e.toString() == 'MoodType.${json['mood']}',
        orElse: () => MoodType.neutral,
      ),
      note: json['note'] as String?,
      triggers: (json['triggers'] as List<dynamic>?)
              ?.map((t) => MoodTrigger.values.firstWhere(
                    (e) => e.toString() == 'MoodTrigger.$t',
                    orElse: () => MoodTrigger.other,
                  ))
              .toList() ??
          [],
      isMorning: json['is_morning'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'mood': mood.toString().split('.').last,
      'note': note,
      'triggers': triggers.map((t) => t.toString().split('.').last).toList(),
      'is_morning': isMorning,
    };
  }

  // Helper methods
  String get moodEmoji {
    switch (mood) {
      case MoodType.veryHappy:
        return '😄';
      case MoodType.happy:
        return '😊';
      case MoodType.neutral:
        return '😐';
      case MoodType.sad:
        return '😢';
      case MoodType.verySad:
        return '😭';
      case MoodType.anxious:
        return '😰';
      case MoodType.excited:
        return '🤩';
      case MoodType.tired:
        return '😴';
      case MoodType.energetic:
        return '⚡';
      case MoodType.frustrated:
        return '😤';
    }
  }

  Color get moodColor {
    switch (mood) {
      case MoodType.veryHappy:
      case MoodType.happy:
      case MoodType.excited:
        return const Color(0xFF4CAF50); // Green
      case MoodType.energetic:
        return const Color(0xFFFF9800); // Orange
      case MoodType.neutral:
        return const Color(0xFF9E9E9E); // Gray
      case MoodType.tired:
        return const Color(0xFF607D8B); // Blue Gray
      case MoodType.anxious:
      case MoodType.frustrated:
        return const Color(0xFFFF5722); // Deep Orange
      case MoodType.sad:
      case MoodType.verySad:
        return const Color(0xFF2196F3); // Blue
    }
  }

  String get moodLabel {
    switch (mood) {
      case MoodType.veryHappy:
        return 'Very Happy';
      case MoodType.happy:
        return 'Happy';
      case MoodType.neutral:
        return 'Okay';
      case MoodType.sad:
        return 'Sad';
      case MoodType.verySad:
        return 'Very Sad';
      case MoodType.anxious:
        return 'Anxious';
      case MoodType.excited:
        return 'Excited';
      case MoodType.tired:
        return 'Tired';
      case MoodType.energetic:
        return 'Energetic';
      case MoodType.frustrated:
        return 'Frustrated';
    }
  }

  int get moodScore {
    // Score from 1-10 for analytics
    switch (mood) {
      case MoodType.verySad:
        return 1;
      case MoodType.sad:
        return 3;
      case MoodType.anxious:
        return 4;
      case MoodType.frustrated:
        return 4;
      case MoodType.neutral:
        return 5;
      case MoodType.tired:
        return 5;
      case MoodType.happy:
        return 7;
      case MoodType.energetic:
        return 8;
      case MoodType.excited:
        return 9;
      case MoodType.veryHappy:
        return 10;
    }
  }
}
