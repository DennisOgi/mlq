/// Represents a school-specific mini course
class SchoolCourse {
  final String id;
  final String schoolId;
  final String? categoryId;
  final String title;
  final String description;
  final String topic;
  final String? summary;
  final List<CourseContentBlock> content;
  final List<QuizQuestion> quizQuestions;
  final List<String> gradeLevels;
  final String? subject;
  final int xpReward;
  final double coinReward;
  final String difficulty;
  final int estimatedDuration;
  final String? thumbnailUrl;
  final SchoolCourseStatus status;
  final bool isFeatured;
  final DateTime? publishDate;
  final DateTime? expiryDate;
  final String? rejectionReason;
  final int viewCount;
  final int completionCount;
  final double? avgRating;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final SchoolCourseCategory? category;
  final CourseCreator? creator;
  final CourseCreator? approver;
  final SchoolInfo? school;

  SchoolCourse({
    required this.id,
    required this.schoolId,
    this.categoryId,
    required this.title,
    required this.description,
    required this.topic,
    this.summary,
    required this.content,
    required this.quizQuestions,
    required this.gradeLevels,
    this.subject,
    this.xpReward = 20,
    this.coinReward = 5.0,
    this.difficulty = 'beginner',
    this.estimatedDuration = 10,
    this.thumbnailUrl,
    this.status = SchoolCourseStatus.draft,
    this.isFeatured = false,
    this.publishDate,
    this.expiryDate,
    this.rejectionReason,
    this.viewCount = 0,
    this.completionCount = 0,
    this.avgRating,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.creator,
    this.approver,
    this.school,
  });

  factory SchoolCourse.fromJson(Map<String, dynamic> json) {
    return SchoolCourse(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      categoryId: json['category_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      topic: json['topic'] as String,
      summary: json['summary'] as String?,
      content: (json['content'] as List<dynamic>?)
              ?.map(
                  (e) => CourseContentBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quizQuestions: (json['quiz_questions'] as List<dynamic>?)
              ?.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      gradeLevels: List<String>.from(json['grade_levels'] ?? []),
      subject: json['subject'] as String?,
      xpReward: json['xp_reward'] as int? ?? 20,
      coinReward: (json['coin_reward'] as num?)?.toDouble() ?? 5.0,
      difficulty: json['difficulty'] as String? ?? 'beginner',
      estimatedDuration: json['estimated_duration'] as int? ?? 10,
      thumbnailUrl: json['thumbnail_url'] as String?,
      status:
          SchoolCourseStatus.fromString(json['status'] as String? ?? 'draft'),
      isFeatured: json['is_featured'] as bool? ?? false,
      publishDate: json['publish_date'] != null
          ? DateTime.parse(json['publish_date'] as String)
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      completionCount: json['completion_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      createdBy: json['created_by'] as String,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      category: json['category'] != null
          ? SchoolCourseCategory.fromJson(
              json['category'] as Map<String, dynamic>)
          : null,
      creator: json['creator'] != null
          ? CourseCreator.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      approver: json['approver'] != null
          ? CourseCreator.fromJson(json['approver'] as Map<String, dynamic>)
          : null,
      school: json['school'] != null
          ? SchoolInfo.fromJson(json['school'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'topic': topic,
      'summary': summary,
      'content': content.map((e) => e.toJson()).toList(),
      'quiz_questions': quizQuestions.map((e) => e.toJson()).toList(),
      'grade_levels': gradeLevels,
      'subject': subject,
      'xp_reward': xpReward,
      'coin_reward': coinReward,
      'difficulty': difficulty,
      'estimated_duration': estimatedDuration,
      'thumbnail_url': thumbnailUrl,
      'status': status.value,
      'is_featured': isFeatured,
      'publish_date': publishDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'view_count': viewCount,
      'completion_count': completionCount,
      'avg_rating': avgRating,
      'created_by': createdBy,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SchoolCourse copyWith({
    String? id,
    String? schoolId,
    String? categoryId,
    String? title,
    String? description,
    String? topic,
    String? summary,
    List<CourseContentBlock>? content,
    List<QuizQuestion>? quizQuestions,
    List<String>? gradeLevels,
    String? subject,
    int? xpReward,
    double? coinReward,
    String? difficulty,
    int? estimatedDuration,
    String? thumbnailUrl,
    SchoolCourseStatus? status,
    bool? isFeatured,
    DateTime? publishDate,
    DateTime? expiryDate,
    String? rejectionReason,
    int? viewCount,
    int? completionCount,
    double? avgRating,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    SchoolCourseCategory? category,
    CourseCreator? creator,
    CourseCreator? approver,
    SchoolInfo? school,
  }) {
    return SchoolCourse(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      gradeLevels: gradeLevels ?? this.gradeLevels,
      subject: subject ?? this.subject,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      difficulty: difficulty ?? this.difficulty,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      publishDate: publishDate ?? this.publishDate,
      expiryDate: expiryDate ?? this.expiryDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      viewCount: viewCount ?? this.viewCount,
      completionCount: completionCount ?? this.completionCount,
      avgRating: avgRating ?? this.avgRating,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      creator: creator ?? this.creator,
      approver: approver ?? this.approver,
      school: school ?? this.school,
    );
  }

  /// Check if course is currently available
  bool get isAvailable {
    if (status != SchoolCourseStatus.published) return false;

    final now = DateTime.now();
    if (publishDate != null && publishDate!.isAfter(now)) return false;
    if (expiryDate != null && expiryDate!.isBefore(now)) return false;

    return true;
  }

  /// Get difficulty display text
  String get difficultyDisplay {
    switch (difficulty) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return difficulty;
    }
  }

  /// Get status display text
  String get statusDisplay => status.displayName;
}

/// Course status enum
enum SchoolCourseStatus {
  draft('draft', 'Draft'),
  pendingApproval('pending_approval', 'Pending Approval'),
  published('published', 'Published'),
  archived('archived', 'Archived'),
  rejected('rejected', 'Rejected');

  final String value;
  final String displayName;

  const SchoolCourseStatus(this.value, this.displayName);

  static SchoolCourseStatus fromString(String value) {
    return SchoolCourseStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SchoolCourseStatus.draft,
    );
  }
}

/// Course content block (text, image, video, etc.)
class CourseContentBlock {
  final String type; // 'text', 'image', 'video', 'heading', 'bullet_list'
  final String content;
  final Map<String, dynamic>? metadata;

  CourseContentBlock({
    required this.type,
    required this.content,
    this.metadata,
  });

  factory CourseContentBlock.fromJson(Map<String, dynamic> json) {
    return CourseContentBlock(
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Quiz question model
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String? ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] as int? ?? 0,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct_index': correctIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

/// Course category model
class SchoolCourseCategory {
  final String id;
  final String schoolId;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  SchoolCourseCategory({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    this.icon = 'book',
    this.color = '#00C4FF',
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory SchoolCourseCategory.fromJson(Map<String, dynamic> json) {
    return SchoolCourseCategory(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'book',
      color: json['color'] as String? ?? '#00C4FF',
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Course creator info
class CourseCreator {
  final String id;
  final String name;
  final String? avatarUrl;

  CourseCreator({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory CourseCreator.fromJson(Map<String, dynamic> json) {
    return CourseCreator(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

/// School info for course display
class SchoolInfo {
  final String id;
  final String name;
  final String? logoUrl;
  final String? primaryColor;

  SchoolInfo({
    required this.id,
    required this.name,
    this.logoUrl,
    this.primaryColor,
  });

  factory SchoolInfo.fromJson(Map<String, dynamic> json) {
    return SchoolInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String?,
    );
  }
}

/// Student progress on a course
class SchoolCourseProgress {
  final String id;
  final String userId;
  final String courseId;
  final String schoolId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? quizScore;
  final int quizAttempts;
  final int? bestQuizScore;
  final int timeSpentSeconds;
  final DateTime lastAccessedAt;
  final bool xpAwarded;
  final bool coinsAwarded;

  // Joined data
  final SchoolCourse? course;

  SchoolCourseProgress({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.schoolId,
    required this.startedAt,
    this.completedAt,
    this.quizScore,
    this.quizAttempts = 0,
    this.bestQuizScore,
    this.timeSpentSeconds = 0,
    required this.lastAccessedAt,
    this.xpAwarded = false,
    this.coinsAwarded = false,
    this.course,
  });

  factory SchoolCourseProgress.fromJson(Map<String, dynamic> json) {
    return SchoolCourseProgress(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      courseId: (json['course_id'] as String?) ?? '',
      schoolId: (json['school_id'] as String?) ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      quizScore: json['quiz_score'] as int?,
      quizAttempts: json['quiz_attempts'] as int? ?? 0,
      bestQuizScore: json['best_quiz_score'] as int?,
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : DateTime.now(),
      xpAwarded: json['xp_awarded'] as bool? ?? false,
      coinsAwarded: json['coins_awarded'] as bool? ?? false,
      course: json['course'] != null
          ? SchoolCourse.fromJson(json['course'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isCompleted => completedAt != null;

  String get formattedTimeSpent {
    final minutes = timeSpentSeconds ~/ 60;
    final seconds = timeSpentSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
