import 'package:intl/intl.dart';

enum GoalCategory { academic, social, health }

enum GoalTimeline { monthly, threeMonth }

class MainGoalModel {
  final String id;
  final String userId;
  final GoalCategory category;
  final String title;
  final GoalTimeline timeline;
  final DateTime startDate;
  final DateTime endDate;
  int currentXp;
  final int totalXpRequired;
  final String? description;
  
  // Archival system fields
  final bool isArchived;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final String status; // 'active', 'completed', 'archived', 'expired'

  MainGoalModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.timeline,
    required this.startDate,
    required this.endDate,
    this.currentXp = 0,
    required this.totalXpRequired,
    this.description,
    this.isArchived = false,
    this.completedAt,
    this.archivedAt,
    this.status = 'active',
  });

  double get progressPercentage {
    if (totalXpRequired <= 0) return 0.0;
    final progress = currentXp / totalXpRequired;
    return progress.clamp(0.0, 1.0);
  }

  bool get isCompleted => currentXp >= totalXpRequired;

  String get categoryName {
    switch (category) {
      case GoalCategory.academic:
        return 'Academic';
      case GoalCategory.social:
        return 'Social';
      case GoalCategory.health:
        return 'Health';
    }
  }

  String get formattedStartDate => DateFormat('MMM d, yyyy').format(startDate);
  String get formattedEndDate => DateFormat('MMM d, yyyy').format(endDate);
  String get timelineText => timeline == GoalTimeline.monthly ? 'Monthly' : '3-Month';
  
  // Archival system getters
  bool get isExpired => DateTime.now().isAfter(endDate) && !isCompleted;
  bool get canBeArchived => isCompleted || isExpired;
  String get statusDisplay {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'archived':
        return 'Archived';
      case 'expired':
        return 'Expired';
      default:
        return 'Active';
    }
  }

  MainGoalModel copyWith({
    String? id,
    String? userId,
    GoalCategory? category,
    String? title,
    GoalTimeline? timeline,
    DateTime? startDate,
    DateTime? endDate,
    int? currentXp,
    int? totalXpRequired,
    String? description,
    bool? isArchived,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    String? status,
  }) {
    return MainGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      title: title ?? this.title,
      timeline: timeline ?? this.timeline,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentXp: currentXp ?? this.currentXp,
      totalXpRequired: totalXpRequired ?? this.totalXpRequired,
      description: description ?? this.description,
      isArchived: isArchived ?? this.isArchived,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    // Get lowercase category name to match database constraint
    String categoryValue;
    switch (category) {
      case GoalCategory.academic:
        categoryValue = 'academic';
        break;
      case GoalCategory.social:
        categoryValue = 'social';
        break;
      case GoalCategory.health:
        categoryValue = 'health';
        break;
    }
    
    // Get timeline value that matches database constraint
    String timelineValue = timeline == GoalTimeline.monthly ? 'monthly' : 'threeMonth';
    
    return {
      'id': id,
      'user_id': userId,
      'category': categoryValue, // Using lowercase string to match database constraint
      'title': title,
      'timeline': timelineValue, // Using lowercase string
      'start_date': startDate.toIso8601String(), // Using ISO format for timestamp
      'end_date': endDate.toIso8601String(), // Using ISO format for timestamp
      'current_xp': currentXp,
      'total_xp_required': totalXpRequired,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_archived': isArchived,
      'completed_at': completedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory MainGoalModel.fromJson(Map<String, dynamic> json) {
    // Convert category string to enum (handle both lowercase and capitalized values)
    GoalCategory categoryEnum;
    switch (json['category']?.toString().toLowerCase()) {
      case 'academic':
        categoryEnum = GoalCategory.academic;
        break;
      case 'social':
        categoryEnum = GoalCategory.social;
        break;
      case 'health':
        categoryEnum = GoalCategory.health;
        break;
      default:
        categoryEnum = GoalCategory.academic; // Default
    }
    
    // Convert timeline string to enum (handle all possible values from database)
    GoalTimeline timelineEnum;
    final timelineValue = json['timeline']?.toString().toLowerCase();
    if (timelineValue == 'monthly') {
      timelineEnum = GoalTimeline.monthly;
    } else if (timelineValue == '3-month' || timelineValue == 'threemonth') {
      timelineEnum = GoalTimeline.threeMonth;
    } else {
      timelineEnum = GoalTimeline.monthly; // Default
    }
    
    // Parse dates from ISO string
    DateTime startDate;
    DateTime endDate;
    try {
      startDate = DateTime.parse(json['start_date']);
      endDate = DateTime.parse(json['end_date']);
    } catch (e) {
      // Fallback if date parsing fails
      final now = DateTime.now();
      startDate = now;
      endDate = now.add(const Duration(days: 30));
    }
    
    return MainGoalModel(
      id: json['id'],
      userId: json['user_id'],
      category: categoryEnum,
      title: json['title'],
      timeline: timelineEnum,
      startDate: startDate,
      endDate: endDate,
      currentXp: json['current_xp'] ?? 0,
      totalXpRequired: json['total_xp_required'],
      description: json['description'],
      isArchived: json['is_archived'] ?? false,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      archivedAt: json['archived_at'] != null 
          ? DateTime.parse(json['archived_at']) 
          : null,
      status: json['status'] ?? 'active',
    );
  }

  // Create a monthly goal with default values
  static MainGoalModel createMonthlyGoal({
    required String userId,
    required String title,
    required GoalCategory category,
    String? description,
  }) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month + 1, now.day);
    
    return MainGoalModel(
      // Use a temporary ID that will be replaced by Supabase's UUID
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      category: category,
      title: title,
      timeline: GoalTimeline.monthly,
      startDate: now,
      endDate: endDate,
      totalXpRequired: 1000, // Monthly goals require 1000 XP
      description: description,
    );
  }

  // Create a three-month goal with default values
  static MainGoalModel createThreeMonthGoal({
    required String userId,
    required String title,
    required GoalCategory category,
    String? description,
  }) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month + 3, now.day);
    
    return MainGoalModel(
      // Use a temporary ID that will be replaced by Supabase's UUID
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      category: category,
      title: title,
      timeline: GoalTimeline.threeMonth,
      startDate: now,
      endDate: endDate,
      totalXpRequired: 3000, // 3-month goals require 3000 XP
      description: description,
    );
  }

  // Mock goals for development
  static List<MainGoalModel> mockGoals() {
    final userId = 'user123';
    final now = DateTime.now();
    
    return [
      MainGoalModel(
        id: '1',
        userId: userId,
        category: GoalCategory.academic,
        title: 'Improve Math Skills',
        timeline: GoalTimeline.monthly,
        startDate: now,
        endDate: DateTime(now.year, now.month + 1, now.day),
        currentXp: 350,
        totalXpRequired: 1000,
        description: 'Practice math problems daily and complete all homework',
      ),
      MainGoalModel(
        id: '2',
        userId: userId,
        category: GoalCategory.social,
        title: 'Make New Friends',
        timeline: GoalTimeline.threeMonth,
        startDate: now,
        endDate: DateTime(now.year, now.month + 3, now.day),
        currentXp: 1200,
        totalXpRequired: 3000,
        description: 'Join a club and talk to at least one new person each week',
      ),
      MainGoalModel(
        id: '3',
        userId: userId,
        category: GoalCategory.health,
        title: 'Exercise Regularly',
        timeline: GoalTimeline.monthly,
        startDate: now,
        endDate: DateTime(now.year, now.month + 1, now.day),
        currentXp: 700,
        totalXpRequired: 1000,
        description: 'Do at least 30 minutes of physical activity every day',
      ),
    ];
  }
}
