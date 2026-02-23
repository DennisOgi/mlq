class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? schoolId;
  final String content;
  final DateTime createdAt;
  final List<String> likedByUserIds;
  final List<CommentModel> comments;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.schoolId,
    required this.content,
    required this.createdAt,
    this.likedByUserIds = const [],
    this.comments = const [],
  });

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
          .toList() ?? [],
    );
  }

  // Mock posts for development
  static List<PostModel> mockPosts() {
    final now = DateTime.now();
    
    return [
      PostModel(
        id: '1',
        userId: 'user456',
        userName: 'Emma',
        content: 'I completed my reading goal today! 📚 So proud of myself for reading 20 pages every day this week!',
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
      PostModel(
        id: '2',
        userId: 'user123',
        userName: 'Alex',
        content: 'I earned the Streak Master badge! 🏆 5 days of completing all my goals!',
        createdAt: now.subtract(const Duration(days: 1)),
        likedByUserIds: ['user456', 'user789', 'user101'],
        comments: [
          CommentModel(
            id: 'c2',
            userId: 'user456',
            userName: 'Emma',
            content: 'Awesome! Keep it up!',
            createdAt: now.subtract(const Duration(hours: 23)),
          ),
          CommentModel(
            id: 'c3',
            userId: 'user789',
            userName: 'Noah',
            content: 'I\'m working on that badge too!',
            createdAt: now.subtract(const Duration(hours: 22)),
          ),
        ],
      ),
      PostModel(
        id: '3',
        userId: 'user789',
        userName: 'Noah',
        content: 'Just finished the Science Explorer challenge! I learned so much about plants and how they grow. 🌱',
        createdAt: now.subtract(const Duration(days: 2)),
        likedByUserIds: ['user123'],
        comments: [],
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
