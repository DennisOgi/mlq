import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/library_watch_limit.dart';
import '../models/library_video_model.dart';
import '../models/yt_library_models.dart';
import '../utils/library_content_filter.dart';

class LibraryRepository {
  LibraryRepository._();
  static final LibraryRepository instance = LibraryRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  Future<void> requestYoutubeSync({bool force = false}) async {
    try {
      await _db.functions.invoke('sync-youtube', body: {'force': force});
    } catch (e) {
      debugPrint('[LibraryRepository] sync-youtube failed: $e');
    }
  }

  Future<List<YtPlaylist>> getAllWhitelistedPlaylists() async {
    final rows = await _db
        .from('yt_playlists')
        .select()
        .eq('is_available', true);
    final playlists = (rows as List)
        .map((r) => YtPlaylist.fromJson(Map<String, dynamic>.from(r)))
        .where((p) => isVisiblePlaylist(
              subject: p.subject,
              title: p.title,
              description: p.description,
              playlistId: p.id,
              channelId: p.channelId,
            ))
        .toList();
    playlists.sort((a, b) => compareWhitelistedPlaylistsById(
          a.id,
          a.title,
          b.id,
          b.title,
        ));
    return playlists;
  }

  Future<int> getWhitelistedVideoCount() async {
    final playlists = await getAllWhitelistedPlaylists();
    if (playlists.isEmpty) return 0;
    final ids = playlists.map((p) => p.id).toList();
    final rows = await _db
        .from('yt_videos')
        .select('id')
        .eq('is_available', true)
        .inFilter('playlist_id', ids);
    return (rows as List).length;
  }

  Future<List<LibraryVideo>> getWhitelistedPreviewVideos({int limit = 8}) async {
    final playlists = await getAllWhitelistedPlaylists();
    if (playlists.isEmpty) return [];

    final channelRows = await _db.from('yt_channels').select('id, name');
    final channelNames = <String, String>{
      for (final r in channelRows as List)
        r['id'] as String: r['name'] as String,
    };

    final preview = <LibraryVideo>[];
    final seen = <String>{};

    for (final playlist in playlists) {
      if (preview.length >= limit) break;
      final rows = await _db
          .from('yt_videos')
          .select()
          .eq('playlist_id', playlist.id)
          .eq('is_available', true)
          .order('position', ascending: true)
          .limit(2);
      for (final r in rows as List) {
        if (preview.length >= limit) break;
        final video = YtVideo.fromJson(Map<String, dynamic>.from(r));
        if (seen.contains(video.id)) continue;
        if (!isVisibleVideo(
          title: video.title,
          description: video.description,
          playlistId: video.playlistId,
          channelId: video.channelId,
        )) {
          continue;
        }
        seen.add(video.id);
        final channel = channelNames[video.channelId ?? playlist.channelId] ?? 'Educational';
        preview.add(toLibraryVideo(
          video,
          topic: playlist.subject,
          channelName: channel,
        ));
      }
    }
    return preview;
  }

  Future<List<String>> getSubjects() async {
    final rows = await _db
        .from('yt_playlists')
        .select('subject')
        .eq('is_available', true);
    final subjects = filterYtSubjects(
      (rows as List).map((r) => (r['subject'] as String?) ?? 'general'),
    );
    return subjects;
  }

  Future<List<YtPlaylist>> getPlaylists({
    required String subject,
    bool featuredOnly = false,
  }) async {
    var q = _db
        .from('yt_playlists')
        .select()
        .eq('is_available', true)
        .eq('subject', subject);
    if (featuredOnly) q = q.eq('is_featured', true);
    final rows = await q.order('video_count', ascending: false).limit(40);
    return (rows as List)
        .map((r) => YtPlaylist.fromJson(Map<String, dynamic>.from(r)))
        .where((p) => isVisiblePlaylist(
              subject: subject,
              title: p.title,
              description: p.description,
              playlistId: p.id,
              channelId: p.channelId,
            ))
        .toList();
  }

  Future<List<YtPlaylist>> getFeaturedPlaylists() async {
    final rows = await _db
        .from('yt_playlists')
        .select()
        .eq('is_available', true)
        .eq('is_featured', true)
        .neq('subject', 'history')
        .order('video_count', ascending: false)
        .limit(12);
    return (rows as List)
        .map((r) => YtPlaylist.fromJson(Map<String, dynamic>.from(r)))
        .where((p) => isVisiblePlaylist(
              subject: p.subject,
              title: p.title,
              description: p.description,
              playlistId: p.id,
              channelId: p.channelId,
            ))
        .toList();
  }

  Future<List<YtVideo>> getVideosForPlaylist(
    String playlistId,
    String userId, {
    String? subject,
  }) async {
    final rows = await _db
        .from('yt_videos')
        .select('''
          *,
          yt_video_progress(watched_seconds, completed),
          yt_video_bookmarks(id)
        ''')
        .eq('playlist_id', playlistId)
        .eq('is_available', true)
        .order('position', ascending: true);
    return (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r);
      return YtVideo.fromJson(map);
    }).where((v) => isVisibleVideo(
          title: v.title,
          description: v.description,
          subject: subject,
          playlistId: v.playlistId,
          channelId: v.channelId,
        )).toList();
  }

  Future<List<YtVideo>> searchVideos(String query, {String? subject}) async {
    if (query.trim().length < 2) return [];
    var filter = _db
        .from('yt_videos')
        .select()
        .eq('is_available', true)
        .ilike('title', '%${query.trim()}%');
    if (subject != null && subject != 'All') {
      // Join via playlist subject — simplified: filter title only for now
    }
    final rows = await filter.order('published_at', ascending: false).limit(40);
    return (rows as List)
        .map((r) => YtVideo.fromJson(Map<String, dynamic>.from(r)))
        .where((v) => isVisibleVideo(
              title: v.title,
              description: v.description,
              playlistId: v.playlistId,
              channelId: v.channelId,
            ))
        .toList();
  }

  Future<int> getCompletedCount(String userId, String playlistId) async {
    final videos = await _db
        .from('yt_videos')
        .select('id')
        .eq('playlist_id', playlistId)
        .eq('is_available', true);
    final ids = (videos as List).map((v) => v['id'].toString()).toList();
    if (ids.isEmpty) return 0;
    final prog = await _db
        .from('yt_video_progress')
        .select('video_id')
        .eq('user_id', userId)
        .eq('completed', true)
        .inFilter('video_id', ids);
    return (prog as List).length;
  }

  Future<void> updateWatchProgress(String userId, String videoId, int seconds) async {
    await _db.from('yt_video_progress').upsert({
      'user_id': userId,
      'video_id': videoId,
      'watched_seconds': seconds,
      'last_watched_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,video_id');
  }

  Future<void> markVideoCompleted(String userId, String videoId) async {
    await _db.from('yt_video_progress').upsert({
      'user_id': userId,
      'video_id': videoId,
      'completed': true,
      'watched_seconds': 999999,
      'last_watched_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,video_id');
  }

  Future<bool> toggleYtBookmark(String userId, String videoId, bool currentlyBookmarked) async {
    if (currentlyBookmarked) {
      await _db
          .from('yt_video_bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('video_id', videoId);
      return false;
    }
    await _db.from('yt_video_bookmarks').upsert({
      'user_id': userId,
      'video_id': videoId,
    }, onConflict: 'user_id,video_id');
    return true;
  }

  Future<List<YtVideo>> getBookmarkedVideos(String userId) async {
    final rows = await _db
        .from('yt_video_bookmarks')
        .select('video_id, yt_videos(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) {
      final v = Map<String, dynamic>.from(r['yt_videos'] as Map);
      v['yt_video_bookmarks'] = [{'id': r['video_id']}];
      return YtVideo.fromJson(v);
    }).where((v) => isVisibleVideo(
          title: v.title,
          description: v.description,
          playlistId: v.playlistId,
          channelId: v.channelId,
        )).toList();
  }

  Future<Map<String, int>> getSubjectVideoCounts() async {
    final rows = await _db
        .from('yt_playlists')
        .select('id, channel_id, subject, title, description, video_count')
        .eq('is_available', true);
    final counts = <String, int>{};
    for (final r in rows as List) {
      final sub = (r['subject'] as String?) ?? 'general';
      final title = (r['title'] as String?) ?? '';
      final desc = r['description'] as String?;
      final playlistId = (r['id'] as String?) ?? '';
      final channelId = r['channel_id'] as String?;
      if (!isVisibleForSubject(
        subject: sub,
        title: title,
        description: desc,
        playlistId: playlistId,
        channelId: channelId,
      )) {
        continue;
      }
      counts[sub] = (counts[sub] ?? 0) + ((r['video_count'] as int?) ?? 0);
    }
    return counts;
  }

  Future<LibraryWatchStatus> getWatchStatus() async {
    try {
      final result = await _db.rpc('get_library_watch_status');
      final map = Map<String, dynamic>.from(result as Map);
      return LibraryWatchStatus.fromJson({
        'allowed': true,
        ...map,
      });
    } catch (e) {
      debugPrint('[LibraryRepository] getWatchStatus failed: $e');
      return LibraryWatchStatus.guest();
    }
  }

  Future<LibraryWatchStatus> recordLibraryWatch(String videoId) async {
    try {
      final result = await _db.rpc('record_library_watch', params: {
        'p_video_id': videoId,
      });
      return LibraryWatchStatus.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (e) {
      debugPrint('[LibraryRepository] recordLibraryWatch failed: $e');
      return const LibraryWatchStatus(
        allowed: false,
        count: kLibraryDailyVideoLimit,
        limit: kLibraryDailyVideoLimit,
        remaining: 0,
        reason: 'error',
      );
    }
  }

  /// Adapter so existing player screen can play synced YouTube content.
  LibraryVideo toLibraryVideo(YtVideo v, {required String topic, String channelName = ''}) {
    return LibraryVideo(
      id: v.id,
      youtubeId: v.id,
      title: v.title,
      description: v.description,
      channelName: channelName,
      topic: ytSubjectLabel(topic),
      tags: const [],
      durationSeconds: v.durationSeconds,
      isFeatured: false,
      isPublished: true,
      viewCount: 0,
      sortOrder: v.position,
      createdAt: v.publishedAt ?? DateTime.now(),
    );
  }
}
