class SavingsGoalModel {
  final String id;
  final String userId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String icon;
  final String status; // active, completed, cancelled
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.icon,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress as a fraction 0.0 – 1.0
  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Progress as a percentage integer 0 – 100
  int get progressPercent => (progress * 100).round();

  /// Remaining amount to reach the goal
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, targetAmount);

  /// Whether the goal is still active
  bool get isActive => status == 'active';

  /// Whether the goal has been completed
  bool get isCompleted => status == 'completed';

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      icon: json['icon'] as String? ?? '🎯',
      status: json['status'] as String? ?? 'active',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'icon': icon,
      'status': status,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavingsGoalModel copyWith({
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? icon,
    String? status,
    DateTime? completedAt,
  }) {
    return SavingsGoalModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
