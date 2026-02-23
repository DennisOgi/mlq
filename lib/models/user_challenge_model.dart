import '../models/challenge_model.dart';

class UserChallengeModel {
  final String id;
  final String userId;
  final String challengeId;
  final ChallengeModel? challenge;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCompleted;
  final DateTime? completionDate;
  final int progress;

  UserChallengeModel({
    required this.id,
    required this.userId,
    required this.challengeId,
    this.challenge,
    required this.startDate,
    this.endDate,
    this.isCompleted = false,
    this.completionDate,
    this.progress = 0,
  });

  UserChallengeModel copyWith({
    String? id,
    String? userId,
    String? challengeId,
    ChallengeModel? challenge,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
    DateTime? completionDate,
    int? progress,
  }) {
    return UserChallengeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challengeId: challengeId ?? this.challengeId,
      challenge: challenge ?? this.challenge,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completionDate: completionDate ?? this.completionDate,
      progress: progress ?? this.progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'challenge_id': challengeId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_completed': isCompleted,
      'completion_date': completionDate?.toIso8601String(),
      'progress': progress,
    };
  }

  factory UserChallengeModel.fromJson(Map<String, dynamic> json) {
    return UserChallengeModel(
      id: json['id'],
      userId: json['user_id'],
      challengeId: json['challenge_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isCompleted: json['is_completed'] ?? false,
      completionDate: json['completion_date'] != null ? DateTime.parse(json['completion_date']) : null,
      progress: json['progress'] ?? 0,
    );
  }
}
