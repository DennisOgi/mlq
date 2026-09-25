import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/library_video_model.dart';

class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final SupabaseClient _db = Supabase.instance.client;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<List<LibraryVideo>> getVideos({
    String? topic,
    String? search,
    int limit = 200,
  }) async {
    try {
      var filter = _db.from('library_videos').select().eq('is_published', true);

      if (topic != null && topic != 'All') {
        filter = filter.eq('topic', topic);
      }

      final rows = await filter
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .limit(limit);
      var videos = (rows as List)
          .map((r) => LibraryVideo.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      if (search != null && search.trim().isNotEmpty) {
        final needle = search.trim().toLowerCase();
        videos = videos.where((v) {
          return v.title.toLowerCase().contains(needle) ||
              v.channelName.toLowerCase().contains(needle) ||
              v.topic.toLowerCase().contains(needle) ||
              v.tags.any((t) => t.toLowerCase().contains(needle)) ||
              (v.description ?? '').toLowerCase().contains(needle);
        }).toList();
      }

      return videos;
    } catch (e) {
      debugPrint('[Library] getVideos error: $e');
      rethrow;
    }
  }

  Future<LibraryVideo?> getFeaturedVideo() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows = await _db
          .from('library_videos')
          .select()
          .eq('is_published', true)
          .eq('is_featured', true)
          .eq('featured_date', today)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows is List && rows.isNotEmpty) {
        return LibraryVideo.fromJson(Map<String, dynamic>.from(rows.first));
      }

      // Fallback: pick the newest featured video regardless of date
      final fallback = await _db
          .from('library_videos')
          .select()
          .eq('is_published', true)
          .eq('is_featured', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (fallback != null) {
        return LibraryVideo.fromJson(Map<String, dynamic>.from(fallback));
      }
      return null;
    } catch (e) {
      debugPrint('[Library] getFeaturedVideo error: $e');
      return null;
    }
  }

  /// Videos added in the last [days] days — powers the "New in Library" shelf.
  Future<List<LibraryVideo>> getRecentVideos({int days = 14, int limit = 12}) async {
    try {
      final since =
          DateTime.now().subtract(Duration(days: days)).toIso8601String();
      final rows = await _db
          .from('library_videos')
          .select()
          .eq('is_published', true)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => LibraryVideo.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[Library] getRecentVideos error: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableTopics() async {
    try {
      final rows = await _db
          .from('library_videos')
          .select('topic')
          .eq('is_published', true);
      final topics = (rows as List)
          .map((r) => r['topic'].toString())
          .toSet()
          .toList()
        ..sort();
      return topics;
    } catch (e) {
      debugPrint('[Library] getAvailableTopics error: $e');
      return [];
    }
  }

  Future<List<LibraryVideo>> getRelated(LibraryVideo video,
      {int limit = 8}) async {
    try {
      final rows = await _db
          .from('library_videos')
          .select()
          .eq('is_published', true)
          .eq('topic', video.topic)
          .neq('id', video.id)
          .order('view_count', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => LibraryVideo.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[Library] getRelated error: $e');
      return [];
    }
  }

  // ── Interactions ───────────────────────────────────────────────────────────

  Future<void> incrementView(String videoId) async {
    try {
      await _db.rpc('increment_video_view_count', params: {'p_video_id': videoId});
    } catch (e) {
      debugPrint('[Library] incrementView error: $e');
    }
  }

  Future<Set<String>> getBookmarkedIds(String userId) async {
    try {
      final rows = await _db
          .from('user_video_bookmarks')
          .select('video_id')
          .eq('user_id', userId);
      return (rows as List).map((r) => r['video_id'].toString()).toSet();
    } catch (e) {
      debugPrint('[Library] getBookmarkedIds error: $e');
      return {};
    }
  }

  Future<bool> toggleBookmark({
    required String userId,
    required String videoId,
    required bool currentlyBookmarked,
  }) async {
    try {
      if (currentlyBookmarked) {
        await _db
            .from('user_video_bookmarks')
            .delete()
            .eq('user_id', userId)
            .eq('video_id', videoId);
        return false;
      } else {
        await _db.from('user_video_bookmarks').upsert({
          'user_id': userId,
          'video_id': videoId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('[Library] toggleBookmark error: $e');
      return currentlyBookmarked;
    }
  }

  Future<List<LibraryVideo>> getBookmarkedVideos(String userId) async {
    try {
      final rows = await _db
          .from('user_video_bookmarks')
          .select('library_videos(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List).map((r) {
        final v = r['library_videos'];
        return LibraryVideo.fromJson(Map<String, dynamic>.from(v));
      }).toList();
    } catch (e) {
      debugPrint('[Library] getBookmarkedVideos error: $e');
      return [];
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  Future<List<LibraryVideo>> getAllVideosAdmin() async {
    final rows = await _db
        .from('library_videos')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LibraryVideo.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<LibraryVideo> createVideo(LibraryVideo video) async {
    final row = await _db
        .from('library_videos')
        .insert(video.toJson())
        .select()
        .single();
    return LibraryVideo.fromJson(Map<String, dynamic>.from(row));
  }

  Future<LibraryVideo> updateVideo(LibraryVideo video) async {
    final row = await _db
        .from('library_videos')
        .update({...video.toJson(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', video.id)
        .select()
        .single();
    return LibraryVideo.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteVideo(String id) async {
    await _db.from('library_videos').delete().eq('id', id);
  }

  /// Soft-unpublish a video that failed YouTube availability checks.
  Future<void> unpublishIfInvalid(String id) async {
    try {
      await _db.from('library_videos').update({
        'is_published': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('[Library] unpublishIfInvalid error: $e');
    }
  }

  Future<void> setFeatured(String id, {bool featured = true, String? date}) async {
    final today = date ?? DateTime.now().toIso8601String().split('T').first;
    // Unset any existing featured on same date first
    if (featured) {
      await _db
          .from('library_videos')
          .update({'is_featured': false, 'featured_date': null})
          .eq('featured_date', today);
    }
    await _db.from('library_videos').update({
      'is_featured': featured,
      'featured_date': featured ? today : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
