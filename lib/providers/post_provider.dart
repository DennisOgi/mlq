import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/content_moderation_service.dart';
import '../services/supabase_service.dart';
import '../services/badge_service.dart';

class CommentAddResult {
  final bool success; // true if saved on server
  final bool offlineSaved; // true if only saved locally
  final String? message;

  const CommentAddResult(
      {required this.success, required this.offlineSaved, this.message});
}

class PostProvider extends ChangeNotifier {
  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  int _currentPage = 0;
  static const int _postsPerPage = 20;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  String? _lastError;
  final _supabaseService = SupabaseService.instance;
  StreamSubscription<AuthState>? _authSub;

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  String? get lastError => _lastError;
  final Set<String> _profileWarned = <String>{};

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  PostProvider() {
    _initializePosts();
    _listenToAuthChanges();
  }

  // New: Add a comment with a richer result indicating where it was saved
  Future<CommentAddResult> addCommentV2(
      String postId, CommentModel comment) async {
    bool savedOnServer = false;
    try {
      // Check authentication more thoroughly
      final currentUser = _supabaseService.currentUser;
      debugPrint(
          'addCommentV2: isAuthenticated=${_supabaseService.isAuthenticated}, user=${currentUser?.email}');

      if (_supabaseService.isAuthenticated && currentUser != null) {
        await _supabaseService.client.from('post_comments').insert({
          'id': comment.id,
          'post_id': postId,
          'user_id': comment.userId,
          'content': comment.content,
          'created_at': comment.createdAt.toIso8601String(),
        });
        savedOnServer = true;
        debugPrint(
            '✅ Comment added to database successfully: ${comment.content}');
      } else {
        debugPrint(
            '⚠️ User not authenticated, cannot save comment to database');
      }

      // Update local state (always)
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final comments = List<CommentModel>.from(post.comments);
        comments.add(comment);
        _posts[index] = post.copyWith(comments: comments);
        notifyListeners();
      }

      return CommentAddResult(
        success: savedOnServer,
        offlineSaved: !savedOnServer,
        message: savedOnServer ? 'saved_remote' : 'saved_local',
      );
    } catch (e) {
      debugPrint('❌ Error adding comment (V2): $e');
      // Fallback: still add locally
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final comments = List<CommentModel>.from(post.comments);
        comments.add(comment);
        _posts[index] = post.copyWith(comments: comments);
        notifyListeners();
      }
      return const CommentAddResult(
          success: false, offlineSaved: true, message: 'saved_local');
    }
  }

  Future<void> _initializePosts() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to fetch posts from database first
      if (_supabaseService.isAuthenticated) {
        await _fetchPostsFromDatabase();
      } else {
        // Do not use mock posts when unauthenticated to avoid leakage/confusion
        _posts = [];
        debugPrint('Posts cleared - user not authenticated');
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _lastError = 'Failed to load posts. Please check your connection.';
      // On error, keep current or empty state (no mock)
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch posts from Supabase database with pagination
  Future<void> _fetchPostsFromDatabase({bool loadMore = false, bool ignoreCache = false}) async {
    try {
      // Check cache validity for initial load
      if (!loadMore && _lastFetchTime != null && !ignoreCache) {
        final cacheAge = DateTime.now().difference(_lastFetchTime!);
        if (cacheAge < _cacheValidDuration && _posts.isNotEmpty) {
          debugPrint('Using cached posts (age: ${cacheAge.inMinutes}min)');
          return;
        }
      }

      final offset = loadMore ? _currentPage * _postsPerPage : 0;
      
      // 1) Fetch posts with nested comments and likes only (no profile joins)
      // PAGINATION: Fetch posts per page with offset
      final response = await _supabaseService.client.from('posts').select('''
            id,
            user_id,
            content,
            created_at,
            post_comments(
              id,
              user_id,
              content,
              created_at
            ),
            post_likes(user_id)
          ''').order('created_at', ascending: false)
          .range(offset, offset + _postsPerPage - 1);

      final List<dynamic> rows = (response as List<dynamic>);

      // 2) Collect all user IDs (post owners and commenters)
      final Set<String> userIds = {
        ...rows.map((p) => p['user_id'] as String),
        ...rows.expand((p) => (p['post_comments'] as List? ?? [])
            .map((c) => c['user_id'] as String))
      };

      // 3) Fetch profiles in a single query with retry logic
      Map<String, dynamic> profileMap = {};
      if (userIds.isNotEmpty) {
        try {
          final profilesResp = await _supabaseService.client
              .from('profiles')
              .select('id, name, avatar_url, school_id')
              .inFilter('id', userIds.toList());

          profileMap = {
            for (final p in (profilesResp as List)) (p['id'] as String): p
          };

          // Debug logs to trace profile resolution issues
          debugPrint(
              '[VictoryWall] Fetched posts: ${rows.length}, unique userIds: ${userIds.length}, profiles fetched: ${profileMap.length}');
          if (profileMap.length < userIds.length) {
            final missing = userIds
                .where((id) => !profileMap.containsKey(id))
                .take(10)
                .toList();
            debugPrint(
                '[VictoryWall] Missing profiles for userIds (sample up to 10): $missing');

            // Retry fetching missing profiles individually
            for (final missingId in missing.take(5)) {
              try {
                final singleProfile = await _supabaseService.client
                    .from('profiles')
                    .select('id, name, avatar_url, school_id')
                    .eq('id', missingId)
                    .maybeSingle();

                if (singleProfile != null) {
                  profileMap[missingId] = singleProfile;
                  debugPrint(
                      '[VictoryWall] Retrieved missing profile: $missingId -> ${singleProfile['name']}');
                } else {
                  debugPrint(
                      '[VictoryWall] Profile not found for ID: $missingId');
                }
              } catch (e) {
                debugPrint(
                    '[VictoryWall] Error fetching individual profile $missingId: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[VictoryWall] Error fetching profiles: $e');
          // Continue with empty profileMap - will show "Unknown User"
        }
      }

      // 4) Build PostModel list with resolved names
      final newPosts = rows.map((postData) {
        // Map comments
        final comments = (postData['post_comments'] as List? ?? [])
            .map((commentData) => CommentModel(
                  id: commentData['id'],
                  userId: commentData['user_id'],
                  userName: (profileMap[commentData['user_id']]?['name']
                          as String?) ??
                      'Unknown',
                  content: commentData['content'],
                  createdAt: DateTime.parse(commentData['created_at']),
                ))
            .toList();

        // Map likes
        final likedByUserIds = (postData['post_likes'] as List? ?? [])
            .map((likeData) => likeData['user_id'] as String)
            .toList();

        final postOwnerProfile = profileMap[postData['user_id']];
        if (postOwnerProfile == null && !_profileWarned.contains(postData['user_id'])) {
          debugPrint('[VictoryWall] Missing profile for post ${postData['id']} owner ${postData['user_id']}');
          _profileWarned.add(postData['user_id']);
        }

        return PostModel(
          id: postData['id'],
          userId: postData['user_id'],
          userName: (postOwnerProfile?['name'] as String?) ?? 'Unknown User',
          schoolId: postOwnerProfile?['school_id'] as String?,
          content: postData['content'],
          createdAt: DateTime.parse(postData['created_at']),
          likedByUserIds: likedByUserIds,
          comments: comments,
        );
      }).toList();

      // Update pagination state
      if (loadMore) {
        _posts.addAll(newPosts);
        _currentPage++;
      } else {
        _posts = newPosts;
        _currentPage = 1;
      }

      // Check if there are more posts to load
      _hasMorePosts = newPosts.length >= _postsPerPage;
      _lastFetchTime = DateTime.now();

      debugPrint('Loaded ${newPosts.length} posts (total: ${_posts.length}, page: $_currentPage, hasMore: $_hasMorePosts)');
    } catch (e) {
      debugPrint('Error fetching posts from database: $e');
      rethrow;
    }
  }

  void _listenToAuthChanges() {
    // Reset/refresh posts when auth state changes to prevent cross-user leakage
    _authSub = _supabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      switch (event) {
        case AuthChangeEvent.signedOut:
          _posts = [];
          notifyListeners();
          break;
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          maybeRefreshPosts(minAge: const Duration(seconds: 30));
          break;
        default:
          break;
      }
    });
  }

  // Rate limiting: Check if user can post (5 minute cooldown)
  Future<Map<String, dynamic>> _checkRateLimit(String userId) async {
    try {
      // Get user's most recent post
      final response = await _supabaseService.client
          .from('posts')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final lastPostTime = DateTime.parse(response[0]['created_at']);
        final timeSinceLastPost = DateTime.now().difference(lastPostTime);

        // 5 minute cooldown
        const cooldownMinutes = 5;
        if (timeSinceLastPost.inMinutes < cooldownMinutes) {
          final remainingMinutes =
              cooldownMinutes - timeSinceLastPost.inMinutes;
          return {
            'allowed': false,
            'message':
                'Please wait $remainingMinutes ${remainingMinutes == 1 ? "minute" : "minutes"} before posting again.',
          };
        }
      }

      return {'allowed': true};
    } catch (e) {
      debugPrint('Error checking rate limit: $e');
      // On error, allow the post (fail open)
      return {'allowed': true};
    }
  }

  // Refresh posts from data source (resets pagination)
  Future<void> refreshPosts() async {
    _isLoading = true;
    _currentPage = 0;
    _hasMorePosts = true;
    _lastFetchTime = null; // Invalidate cache
    notifyListeners();

    try {
      if (_supabaseService.isAuthenticated) {
        await _fetchPostsFromDatabase(loadMore: false);
        debugPrint('Refreshed ${_posts.length} posts from database');
      } else {
        // Keep empty when unauthenticated
        _posts = [];
        debugPrint('Posts cleared on refresh - user not authenticated');
      }
    } catch (e) {
      debugPrint('Error refreshing posts: $e');
      _lastError = 'Failed to refresh posts. Please try again.';
      // On error, avoid filling with mock
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> maybeRefreshPosts({
    Duration minAge = const Duration(seconds: 60),
    bool silent = true,
  }) async {
    try {
      if (_lastFetchTime != null) {
        final age = DateTime.now().difference(_lastFetchTime!);
        if (age < minAge) {
          return false;
        }
      }

      if (!_supabaseService.isAuthenticated) {
        return false;
      }

      if (silent) {
        await _fetchPostsFromDatabase(loadMore: false, ignoreCache: true);
        notifyListeners();
      } else {
        await refreshPosts();
      }
      return true;
    } catch (e) {
      debugPrint('Error maybe refreshing posts: $e');
      return false;
    }
  }

  // Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || !_supabaseService.isAuthenticated) {
      debugPrint('Cannot load more: loading=$_isLoadingMore, hasMore=$_hasMorePosts, auth=${_supabaseService.isAuthenticated}');
      return;
    }

    _isLoadingMore = true;
    _lastError = null; // Clear previous errors
    notifyListeners();

    try {
      await _fetchPostsFromDatabase(loadMore: true);
      debugPrint('Loaded more posts (total: ${_posts.length})');
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      _lastError = 'Failed to load more posts. Please try again.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Add a new post with content moderation and rate limiting
  Future<Map<String, dynamic>> addPost(PostModel post) async {
    // Check rate limiting (5 minutes between posts)
    final rateLimitCheck = await _checkRateLimit(post.userId);
    if (!rateLimitCheck['allowed']) {
      return {
        'success': false,
        'message': rateLimitCheck['message'],
      };
    }

    // Check content for inappropriate language
    final moderationService = ContentModerationService.instance;
    final validationMessage = moderationService.validateContent(post.content);

    if (validationMessage != null) {
      // Content was rejected
      return {
        'success': false,
        'message': validationMessage,
      };
    }

    // Content passed moderation, add post
    try {
      // Save to database if authenticated
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.client.from('posts').insert({
          'id': post.id,
          'user_id': post.userId,
          'content': post.content,
          'created_at': post.createdAt.toIso8601String(),
        });

        debugPrint('Post saved to database: ${post.content}');
      }

      // Update local state
      _posts.add(post);
      _posts.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
      notifyListeners();

      // Trigger badge checks for Victory Wall achievements
      try {
        await BadgeService().checkForAchievements();
      } catch (e) {
        debugPrint('Badge evaluation after post creation failed: $e');
      }

      return {
        'success': true,
        'post': post,
      };
    } catch (e) {
      debugPrint('Error adding post: $e');
      return {
        'success': false,
        'message': 'Failed to save post. Please try again.',
      };
    }
  }

  // Old deletePost method removed - replaced with admin-only version below

  // Like a post
  Future<void> likePost(String postId, String userId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final likedByUserIds = List<String>.from(post.likedByUserIds);
      final isCurrentlyLiked = likedByUserIds.contains(userId);

      try {
        // Update database if authenticated
        if (_supabaseService.isAuthenticated) {
          if (isCurrentlyLiked) {
            // Unlike - remove from database
            await _supabaseService.client
                .from('post_likes')
                .delete()
                .eq('post_id', postId)
                .eq('user_id', userId);

            debugPrint('Post unliked in database: $postId');
          } else {
            // Like - add to database
            await _supabaseService.client.from('post_likes').insert({
              'post_id': postId,
              'user_id': userId,
            });

            debugPrint('Post liked in database: $postId');
          }
        }

        // Update local state
        if (isCurrentlyLiked) {
          likedByUserIds.remove(userId); // Unlike
        } else {
          likedByUserIds.add(userId); // Like
        }

        _posts[index] = post.copyWith(likedByUserIds: likedByUserIds);
        notifyListeners();
      } catch (e) {
        debugPrint('Error updating like status: $e');
        // Still update local state even if database update fails
        if (isCurrentlyLiked) {
          likedByUserIds.remove(userId);
        } else {
          likedByUserIds.add(userId);
        }
        _posts[index] = post.copyWith(likedByUserIds: likedByUserIds);
        notifyListeners();
      }
    }
  }

  // Add a comment to a post
  Future<bool> addComment(String postId, CommentModel comment) async {
    try {
      // Add comment to database if authenticated
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.client.from('post_comments').insert({
          'id': comment.id,
          'post_id': postId,
          'user_id': comment.userId,
          'content': comment.content,
          'created_at': comment.createdAt.toIso8601String(),
        });

        debugPrint('Comment added to database: ${comment.content}');
      }

      // Update local state
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final comments = List<CommentModel>.from(post.comments);
        comments.add(comment);

        _posts[index] = post.copyWith(comments: comments);
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error adding comment: $e');

      // Still add to local state as fallback
      final index = _posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final comments = List<CommentModel>.from(post.comments);
        comments.add(comment);

        _posts[index] = post.copyWith(comments: comments);
        notifyListeners();
      }

      return false;
    }
  }

  // Get post by ID
  PostModel? getPostById(String postId) {
    try {
      return _posts.firstWhere((post) => post.id == postId);
    } catch (e) {
      return null;
    }
  }

  // Get posts by user ID
  List<PostModel> getPostsByUserId(String userId) {
    return _posts.where((post) => post.userId == userId).toList();
  }

  // Explicitly clear posts (can be called by other providers if needed)
  void clearPosts() {
    _posts = [];
    notifyListeners();
  }

  /// Delete a post (admin only)
  /// Returns true if successful, false otherwise
  Future<bool> deletePost(String postId, {required bool isAdmin}) async {
    if (!isAdmin) {
      debugPrint('❌ Unauthorized: Only admins can delete posts');
      _lastError = 'Unauthorized: Only admins can delete posts';
      notifyListeners();
      return false;
    }

    try {
      // Delete from database if authenticated
      if (_supabaseService.isAuthenticated) {
        // Delete comments first (foreign key constraint)
        await _supabaseService.client
            .from('post_comments')
            .delete()
            .eq('post_id', postId);

        // Delete likes
        await _supabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', postId);

        // Delete the post
        await _supabaseService.client
            .from('posts')
            .delete()
            .eq('id', postId);

        debugPrint('✅ Post deleted from database: $postId');
      }

      // Remove from local state
      _posts.removeWhere((post) => post.id == postId);
      notifyListeners();

      debugPrint('✅ Post deleted successfully: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      _lastError = 'Failed to delete post. Please try again.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
