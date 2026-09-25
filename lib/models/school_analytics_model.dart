class SchoolAnalytics {
  final String schoolId;
  final String schoolName;
  final int totalStudents;
  final int activeStudents;
  final int totalXp;
  final int monthlyXp;
  final int totalCoursesCompleted;
  final int totalBadgesEarned;
  final int totalGratitudeEntries;
  final int totalChallengesCompleted;
  final double engagementRate;
  final DateTime generatedAt;

  SchoolAnalytics({
    required this.schoolId,
    required this.schoolName,
    required this.totalStudents,
    required this.activeStudents,
    required this.totalXp,
    required this.monthlyXp,
    required this.totalCoursesCompleted,
    required this.totalBadgesEarned,
    required this.totalGratitudeEntries,
    required this.totalChallengesCompleted,
    required this.engagementRate,
    required this.generatedAt,
  });

  factory SchoolAnalytics.fromJson(Map<String, dynamic> json) {
    return SchoolAnalytics(
      schoolId: json['school_id'] ?? '',
      schoolName: json['school_name'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      activeStudents: json['active_students'] ?? 0,
      totalXp: json['total_xp'] ?? 0,
      monthlyXp: json['monthly_xp'] ?? 0,
      totalCoursesCompleted: json['total_courses_completed'] ?? 0,
      totalBadgesEarned: json['total_badges_earned'] ?? 0,
      totalGratitudeEntries: json['total_gratitude_entries'] ?? 0,
      totalChallengesCompleted: json['total_challenges_completed'] ?? 0,
      engagementRate: (json['engagement_rate'] ?? 0.0).toDouble(),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'school_name': schoolName,
      'total_students': totalStudents,
      'active_students': activeStudents,
      'total_xp': totalXp,
      'monthly_xp': monthlyXp,
      'total_courses_completed': totalCoursesCompleted,
      'total_badges_earned': totalBadgesEarned,
      'total_gratitude_entries': totalGratitudeEntries,
      'total_challenges_completed': totalChallengesCompleted,
      'engagement_rate': engagementRate,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

class StudentPerformance {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int totalXp;
  final int monthlyXp;
  final double coins;
  final int coursesCompleted;
  final int badgesEarned;
  final int challengesCompleted;
  final int gratitudeEntries;
  final int goalsCompleted;
  final int rank;
  final DateTime? lastActive;

  StudentPerformance({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.totalXp,
    required this.monthlyXp,
    required this.coins,
    required this.coursesCompleted,
    required this.badgesEarned,
    required this.challengesCompleted,
    required this.gratitudeEntries,
    required this.goalsCompleted,
    required this.rank,
    this.lastActive,
  });

  factory StudentPerformance.fromJson(Map<String, dynamic> json) {
    return StudentPerformance(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatarUrl: json['avatar_url'],
      totalXp: json['total_xp'] ?? 0,
      monthlyXp: json['monthly_xp'] ?? 0,
      coins: (json['coins'] ?? 0.0).toDouble(),
      coursesCompleted: json['courses_completed'] ?? 0,
      badgesEarned: json['badges_earned'] ?? 0,
      challengesCompleted: json['challenges_completed'] ?? 0,
      gratitudeEntries: json['gratitude_entries'] ?? 0,
      goalsCompleted: json['goals_completed'] ?? 0,
      rank: json['rank'] ?? 0,
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'avatar_url': avatarUrl,
      'total_xp': totalXp,
      'monthly_xp': monthlyXp,
      'coins': coins,
      'courses_completed': coursesCompleted,
      'badges_earned': badgesEarned,
      'challenges_completed': challengesCompleted,
      'gratitude_entries': gratitudeEntries,
      'goals_completed': goalsCompleted,
      'rank': rank,
      'last_active': lastActive?.toIso8601String(),
    };
  }
}

class MonthlyLeaderboard {
  final String monthKey; // Format: YYYY-MM
  final String schoolId;
  final List<StudentPerformance> topStudents;
  final DateTime generatedAt;

  MonthlyLeaderboard({
    required this.monthKey,
    required this.schoolId,
    required this.topStudents,
    required this.generatedAt,
  });

  factory MonthlyLeaderboard.fromJson(Map<String, dynamic> json) {
    return MonthlyLeaderboard(
      monthKey: json['month_key'] ?? '',
      schoolId: json['school_id'] ?? '',
      topStudents: (json['top_students'] as List<dynamic>?)
              ?.map((e) => StudentPerformance.fromJson(e))
              .toList() ??
          [],
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month_key': monthKey,
      'school_id': schoolId,
      'top_students': topStudents.map((e) => e.toJson()).toList(),
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

class SchoolTrends {
  final String schoolId;
  final Map<String, int> monthlyXpTrend; // month_key -> total_xp
  final Map<String, int> monthlyActiveStudents; // month_key -> active_count
  final Map<String, int> monthlyCourseCompletions; // month_key -> course_count
  final DateTime generatedAt;

  SchoolTrends({
    required this.schoolId,
    required this.monthlyXpTrend,
    required this.monthlyActiveStudents,
    required this.monthlyCourseCompletions,
    required this.generatedAt,
  });

  factory SchoolTrends.fromJson(Map<String, dynamic> json) {
    return SchoolTrends(
      schoolId: json['school_id'] ?? '',
      monthlyXpTrend: Map<String, int>.from(json['monthly_xp_trend'] ?? {}),
      monthlyActiveStudents:
          Map<String, int>.from(json['monthly_active_students'] ?? {}),
      monthlyCourseCompletions:
          Map<String, int>.from(json['monthly_course_completions'] ?? {}),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'monthly_xp_trend': monthlyXpTrend,
      'monthly_active_students': monthlyActiveStudents,
      'monthly_course_completions': monthlyCourseCompletions,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
