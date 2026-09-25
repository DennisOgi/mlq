/// Display labels for YouTube-synced library subjects.
const kYtSubjectLabels = <String, String>{
  'mathematics': 'Mathematics',
  'biology': 'Biology',
  'chemistry': 'Chemistry',
  'physics': 'Physics',
  'english': 'English',
  'foreign_language': 'Foreign Languages',
  'history': 'History',
  'health_wellness': 'Health & Wellness',
  'general': 'General',
};

String ytSubjectLabel(String subject) =>
    kYtSubjectLabels[subject] ?? subject.replaceAll('_', ' ');

class YtChannel {
  final String id;
  final String name;
  final String subject;
  final String? handle;
  final String? thumbnailUrl;

  const YtChannel({
    required this.id,
    required this.name,
    required this.subject,
    this.handle,
    this.thumbnailUrl,
  });

  factory YtChannel.fromJson(Map<String, dynamic> json) => YtChannel(
        id: json['id'] as String,
        name: json['name'] as String,
        subject: json['subject'] as String,
        handle: json['handle'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );
}

class YtPlaylist {
  final String id;
  final String channelId;
  final String title;
  final String subject;
  final String? description;
  final String? thumbnailUrl;
  final String? difficulty;
  final int videoCount;
  final bool isFeatured;

  const YtPlaylist({
    required this.id,
    required this.channelId,
    required this.title,
    required this.subject,
    this.description,
    this.thumbnailUrl,
    this.difficulty,
    required this.videoCount,
    required this.isFeatured,
  });

  factory YtPlaylist.fromJson(Map<String, dynamic> json) => YtPlaylist(
        id: json['id'] as String,
        channelId: json['channel_id'] as String,
        title: json['title'] as String,
        subject: (json['subject'] as String?) ?? 'general',
        description: json['description'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        difficulty: json['difficulty'] as String?,
        videoCount: (json['video_count'] as int?) ?? 0,
        isFeatured: (json['is_featured'] as bool?) ?? false,
      );
}

class YtVideo {
  final String id;
  final String playlistId;
  final String? channelId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int position;
  final DateTime? publishedAt;
  bool completed;
  int watchedSeconds;
  bool bookmarked;

  YtVideo({
    required this.id,
    required this.playlistId,
    this.channelId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.durationSeconds,
    required this.position,
    this.publishedAt,
    this.completed = false,
    this.watchedSeconds = 0,
    this.bookmarked = false,
  });

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

  factory YtVideo.fromJson(Map<String, dynamic> json) {
    final progress = json['yt_video_progress'] as List?;
    final bookmarks = json['yt_video_bookmarks'] as List?;
    final p = progress != null && progress.isNotEmpty
        ? Map<String, dynamic>.from(progress.first as Map)
        : null;

    return YtVideo(
      id: json['id'] as String,
      playlistId: (json['playlist_id'] as String?) ?? '',
      channelId: json['channel_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      position: (json['position'] as int?) ?? 0,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      completed: (p?['completed'] as bool?) ?? false,
      watchedSeconds: (p?['watched_seconds'] as int?) ?? 0,
      bookmarked: bookmarks != null && bookmarks.isNotEmpty,
    );
  }
}
