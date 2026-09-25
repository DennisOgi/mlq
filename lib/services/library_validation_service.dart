import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Validates YouTube video IDs via the public oEmbed endpoint.
/// Only caches confirmed invalid IDs — network errors fail open so the catalog stays full.
class LibraryValidationService {
  LibraryValidationService._();
  static final LibraryValidationService instance = LibraryValidationService._();

  static const _cacheInvalidKey = 'library_yt_invalid_cache_v2';

  final Map<String, bool> _memory = {};

  /// True only when a video was previously confirmed broken (e.g. playback error).
  Future<bool> isKnownInvalid(String youtubeId) async {
    if (youtubeId.trim().isEmpty) return true;
    if (_memory.containsKey(youtubeId)) return !_memory[youtubeId]!;

    final prefs = await SharedPreferences.getInstance();
    final invalid = prefs.getStringList(_cacheInvalidKey) ?? [];
    final knownInvalid = invalid.contains(youtubeId);
    _memory[youtubeId] = !knownInvalid;
    return knownInvalid;
  }

  Future<void> markInvalid(String youtubeId) async {
    if (youtubeId.trim().isEmpty) return;
    _memory[youtubeId] = false;
    final prefs = await SharedPreferences.getInstance();
    final invalid = prefs.getStringList(_cacheInvalidKey) ?? [];
    if (!invalid.contains(youtubeId)) {
      invalid.add(youtubeId);
      await prefs.setStringList(_cacheInvalidKey, invalid);
    }
  }

  /// Optional admin pre-check. Network failures return true (assume available).
  Future<bool> isYoutubeIdAvailable(String youtubeId) async {
    if (youtubeId.trim().isEmpty) return false;
    if (await isKnownInvalid(youtubeId)) return false;
    return _checkOembed(youtubeId);
  }

  Future<bool> _checkOembed(String youtubeId) async {
    final uri = Uri.parse(
      'https://www.youtube.com/oembed'
      '?url=${Uri.encodeComponent('https://www.youtube.com/watch?v=$youtubeId')}'
      '&format=json',
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return true;
      if (res.statusCode == 404 || res.statusCode == 401) {
        await markInvalid(youtubeId);
        return false;
      }
      // Rate limits / transient errors — don't hide curated content.
      return true;
    } catch (e) {
      debugPrint('[LibraryValidation] oEmbed skipped for $youtubeId: $e');
      return true;
    }
  }
}
