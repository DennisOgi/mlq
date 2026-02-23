import 'package:uuid/uuid.dart';

class GratitudeEntry {
  final String id;
  final String content;
  final DateTime date;
  final String mood; // Optional mood associated with the gratitude entry

  GratitudeEntry({
    String? id,
    required this.content,
    DateTime? date,
    this.mood = 'happy',
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  // Convert to and from JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'date': date.toIso8601String(),
      'mood': mood,
    };
  }

  factory GratitudeEntry.fromJson(Map<String, dynamic> json) {
    return GratitudeEntry(
      id: json['id'],
      content: json['content'],
      date: DateTime.parse(json['date']),
      mood: json['mood'] ?? 'happy',
    );
  }

  // Create a copy of this entry with optional new values
  GratitudeEntry copyWith({
    String? content,
    DateTime? date,
    String? mood,
  }) {
    return GratitudeEntry(
      id: id,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: mood ?? this.mood,
    );
  }
}
