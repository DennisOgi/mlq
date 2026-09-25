enum PostType {
  user,
  adminAnnouncement,
  poll;

  static PostType fromString(String? value) {
    switch (value) {
      case 'admin_announcement':
        return PostType.adminAnnouncement;
      case 'poll':
        return PostType.poll;
      default:
        return PostType.user;
    }
  }

  String toDbValue() {
    switch (this) {
      case PostType.adminAnnouncement:
        return 'admin_announcement';
      case PostType.poll:
        return 'poll';
      case PostType.user:
        return 'user';
    }
  }
}

class PollOptionModel {
  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;

  PollOptionModel({
    required this.id,
    required this.label,
    this.sortOrder = 0,
    this.voteCount = 0,
  });

  PollOptionModel copyWith({
    String? id,
    String? label,
    int? sortOrder,
    int? voteCount,
  }) {
    return PollOptionModel(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? schoolId;
  final String content;
  final DateTime createdAt;
  final List<String> likedByUserIds;
  final List<CommentModel> comments;
  final PostType postType;
  final String? title;
  final bool isPinned;
  final String priority;
  final DateTime? expiresAt;
  final List<PollOptionModel> pollOptions;
  final String? userVoteOptionId;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.schoolId,
    required this.content,
    required this.createdAt,
    this.likedByUserIds = const [],
    this.comments = const [],
    this.postType = PostType.user,
    this.title,
    this.isPinned = false,
    this.priority = 'normal',
    this.expiresAt,
    this.pollOptions = const [],
    this.userVoteOptionId,
  });

  bool get isAdminPost => postType == PostType.adminAnnouncement;
  bool get isPoll => postType == PostType.poll;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get hasUserVoted => userVoteOptionId != null;
  int get totalPollVotes =>
      pollOptions.fold<int>(0, (sum, opt) => sum + opt.voteCount);

  int get likesCount => likedByUserIds.length;
  int get commentsCount => comments.length;

  bool isLikedByUser(String userId) => likedByUserIds.contains(userId);

  PostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? schoolId,
    String? content,
    DateTime? createdAt,
    List<String>? likedByUserIds,
    List<CommentModel>? comments,
    PostType? postType,
    String? title,
    bool? isPinned,
    String? priority,
    DateTime? expiresAt,
    List<PollOptionModel>? pollOptions,
    String? userVoteOptionId,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      schoolId: schoolId ?? this.schoolId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likedByUserIds: likedByUserIds ?? this.likedByUserIds,
      comments: comments ?? this.comments,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      isPinned: isPinned ?? this.isPinned,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      pollOptions: pollOptions ?? this.pollOptions,
      userVoteOptionId: userVoteOptionId ?? this.userVoteOptionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      if (schoolId != null) 'schoolId': schoolId,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likedByUserIds': likedByUserIds,
      'comments': comments.map((comment) => comment.toJson()).toList(),
      'postType': postType.toDbValue(),
      if (title != null) 'title': title,
      'isPinned': isPinned,
      'priority': priority,
      if (expiresAt != null)
        'expiresAt': expiresAt!.millisecondsSinceEpoch,
      'pollOptions': pollOptions
          .map((o) => {
                'id': o.id,
                'label': o.label,
                'sortOrder': o.sortOrder,
                'voteCount': o.voteCount,
              })
          .toList(),
      if (userVoteOptionId != null) 'userVoteOptionId': userVoteOptionId,
    };
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      schoolId: json['schoolId'],
      content: json['content'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      likedByUserIds: List<String>.from(json['likedByUserIds'] ?? []),
      comments: (json['comments'] as List?)
              ?.map((comment) => CommentModel.fromJson(comment))
              .toList() ??
          [],
      postType: PostType.fromString(json['postType']),
      title: json['title'],
      isPinned: json['isPinned'] ?? false,
      priority: json['priority'] ?? 'normal',
      expiresAt: json['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'])
          : null,
      pollOptions: (json['pollOptions'] as List?)
              ?.map((o) => PollOptionModel(
                    id: o['id'],
                    label: o['label'],
                    sortOrder: o['sortOrder'] ?? 0,
                    voteCount: o['voteCount'] ?? 0,
                  ))
              .toList() ??
          [],
      userVoteOptionId: json['userVoteOptionId'],
    );
  }

  static List<PostModel> mockPosts() {
    final now = DateTime.now();

    return [
      PostModel(
        id: '1',
        userId: 'user456',
        userName: 'Emma',
        content:
            'I completed my reading goal today! 📚 So proud of myself for reading 20 pages every day this week!',
        createdAt: now.subtract(const Duration(hours: 2)),
        likedByUserIds: ['user123', 'user789'],
        comments: [
          CommentModel(
            id: 'c1',
            userId: 'user123',
            userName: 'Alex',
            content: 'Great job!',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    ];
  }
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  CommentModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      content: json['content'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }
}
