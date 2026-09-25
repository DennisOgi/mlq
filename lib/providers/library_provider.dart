import 'package:flutter/foundation.dart';

import '../models/library_watch_limit.dart';
import '../models/library_video_model.dart';
import '../models/yt_library_models.dart';
import '../repositories/library_repository.dart';
import '../services/library_service.dart';

enum LibraryStatus { initial, loading, ready, error }

class LibraryProvider extends ChangeNotifier {
  final LibraryService _legacy = LibraryService.instance;
  final LibraryRepository _repo = LibraryRepository.instance;

  LibraryStatus _status = LibraryStatus.initial;
  String? _error;

  // YouTube-synced catalog (whitelist only — flat, no subject tabs)
  List<YtPlaylist> _playlists = [];
  List<LibraryVideo> _previewVideos = [];
  int _whitelistedVideoCount = 0;

  // Legacy (unused in UI; kept for bookmark RPC compatibility)
  List<LibraryVideo> _legacyVideos = [];
  List<LibraryVideo> _filtered = [];
  Set<String> _bookmarkedIds = {};
  List<YtVideo> _ytBookmarked = [];

  String _searchQuery = '';
  bool _searchActive = false;
  List<YtVideo> _searchResults = [];
  LibraryWatchStatus? _watchStatus;

  LibraryStatus get status => _status;
  String? get error => _error;
  List<String> get subjects => const [];
  String get activeSubject => 'general';
  List<YtPlaylist> get playlists => _playlists;
  List<YtPlaylist> get featuredPlaylists => const [];
  Map<String, int> get subjectCounts => const {};
  List<LibraryVideo> get previewVideos => _previewVideos;
  LibraryVideo? get featured => null;
  List<LibraryVideo> get all => _previewVideos;
  List<LibraryVideo> get filtered => _filtered;
  List<YtVideo> get searchResults => _searchResults;
  Set<String> get bookmarkedIds => _bookmarkedIds;
  List<YtVideo> get ytBookmarked => _ytBookmarked;
  String get searchQuery => _searchQuery;
  bool get searchActive => _searchActive;
  bool get usesYoutubeCatalog => true;
  LibraryWatchStatus? get watchStatus => _watchStatus;
  int get dailyVideosRemaining => _watchStatus?.remaining ?? kLibraryDailyVideoLimit;

  int get totalCount => _whitelistedVideoCount > 0 ? _whitelistedVideoCount : _previewVideos.length;

  List<String> get availableTopics => const ['All'];

  String get activeTopic => 'All';

  bool isBookmarked(String videoId) => _bookmarkedIds.contains(videoId);

  DateTime? _lastLoadedAt;
  static const _staleAfter = Duration(hours: 6);

  Future<void> loadIfStale({String? userId}) async {
    if (_status == LibraryStatus.initial ||
        _lastLoadedAt == null ||
        DateTime.now().difference(_lastLoadedAt!) > _staleAfter) {
      await load(userId: userId);
    }
  }

  Future<void> load({String? userId}) async {
    if (_status == LibraryStatus.loading) return;
    _status = LibraryStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _playlists = await _repo.getAllWhitelistedPlaylists();
      _whitelistedVideoCount = await _repo.getWhitelistedVideoCount();
      _previewVideos = await _repo.getWhitelistedPreviewVideos(limit: 8);

      if (_playlists.isEmpty) {
        await _repo.requestYoutubeSync();
        await Future.delayed(const Duration(seconds: 2));
        _playlists = await _repo.getAllWhitelistedPlaylists();
        _whitelistedVideoCount = await _repo.getWhitelistedVideoCount();
        _previewVideos = await _repo.getWhitelistedPreviewVideos(limit: 8);
      }

      if (userId != null) {
        _bookmarkedIds = await _legacy.getBookmarkedIds(userId);
        _ytBookmarked = await _repo.getBookmarkedVideos(userId);
        for (final v in _ytBookmarked) {
          _bookmarkedIds.add(v.id);
        }
        _watchStatus = await _repo.getWatchStatus();
      } else {
        _bookmarkedIds = {};
        _ytBookmarked = [];
      }

      _legacyVideos = [];
      _filtered = [];
      _status = LibraryStatus.ready;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = 'Could not load library. Please try again.';
      _status = LibraryStatus.error;
      debugPrint('[Library] load error: $e');
    }
    notifyListeners();
  }

  Future<void> refresh({String? userId}) async {
    _status = LibraryStatus.initial;
    await _repo.requestYoutubeSync(force: true);
    await load(userId: userId);
  }

  Future<void> setSubject(String subjectKey) async {}

  void setTopic(String topic) {}

  Future<List<YtVideo>> getPlaylistVideos(
    String playlistId,
    String userId, {
    String? subject,
  }) =>
      _repo.getVideosForPlaylist(
        playlistId,
        userId,
        subject: subject,
      );

  Future<int> getPlaylistCompletedCount(String userId, String playlistId) =>
      _repo.getCompletedCount(userId, playlistId);

  LibraryVideo toPlayable(YtVideo v, {required String topic, String channel = ''}) =>
      _repo.toLibraryVideo(v, topic: topic, channelName: channel);

  void setSearch(String query) async {
    _searchQuery = query;
    if (query.trim().length >= 2) {
      _searchResults = await _repo.searchVideos(query);
    } else {
      _searchResults = [];
    }
    _applyFilter();
    notifyListeners();
  }

  void setSearchActive(bool active) {
    _searchActive = active;
    if (!active) {
      _searchQuery = '';
      _searchResults = [];
      _applyFilter();
    }
    notifyListeners();
  }

  void _applyFilter() {
    var list = _legacyVideos;
    if (_searchQuery.trim().isNotEmpty) {
      final needle = _searchQuery.trim().toLowerCase();
      list = list.where((v) {
        return v.title.toLowerCase().contains(needle) ||
            v.channelName.toLowerCase().contains(needle) ||
            v.topic.toLowerCase().contains(needle);
      }).toList();
    }
    _filtered = list;
  }

  Future<void> toggleBookmark(String videoId, String userId, {bool isYt = true}) async {
    final was = _bookmarkedIds.contains(videoId);
    if (was) {
      _bookmarkedIds.remove(videoId);
      _ytBookmarked.removeWhere((v) => v.id == videoId);
    } else {
      _bookmarkedIds.add(videoId);
    }
    notifyListeners();

    if (isYt) {
      await _repo.toggleYtBookmark(userId, videoId, was);
    } else {
      await _legacy.toggleBookmark(
        userId: userId,
        videoId: videoId,
        currentlyBookmarked: was,
      );
    }
  }

  Future<void> updateProgress(String userId, String videoId, int seconds, int duration) async {
    await _repo.updateWatchProgress(userId, videoId, seconds);
    if (duration > 0 && seconds / duration >= 0.85) {
      await _repo.markVideoCompleted(userId, videoId);
    }
  }

  Future<LibraryWatchStatus> tryStartWatch(String userId, String videoId) async {
    final status = await _repo.recordLibraryWatch(videoId);
    _watchStatus = status;
    notifyListeners();
    return status;
  }

  Future<void> refreshWatchStatus() async {
    _watchStatus = await _repo.getWatchStatus();
    notifyListeners();
  }

  void trackView(String videoId) {
    if (_legacyVideos.any((v) => v.id == videoId)) {
      _legacy.incrementView(videoId);
    }
  }

  void clearState() {
    _status = LibraryStatus.initial;
    _playlists = [];
    _previewVideos = [];
    _whitelistedVideoCount = 0;
    _legacyVideos = [];
    _filtered = [];
    _bookmarkedIds = {};
    _ytBookmarked = [];
    _searchQuery = '';
    _searchActive = false;
    _lastLoadedAt = null;
    _error = null;
    notifyListeners();
  }
}
