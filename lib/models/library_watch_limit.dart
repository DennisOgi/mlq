class LibraryWatchStatus {
  final bool allowed;
  final int count;
  final int limit;
  final int remaining;
  final bool alreadyWatched;
  final String? reason;

  const LibraryWatchStatus({
    required this.allowed,
    required this.count,
    required this.limit,
    required this.remaining,
    this.alreadyWatched = false,
    this.reason,
  });

  factory LibraryWatchStatus.fromJson(Map<String, dynamic> json) =>
      LibraryWatchStatus(
        allowed: (json['allowed'] as bool?) ?? true,
        count: (json['count'] as int?) ?? 0,
        limit: (json['limit'] as int?) ?? kLibraryDailyVideoLimit,
        remaining: (json['remaining'] as int?) ??
            ((json['limit'] as int?) ?? kLibraryDailyVideoLimit) -
                ((json['count'] as int?) ?? 0),
        alreadyWatched: (json['already_watched'] as bool?) ?? false,
        reason: json['reason'] as String?,
      );

  factory LibraryWatchStatus.guest() => const LibraryWatchStatus(
        allowed: true,
        count: 0,
        limit: kLibraryDailyVideoLimit,
        remaining: kLibraryDailyVideoLimit,
      );
}

const kLibraryDailyVideoLimit = 3;
