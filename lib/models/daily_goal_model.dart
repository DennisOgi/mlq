import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DailyGoalModel {
  final String id;
  final String userId;
  final String mainGoalId;
  final String title;
  bool isCompleted;
  final DateTime date;
  final int xpValue;
  final String category;

  DailyGoalModel({
    required this.id,
    required this.userId,
    required this.mainGoalId,
    required this.title,
    this.isCompleted = false,
    required this.date,
    this.xpValue = 10, // Default XP value for daily goals
    this.category = 'other',
  });

  String get formattedDate => DateFormat('EEEE, MMM d').format(date);

  DailyGoalModel copyWith({
    String? id,
    String? userId,
    String? mainGoalId,
    String? title,
    bool? isCompleted,
    DateTime? date,
    int? xpValue,
    String? category,
  }) {
    return DailyGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mainGoalId: mainGoalId ?? this.mainGoalId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
      xpValue: xpValue ?? this.xpValue,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'main_goal_id': mainGoalId,
      'title': title,
      'is_completed': isCompleted,
      'date': date.toIso8601String(),
      'xp_value': xpValue,
      'category': category,
    };
  }

  factory DailyGoalModel.fromJson(Map<String, dynamic> json) {
    // Handle both database format (snake_case) and local storage format (camelCase)
    final userId = json['user_id'] ?? json['userId'];
    final mainGoalId = json['main_goal_id'] ?? json['mainGoalId'];
    final isCompleted = json['is_completed'] ?? json['isCompleted'] ?? false;
    final xpValue = json['xp_value'] ?? json['xpValue'] ?? 10;
    final category = json['category'] ?? 'other';

    // Handle date parsing for both formats
    DateTime date;
    if (json['date'] is String) {
      date = DateTime.parse(json['date']);
    } else if (json['date'] is int) {
      date = DateTime.fromMillisecondsSinceEpoch(json['date']);
    } else {
      date = DateTime.now();
    }

    return DailyGoalModel(
      id: json['id'],
      userId: userId,
      mainGoalId: mainGoalId,
      title: json['title'],
      isCompleted: isCompleted,
      date: date,
      xpValue: xpValue,
      category: category,
    );
  }

  // Create a new daily goal
  static DailyGoalModel createDailyGoal({
    required String userId,
    required String mainGoalId,
    required String title,
    DateTime? date,
    String category = 'other',
  }) {
    return DailyGoalModel(
      id: const Uuid().v4(),
      userId: userId,
      mainGoalId: mainGoalId,
      title: title,
      date: date ?? DateTime.now(),
      category: category,
    );
  }

  // Mock daily goals for development
  static List<DailyGoalModel> mockDailyGoals() {
    final userId = 'user123';
    final now = DateTime.now();

    // Create goals for the current week
    final List<DailyGoalModel> goals = [];

    // Today's goals
    goals.addAll([
      DailyGoalModel(
        id: '1',
        userId: userId,
        mainGoalId: '1', // Academic goal
        title: 'Complete math homework',
        date: now,
        isCompleted: true,
      ),
      DailyGoalModel(
        id: '2',
        userId: userId,
        mainGoalId: '2', // Social goal
        title: 'Talk to someone new at lunch',
        date: now,
        isCompleted: false,
      ),
      DailyGoalModel(
        id: '3',
        userId: userId,
        mainGoalId: '3', // Health goal
        title: 'Go for a 20-minute walk',
        date: now,
        isCompleted: true,
      ),
    ]);

    // Yesterday's goals
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    goals.addAll([
      DailyGoalModel(
        id: '4',
        userId: userId,
        mainGoalId: '1',
        title: 'Study for science quiz',
        date: yesterday,
        isCompleted: true,
      ),
      DailyGoalModel(
        id: '5',
        userId: userId,
        mainGoalId: '3',
        title: 'Drink 8 glasses of water',
        date: yesterday,
        isCompleted: true,
      ),
    ]);

    // Day before yesterday
    final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
    goals.addAll([
      DailyGoalModel(
        id: '6',
        userId: userId,
        mainGoalId: '1',
        title: 'Read a chapter of my book',
        date: twoDaysAgo,
        isCompleted: false,
      ),
      DailyGoalModel(
        id: '7',
        userId: userId,
        mainGoalId: '2',
        title: 'Help a classmate with homework',
        date: twoDaysAgo,
        isCompleted: true,
      ),
    ]);

    return goals;
  }
}
