class LibraryVideo {
  final String id;
  final String youtubeId;
  final String title;
  final String? description;
  final String channelName;
  final String topic;
  final List<String> tags;
  final int durationSeconds;
  final bool isFeatured;
  final String? featuredDate;
  final bool isPublished;
  final int viewCount;
  final int sortOrder;
  final DateTime createdAt;

  const LibraryVideo({
    required this.id,
    required this.youtubeId,
    required this.title,
    this.description,
    required this.channelName,
    required this.topic,
    required this.tags,
    required this.durationSeconds,
    required this.isFeatured,
    this.featuredDate,
    required this.isPublished,
    required this.viewCount,
    required this.sortOrder,
    required this.createdAt,
  });

  // YouTube thumbnail — mqdefault is available on more videos than hqdefault.
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg';

  String get thumbnailHighRes =>
      'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

  /// Fallback chain when the primary thumbnail 404s.
  List<String> get thumbnailFallbacks => [
        'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg',
        'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
        'https://img.youtube.com/vi/$youtubeId/sddefault.jpg',
        'https://img.youtube.com/vi/$youtubeId/default.jpg',
      ];

  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rm = m % 60;
      return '${h}h ${rm}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  LibraryVideo copyWith({
    String? id,
    String? youtubeId,
    String? title,
    String? description,
    String? channelName,
    String? topic,
    List<String>? tags,
    int? durationSeconds,
    bool? isFeatured,
    String? featuredDate,
    bool? isPublished,
    int? viewCount,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return LibraryVideo(
      id: id ?? this.id,
      youtubeId: youtubeId ?? this.youtubeId,
      title: title ?? this.title,
      description: description ?? this.description,
      channelName: channelName ?? this.channelName,
      topic: topic ?? this.topic,
      tags: tags ?? this.tags,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredDate: featuredDate ?? this.featuredDate,
      isPublished: isPublished ?? this.isPublished,
      viewCount: viewCount ?? this.viewCount,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LibraryVideo.fromJson(Map<String, dynamic> json) {
    return LibraryVideo(
      id: json['id'] as String,
      youtubeId: json['youtube_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      channelName: (json['channel_name'] as String?) ?? '',
      topic: (json['topic'] as String?) ?? 'General',
      tags: ((json['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      featuredDate: json['featured_date'] as String?,
      isPublished: (json['is_published'] as bool?) ?? true,
      viewCount: (json['view_count'] as int?) ?? 0,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'youtube_id': youtubeId,
        'title': title,
        'description': description,
        'channel_name': channelName,
        'topic': topic,
        'tags': tags,
        'duration_seconds': durationSeconds,
        'is_featured': isFeatured,
        'featured_date': featuredDate,
        'is_published': isPublished,
        'sort_order': sortOrder,
      };
}

// Topic categories tuned for secondary school learners
const kLibraryTopics = [
  'All',
  'Study Skills',
  'Biology',
  'Chemistry',
  'Physics',
  'Mathematics',
  'English & Literature',
  'History',
  'Geography & Civics',
  'Science & Nature',
  'Technology & Coding',
  'Health & Wellness',
  'Career & Life Skills',
  'Communication & Leadership',
  'Mindset & Psychology',
];
