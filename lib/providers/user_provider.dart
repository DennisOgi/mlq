import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/models.dart';
import '../utils/error_handler.dart';
import '../services/supabase_service.dart';
import '../services/offline_persistence_service.dart';
import '../services/push_notification_service.dart';

enum LeaderboardView { global, school }

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  List<BadgeModel> _badges = [];
  List<UserModel> _leaderboardUsers = [];
  List<UserModel> _schoolLeaderboardUsers = [];
  bool _isFirstTimeUser = true;
  bool _isAuthenticated = false;
  List<AvatarModel> _unlockedAvatars = [];
  LeaderboardView _leaderboardView = LeaderboardView.global;
  List<Map<String, dynamic>> _schools = [];
  String? _lastErrorMessage;
  
  // Supabase service instance
  final _supabaseService = SupabaseService();
  
  // Offline persistence service
  final _offlineService = OfflinePersistenceService();

  UserModel? get user => _user;
  List<BadgeModel> get badges => _badges;
  List<UserModel> get leaderboardUsers => _leaderboardUsers;
  List<UserModel> get schoolLeaderboardUsers => _schoolLeaderboardUsers;
  bool get isFirstTimeUser => _isFirstTimeUser;
  bool get isAuthenticated => _isAuthenticated;
  List<AvatarModel> get unlockedAvatars => _unlockedAvatars;
  LeaderboardView get leaderboardView => _leaderboardView;
  List<Map<String, dynamic>> get schools => _schools;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Returns the [UserModel] with the given [id] from current caches.
  UserModel? getUserById(String id) {
    if (_user?.id == id) return _user;
    try {
      return _leaderboardUsers.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ===== B2B: Entitlements and Class Code Join =====
  Future<void> refreshEntitlements() async {
    try {
      if (!_supabaseService.isAuthenticated) return;
      final res = await _supabaseService.fetchEntitlements();
      final bool isPremiumFlag = (res['is_premium'] == true);
      if (_user != null && _user!.isPremium != isPremiumFlag) {
        _user = _user!.copyWith(isPremium: isPremiumFlag);
        await _offlineService.cacheUserProfile(_user!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing entitlements: $e');
    }
  }

  Future<bool> joinWithClassCode(String code) async {
    try {
      if (!_supabaseService.isAuthenticated) return false;
      final ok = await _supabaseService.acceptInvitation(code);
      if (ok) {
        await refreshEntitlements();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error joining with class code: $e');
      return false;
    }
  }

  // Leaderboard API used by UI
  Future<void> refreshLeaderboard() async {
    if (_leaderboardView == LeaderboardView.school) {
      await refreshSchoolLeaderboard();
    } else {
      await _fetchLeaderboardUsers();
    }
  }

  List<UserModel> getLeaderboardUsers() {
    final users = _leaderboardView == LeaderboardView.school
        ? _schoolLeaderboardUsers
        : _leaderboardUsers;
    // Limit to top 20 users
    return users.take(20).toList();
  }

  void setLeaderboardView(LeaderboardView view) {
    if (_leaderboardView == view) return;
    _leaderboardView = view;
    notifyListeners();
    // Optionally refresh when switching views
    refreshLeaderboard();
  }

  Future<void> _fetchLeaderboardUsers() async {
    try {
      final users = await _supabaseService.fetchLeaderboardUsers();
      if (users.isNotEmpty) {
        _leaderboardUsers = users;

        // If current user exists in fetched leaderboard, sync profile to latest server values
        // BUT only if the server data is newer (higher XP/coins) to prevent overwriting optimistic updates
        if (_user != null) {
          try {
            final meFromBoard = users.firstWhere((u) => u.id == _user!.id);
            // Only update if server has higher values (prevents overwriting optimistic updates)
            // OR if other fields changed (avatar, name, school)
            final shouldUpdate = meFromBoard.xp > _user!.xp ||
                meFromBoard.coins > _user!.coins ||
                meFromBoard.avatarUrl != _user!.avatarUrl ||
                meFromBoard.name != _user!.name ||
                meFromBoard.schoolId != _user!.schoolId;
            
            if (shouldUpdate) {
              _user = meFromBoard;
              await _offlineService.cacheUserProfile(_user!);
              debugPrint('🔄 Synced current user from leaderboard (XP: ${_user!.xp}, Coins: ${_user!.coins})');
            } else {
              debugPrint('⏭️ Skipped leaderboard sync (local data is newer)');
            }
          } catch (_) {
            // Current user not in top leaderboard list; will handle below
          }
        }

        // Cache the fresh leaderboard data
        await _offlineService.cacheLeaderboard(_leaderboardUsers);
        
        // If current user is authenticated, ensure they're in the leaderboard
        if (_user != null && _isAuthenticated) {
          // Check if current user is already in the list
          final userExists = _leaderboardUsers.any((u) => u.id == _user!.id);
          
          if (!userExists) {
            // Fetch fresh user data to get latest stats
            final freshUserData = await _supabaseService.getUserProfile();
            if (freshUserData != null) {
              _user = freshUserData;
              
              // Update or add current user in leaderboard list
              final userIndex = _leaderboardUsers.indexWhere((u) => u.id == _user!.id);
              if (userIndex >= 0) {
                _leaderboardUsers[userIndex] = _user!;
              } else {
                _leaderboardUsers.add(_user!);
              }
              
              // Re-sort the leaderboard by monthly XP (matches server-side ordering)
              _leaderboardUsers.sort((a, b) => b.monthlyXp.compareTo(a.monthlyXp));
              // Persist updated profile
              await _offlineService.cacheUserProfile(_user!);
            }
          }
          
          debugPrint('✅ Leaderboard refreshed with ${users.length} users');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching leaderboard users: $e');
      // Try to use cached data as fallback
      final cachedLeaderboard = await _offlineService.getCachedLeaderboard();
      if (cachedLeaderboard.isNotEmpty && _leaderboardUsers.isEmpty) {
        _leaderboardUsers = cachedLeaderboard;
        debugPrint('📱 Using cached leaderboard as fallback');
        notifyListeners();
      }
    }
  }

  Future<void> refreshSchoolLeaderboard() async {
    try {
      if (_user?.schoolId == null) {
        _schoolLeaderboardUsers = [];
        notifyListeners();
        return;
      }
      
      // Fetch school leaderboard from server
      final users = await _supabaseService.fetchSchoolLeaderboard(schoolId: _user!.schoolId!);
      if (users.isNotEmpty) {
        _schoolLeaderboardUsers = users;

        // If current user exists in fetched school leaderboard, sync profile to latest server values
        // BUT only if the server data is newer (higher XP/coins) to prevent overwriting optimistic updates
        if (_user != null) {
          try {
            final meFromBoard = users.firstWhere((u) => u.id == _user!.id);
            // Only update if server has higher values (prevents overwriting optimistic updates)
            // OR if other fields changed (avatar, name, school)
            final shouldUpdate = meFromBoard.xp > _user!.xp ||
                meFromBoard.coins > _user!.coins ||
                meFromBoard.avatarUrl != _user!.avatarUrl ||
                meFromBoard.name != _user!.name ||
                meFromBoard.schoolId != _user!.schoolId;
            
            if (shouldUpdate) {
              _user = meFromBoard;
              await _offlineService.cacheUserProfile(_user!);
              debugPrint('🔄 Synced current user from school leaderboard (XP: ${_user!.xp}, Coins: ${_user!.coins})');
            } else {
              debugPrint('⏭️ Skipped school leaderboard sync (local data is newer)');
            }
          } catch (_) {
            // Not present in the returned list; fallback behavior below will handle
          }
        }
      }

      // Ensure current user appears in the school leaderboard even if RPC omits them
      // (e.g., rank beyond limit or zero XP users filtered out server-side)
      if (_user != null) {
        final meId = _user!.id;
        final alreadyIncluded = _schoolLeaderboardUsers.any((u) => u.id == meId);
        if (!alreadyIncluded) {
          try {
            // Fetch fresh profile to ensure latest XP/school state
            final fresh = await _supabaseService.getUserProfile();
            final me = (fresh ?? _user!);
            // Only add if still in the same school context
            if (me.schoolId == _user!.schoolId) {
              _schoolLeaderboardUsers.add(me);
              // Sort by monthly XP desc and compute a rank for display consistency
              _schoolLeaderboardUsers.sort((a, b) => b.monthlyXp.compareTo(a.monthlyXp));
              for (int i = 0; i < _schoolLeaderboardUsers.length; i++) {
                final u = _schoolLeaderboardUsers[i];
                if (u.id == me.id && (u.rank == null || u.rank != i + 1)) {
                  _schoolLeaderboardUsers[i] = u.copyWith(rank: i + 1);
                }
              }
              debugPrint('👤 Added current user to school leaderboard as fallback');
              // Persist updated profile if coming from fresh
              if (fresh != null) {
                _user = fresh;
                await _offlineService.cacheUserProfile(_user!);
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to append current user to school leaderboard: $e');
          }
        }
      }
      
      // Cache the fresh school leaderboard data
      await _offlineService.cacheSchoolLeaderboard(_schoolLeaderboardUsers);
      
      notifyListeners();
      debugPrint('✅ School leaderboard refreshed: ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error fetching school leaderboard: $e');
      // Try to use cached data as fallback
      final cachedSchoolLeaderboard = await _offlineService.getCachedSchoolLeaderboard();
      if (cachedSchoolLeaderboard.isNotEmpty && _schoolLeaderboardUsers.isEmpty) {
        _schoolLeaderboardUsers = cachedSchoolLeaderboard;
        debugPrint('📱 Using cached school leaderboard as fallback');
        notifyListeners();
      }
    }
  }

  // Schools list for dropdowns
  Future<void> loadSchools({bool force = false}) async {
    if (_schools.isNotEmpty && !force) return;
    
    try {
      // Try to load from server first
      final freshSchools = await _supabaseService.fetchSchools();
      _schools = freshSchools;
      
      // Cache the fresh schools data
      await _offlineService.cacheSchools(_schools);
      
      notifyListeners();
      debugPrint('✅ Schools loaded: ${_schools.length} schools');
    } catch (e) {
      debugPrint('❌ Error loading schools: $e');
      // Try to use cached data as fallback
      final cachedSchools = await _offlineService.getCachedSchools();
      if (cachedSchools.isNotEmpty && _schools.isEmpty) {
        _schools = cachedSchools;
        debugPrint('📱 Using cached schools as fallback');
        notifyListeners();
      }
    }
  }

  // Update current user's school
  Future<bool> setUserSchool(String? schoolId) async {
    try {
      String? name;
      if (schoolId != null) {
        // Ensure we have schools cached
        if (_schools.isEmpty) {
          await loadSchools(force: true);
        }
        final found = _schools.firstWhere(
          (s) => s['id'] == schoolId,
          orElse: () => {},
        );
        name = found.isNotEmpty ? (found['name'] as String?) : null;
      }

      final ok = await _supabaseService.updateUserSchool(
        schoolId: schoolId,
        schoolName: name,
      );
      if (ok && _user != null) {
        _user = _user!.copyWith(schoolId: schoolId, schoolName: name);
        notifyListeners();
        if (_leaderboardView == LeaderboardView.school) {
          await refreshSchoolLeaderboard();
        }
      }
      return ok;
    } catch (e) {
      debugPrint('Error setting user school: $e');
      return false;
    }
  }
  /// Quick helper to check if a user is premium.
  bool isPremium(String userId) => getUserById(userId)?.isPremium ?? false;

  /// Check if current user is in trial
  bool get isTrial => _user?.isTrial ?? false;

  /// Get days left in trial
  int get trialDaysLeft {
    if (_user?.trialEndsAt == null) return 0;
    final diff = _user!.trialEndsAt!.difference(DateTime.now());
    return max(0, diff.inDays);
  }

  void deductCoins(int amount) {
    if (_user == null) return;
    _user = _user!.copyWith(
      coins: _user!.coins - amount,
    );
    _saveData();
    notifyListeners();
  }
  
  // Update user model with new data
  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    _saveData();
    notifyListeners();
  }

  /// Refreshes the current user data from the backend
  Future<void> refreshUser() async {
    try {
      if (!_supabaseService.isAuthenticated) return;
      
      final freshUser = await _supabaseService.getUserProfile();
      if (freshUser != null) {
        _user = freshUser;
        await _offlineService.cacheUserProfile(_user!);
        
        // Also refresh entitlements to ensure premium status is up to date
        await refreshEntitlements();
        
        notifyListeners();
        debugPrint('✅ User data refreshed successfully');
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
    }
  }

  // Initialize with user data from Supabase if available
  UserProvider() {
    _initializeUser();
    _loadAvatarData();
  }
  
  // Login method
  Future<bool> login({required String email, required String password}) async {
    try {
      _lastErrorMessage = null;
      final response = await _supabaseService.signIn(email: email, password: password);
      
      if (response.user != null) {
        // Load user profile with fresh data including admin status
        _user = await _supabaseService.getUserProfile();
        _isAuthenticated = true;
        
        // Set hasCompletedRegistration to true since this is a real user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasCompletedRegistration', true);
        await prefs.setBool('isFirstTimeUser', false);
        
        // Load user badges after successful login
        await loadUserBadges();

        // Refresh entitlements (B2B/B2C premium)
        await refreshEntitlements();
        
        // Sync FCM token for push notifications
        try {
          await PushNotificationService.instance.syncFcmToken();
        } catch (e) {
          debugPrint('FCM token sync after login failed: $e');
        }
        
        debugPrint('User logged in successfully: ${_user?.name}');
        notifyListeners();
        return true;
      }
      // No user returned and no exception thrown
      _lastErrorMessage = 'Login failed. Please verify your credentials and try again.';
      return false;
    } catch (e) {
      debugPrint('Error during login: $e');
      _lastErrorMessage = ErrorHandler.toMessage(e);
      return false;
    }
  }
  
  // Logout method
  Future<void> logout() async {
    try {
      await _supabaseService.signOut();
      // Clear in-memory user-scoped caches to avoid cross-account leakage
      _user = null;
      _isAuthenticated = false;
      _badges.clear();
      _leaderboardUsers.clear();
      _schoolLeaderboardUsers.clear();
      _unlockedAvatars.clear();
      _schools.clear();
      // Clear offline caches on disk
      await _offlineService.clearCache();
      
      // Clear FCM token state on logout
      try {
        await PushNotificationService.instance.clearTokenState();
      } catch (e) {
        debugPrint('Error clearing FCM token state: $e');
      }
      
      // Clear goals cache from SharedPreferences to prevent cross-account leakage
      await _clearGoalsCache();
      
      // Clear gratitude entries cache from SharedPreferences
      await _clearGratitudeCache();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  // Clear all goals-related cache from SharedPreferences
  Future<void> _clearGoalsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all goal-related keys (both user-scoped and legacy)
      for (final key in keys) {
        if (key.contains('main_goals') || key.contains('daily_goals')) {
          await prefs.remove(key);
          debugPrint('Cleared goals cache key: $key');
        }
      }
    } catch (e) {
      debugPrint('Error clearing goals cache: $e');
    }
  }

  // Clear all gratitude-related cache from SharedPreferences
  Future<void> _clearGratitudeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Remove all gratitude-related keys (both user-scoped and legacy)
      for (final key in keys) {
        if (key.contains('gratitude_entries')) {
          await prefs.remove(key);
          debugPrint('Cleared gratitude cache key: $key');
        }
      }
    } catch (e) {
      debugPrint('Error clearing gratitude cache: $e');
    }
  }


  
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required int age,
    String? parentEmail,
  }) async {
    try {
      _lastErrorMessage = null;
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
        age: age,
        parentEmail: parentEmail,
      );
      
      if (response.user != null) {
        // Save registration state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasCompletedRegistration', true);
        await prefs.setBool('isFirstTimeUser', false);

        // Clear any stale caches from mock/previous sessions to avoid cross-account leakage
        _badges.clear();
        _leaderboardUsers.clear();
        _schoolLeaderboardUsers.clear();
        _unlockedAvatars.clear();
        _schools.clear();
        await _offlineService.clearCache();

        // Load a fresh user profile and mark as authenticated
        _user = await _supabaseService.getUserProfile();
        _isAuthenticated = _user != null;

        // Load user badges for the new account
        await loadUserBadges();

        // Sync FCM token for push notifications
        try {
          await PushNotificationService.instance.syncFcmToken();
        } catch (e) {
          debugPrint('FCM token sync after registration failed: $e');
        }

        debugPrint('User registered successfully: $email (userId: ${_user?.id})');
        notifyListeners();
        return true;
      }
      _lastErrorMessage =
          'Registration did not complete. Please verify your email or try again.';
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      _lastErrorMessage = ErrorHandler.toMessage(e);
      return false;
    }
  }
  


  Future<void> _initializeUser() async {
    try {
      // Check if first time user
      final prefs = await SharedPreferences.getInstance();
      _isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? true;

      // OFFLINE-FIRST APPROACH: Load cached data immediately
      await _loadCachedData();

      // If we have cached user data, use it while attempting online sync
      if (_user != null && _supabaseService.isAuthenticated) {
        debugPrint('🔄 Using cached data, attempting online sync...');
        _attemptOnlineSync();
        return;
      }

      // Try to load user from Supabase if authenticated and no cached data
      if (_supabaseService.isAuthenticated) {
        try {
          // Attempt to load user profile from Supabase
          final freshUser = await _supabaseService.getUserProfile();
          if (freshUser != null) {
            _user = freshUser;
            _isAuthenticated = true;
            debugPrint('✅ User loaded from Supabase: ${_user?.name}');
            
            // Cache the fresh data
            await _offlineService.cacheUserProfile(_user!);
            
            // Load user badges after successful user load
            await loadUserBadges();

            // Refresh entitlements so premium gates reflect immediately
            await refreshEntitlements();
            
            // Sync FCM token for push notifications (existing session)
            try {
              await PushNotificationService.instance.syncFcmToken();
            } catch (e) {
              debugPrint('FCM token sync during init failed: $e');
            }
            
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint('❌ Failed to load user from Supabase: $e');
          // If we have cached data, continue using it
          if (_user != null) {
            debugPrint('📱 Continuing with cached user data');
            notifyListeners();
            return;
          }
        }
      }
      
      // Check if user has completed registration before
      final hasCompletedRegistration = prefs.getBool('hasCompletedRegistration') ?? false;
      
      if (hasCompletedRegistration) {
        // User has registered before - check for cached profile
        if (_user == null) {
          // No cached data and session expired - they need to login
          _isAuthenticated = false;
          debugPrint('⚠️ User session expired and no cached data - login required');
        } else {
          // Have cached data but not authenticated - show cached data
          _isAuthenticated = false;
          debugPrint('📱 Using cached user data while offline: ${_user?.name}');
        }
      } else {
        // First time user - use mock data for onboarding
        _user = UserModel.mockUser();
        _isAuthenticated = false;
        debugPrint('👋 First time user - using mock data for onboarding');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing user: $e');
      // Try to load cached data as emergency fallback
      await _loadCachedData();
      if (_user == null) {
        _user = UserModel.mockUser();
      }
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  // Load all cached data for offline-first approach
  Future<void> _loadCachedData() async {
    try {
      // Load cached user profile
      final cachedUser = await _offlineService.getCachedUserProfile();
      if (cachedUser != null) {
        _user = cachedUser;
        debugPrint('📱 Loaded cached user: ${_user?.name}');
      }

      // Load cached leaderboard
      final cachedLeaderboard = await _offlineService.getCachedLeaderboard();
      if (cachedLeaderboard.isNotEmpty) {
        _leaderboardUsers = cachedLeaderboard;
        debugPrint('📱 Loaded cached leaderboard: ${_leaderboardUsers.length} users');
      }

      // Load cached school leaderboard
      final cachedSchoolLeaderboard = await _offlineService.getCachedSchoolLeaderboard();
      if (cachedSchoolLeaderboard.isNotEmpty) {
        _schoolLeaderboardUsers = cachedSchoolLeaderboard;
        debugPrint('📱 Loaded cached school leaderboard: ${_schoolLeaderboardUsers.length} users');
      }

      // Load cached schools
      final cachedSchools = await _offlineService.getCachedSchools();
      if (cachedSchools.isNotEmpty) {
        _schools = cachedSchools;
        debugPrint('📱 Loaded cached schools: ${_schools.length} schools');
      }
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
    }
  }

  // Attempt online sync in background
  Future<void> _attemptOnlineSync() async {
    if (!_offlineService.isOnline) {
      debugPrint('📴 Offline - skipping sync attempt');
      return;
    }

    try {
      debugPrint('🔄 Attempting background sync...');
      
      // Sync user profile
      final freshUser = await _supabaseService.getUserProfile();
      if (freshUser != null && freshUser != _user) {
        _user = freshUser;
        await _offlineService.cacheUserProfile(_user!);
        debugPrint('✅ User profile synced');
      }

      // Sync leaderboard
      await _fetchLeaderboardUsers();
      
      // Sync school leaderboard if applicable
      if (_user?.schoolId != null) {
        await refreshSchoolLeaderboard();
      }

      notifyListeners();
      debugPrint('✅ Background sync completed');
    } catch (e) {
      debugPrint('⚠️ Background sync failed (will retry): $e');
      // Schedule retry
      Future.delayed(const Duration(seconds: 30), () {
        if (_offlineService.isOnline) {
          _attemptOnlineSync();
        }
      });
    }
  }

  // Load avatar data from local storage
  Future<void> _loadAvatarData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedIds = prefs.getStringList('unlockedAvatarIds') ?? [];
      for (final id in unlockedIds) {
        final avatar = _findAvatarById(id);
        if (avatar != null && !_unlockedAvatars.any((a) => a.id == id)) {
          _unlockedAvatars.add(avatar.copyWith(isLocked: false));
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading avatar data: $e');
    }
  }

  // Complete onboarding with account creation
  Future<void> completeOnboarding({
    required String name,
    required int age,
    required String email,
    required String password,
    String? parentEmail,
    List<String> interests = const [],
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTimeUser', false);
      await prefs.setBool('hasCompletedRegistration', true);
      
      _isFirstTimeUser = false;
      
      // Register user with Supabase
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
        age: age,
        parentEmail: parentEmail,
      );
      
      if (response.user != null) {
        // Update user profile with additional information
        await _supabaseService.updateUserProfile(
          interests: interests,
        );
        
        // Load user profile
        _user = await _supabaseService.getUserProfile();
        _isAuthenticated = true;

        // Award 0.5 coins for setting up account (as per requirements)
        await _supabaseService.addCoins(0.5);
        if (_user != null) {
          _user = _user!.copyWith(coins: 0.5);
        }

        // Ensure entitlements are updated for premium access
        await refreshEntitlements();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    int? age,
    String? avatarUrl,
    List<String>? interests,
    String? parentEmail,
    bool? weeklyReportsEnabled,
    String? timezone,
    int? preferredSendDow,
    int? preferredSendHour,
    int? preferredSendMinute,
  }) async {
    if (_user == null) return;
    
    try {
      // Enforce shop-owned avatars for asset-based avatars
      if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
        final ownsAvatar = _unlockedAvatars.any((a) => a.imagePath == avatarUrl);
        if (!ownsAvatar) {
          throw Exception('Avatar not owned. Purchase in Shop before use.');
        }
      }

      // Update profile in Supabase
      await _supabaseService.updateUserProfile(
        name: name,
        age: age,
        avatarUrl: avatarUrl,
        interests: interests,
        parentEmail: parentEmail,
        weeklyReportsEnabled: weeklyReportsEnabled,
        timezone: timezone,
        preferredSendDow: preferredSendDow,
        preferredSendHour: preferredSendHour,
        preferredSendMinute: preferredSendMinute,
      );
      
      // Update local user model
      _user = _user!.copyWith(
        name: name,
        age: age,
        avatarUrl: avatarUrl,
        interests: interests,
        parentEmail: parentEmail,
        weeklyReportsEnabled: weeklyReportsEnabled,
        timezone: timezone,
        preferredSendDow: preferredSendDow,
        preferredSendHour: preferredSendHour,
        preferredSendMinute: preferredSendMinute,
      );
      
      notifyListeners();
      debugPrint('✅ User profile updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow; // Re-throw so caller can handle the error
    }
  }

  // Spend coins (offline-resilient)
  Future<bool> spendCoins(double amount) async {
    if (_user == null || _user!.coins < amount) {
      return false;
    }
    
    try {
      // Update local user model immediately for responsive UI
      _user = _user!.copyWith(
        coins: _user!.coins - amount,
      );
      
      // Cache updated user data
      await _offlineService.cacheUserProfile(_user!);
      notifyListeners();
      
      if (_offlineService.isOnline) {
        // Try to sync with server immediately
        await _supabaseService.spendCoins(amount);
        debugPrint('✅ Coins spent and synced: $amount');
      } else {
        // Add to pending actions for later sync
        await _offlineService.addPendingAction('spend_coins', {
          'amount': amount,
          'user_id': _user!.id,
        });
        debugPrint('📴 Coins spent offline, will sync when online: $amount');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error spending coins: $e');
      // Revert local changes if server sync failed
      _user = _user!.copyWith(
        coins: _user!.coins + amount,
      );
      await _offlineService.cacheUserProfile(_user!);
      notifyListeners();
      return false;
    }
  }

  // Add an avatar to user's collection
  void addAvatar(AvatarModel avatar) {
    if (!_unlockedAvatars.any((a) => a.id == avatar.id)) {
      _unlockedAvatars.add(avatar);
      // Persist unlocked avatars locally
      _saveData();
      notifyListeners();
    }
  }

  // Check if user has unlocked an avatar
  bool hasAvatar(String avatarId) {
    return _unlockedAvatars.any((avatar) => avatar.id == avatarId);
  }

  // Add coins to user (offline-resilient)
  Future<void> addCoins(double amount) async {
    if (_user == null) return;
    
    try {
      // Update local user model immediately for responsive UI
      _user = _user!.copyWith(
        coins: _user!.coins + amount,
      );
      
      // Cache updated user data
      await _offlineService.cacheUserProfile(_user!);
      notifyListeners();
      
      if (_offlineService.isOnline) {
        // Try to sync with server immediately
        await _supabaseService.addCoins(amount);
        debugPrint('✅ Coins added and synced: $amount');
      } else {
        // Add to pending actions for later sync
        await _offlineService.addPendingAction('add_coins', {
          'amount': amount,
          'user_id': _user!.id,
        });
        debugPrint('📴 Coins added offline, will sync when online: $amount');
      }
    } catch (e) {
      debugPrint('❌ Error adding coins: $e');
      // Revert local changes if server sync failed
      _user = _user!.copyWith(
        coins: _user!.coins - amount,
      );
      await _offlineService.cacheUserProfile(_user!);
      notifyListeners();
    }
  }

  /// Update local XP only (when server has already updated DB)
  void updateLocalXp(int amount) {
    if (_user == null) return;
    
    _user = _user!.copyWith(xp: _user!.xp + amount);
    
    // Update leaderboard
    final userIndex = _leaderboardUsers.indexWhere((u) => u.id == _user!.id);
    if (userIndex >= 0) {
      _leaderboardUsers[userIndex] = _user!;
    }
    _leaderboardUsers.sort((a, b) => b.monthlyXp.compareTo(a.monthlyXp));
    
    notifyListeners();
    debugPrint('✅ Local XP updated: +$amount');
  }

  /// Update local coins only (when server has already updated DB)
  void updateLocalCoins(double amount) {
    if (_user == null) return;
    
    _user = _user!.copyWith(coins: _user!.coins + amount);
    notifyListeners();
    debugPrint('✅ Local coins updated: +$amount');
  }

  // Add XP to user (offline-resilient)
  Future<void> addXp(int amount) async {
    if (_user == null) return;
    
    try {
      // Update local user model immediately for responsive UI
      _user = _user!.copyWith(
        xp: _user!.xp + amount,
      );
      
      // Update the user in the leaderboard list to ensure it's reflected immediately
      final userIndex = _leaderboardUsers.indexWhere((u) => u.id == _user!.id);
      if (userIndex >= 0) {
        _leaderboardUsers[userIndex] = _user!;
      } else if (_user != null) {
        // If user isn't in leaderboard yet, add them
        _leaderboardUsers.add(_user!);
      }
      
      // Re-sort the leaderboard after XP update (by monthly XP to match server ordering)
      _leaderboardUsers.sort((a, b) => b.monthlyXp.compareTo(a.monthlyXp));
      
      // Cache updated user and leaderboard data
      await _offlineService.cacheUserProfile(_user!);
      await _offlineService.cacheLeaderboard(_leaderboardUsers);
      
      // Refresh UI
      notifyListeners();
      
      if (_offlineService.isOnline) {
        // Try to sync with server immediately
        await _supabaseService.addXp(amount);
        debugPrint('✅ XP added and synced: $amount');
        
        // Fetch updated leaderboard from server in background (without overwriting current user)
        _fetchLeaderboardUsers().then((_) {
          // After fetching leaderboard, ensure current user's XP is not overwritten
          // by stale data from the leaderboard fetch
          notifyListeners();
        });
      } else {
        // Add to pending actions for later sync
        await _offlineService.addPendingAction('add_xp', {
          'amount': amount,
          'user_id': _user!.id,
        });
        debugPrint('📴 XP added offline, will sync when online: $amount');
      }
    } catch (e) {
      debugPrint('❌ Error adding XP: $e');
      // Revert local changes if server sync failed
      _user = _user!.copyWith(
        xp: _user!.xp - amount,
      );
      await _offlineService.cacheUserProfile(_user!);
      notifyListeners();
    }
  }

  // Add a badge
  Future<void> addBadge(BadgeModel badge) async {
    try {
      // Check if badge already exists in local list to prevent duplicates
      final alreadyExists = _badges.any((b) => 
        b.type == badge.type || 
        (b.name == badge.name && b.userId == badge.userId)
      );
      
      if (alreadyExists) {
        debugPrint('⚠️ Badge ${badge.name} already in local list, skipping duplicate');
        return;
      }
      
      // Save badge locally
      _badges.add(badge);
      debugPrint('✅ Badge ${badge.name} added to local list. Total badges: ${_badges.length}');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding badge: $e');
    }
  }


  // Check if user has a specific badge type
  bool hasBadgeOfType(BadgeType type) {
    return _badges.any((badge) => badge.type == type);
  }

  // Check if user has a specific badge type
  // Reset first time user status (for testing)
  Future<void> resetFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeUser', true);
    _isFirstTimeUser = true;
    _saveData();
    notifyListeners();
  }

  // Save user data to SharedPreferences
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString('user_data', jsonEncode(_user!.toJson()));
      await prefs.setDouble('coins', _user!.coins);
      await prefs.setInt('xp', _user!.xp);
    }
    await prefs.setStringList('unlockedAvatarIds', _unlockedAvatars.map((a) => a.id).toList());
  }

  // This method is now merged with the _loadData method above

  // Find avatar by ID (helper method)
  AvatarModel? _findAvatarById(String id) {
    // This should be replaced with your actual avatar data source
    final allAvatars = [
      AvatarModel(
        id: '1',
        name: 'Default Avatar',
        imagePath: 'assets/images/avatars/default.png',
        price: 0,
        isLocked: false,
      ),
      AvatarModel(
        id: '2',
        name: 'Hero Avatar',
        imagePath: 'assets/images/avatars/hero.png',
        price: 100,
      ),
      AvatarModel(
        id: '3',
        name: 'Ninja Avatar',
        imagePath: 'assets/images/avatars/ninja.png',
        price: 200,
      ),
      AvatarModel(
        id: '4',
        name: 'Wizard Avatar',
        imagePath: 'assets/images/avatars/wizard.png',
        price: 300,
      ),
      AvatarModel(
        id: '5',
        name: 'Dragon Avatar',
        imagePath: 'assets/images/avatars/dragon.png',
        price: 500,
      ),
    ];
    return allAvatars.firstWhere((a) => a.id == id, orElse: () => allAvatars[0]);
  }

  // Generate mock users for the leaderboard
  List<UserModel> _generateMockLeaderboardUsers() {
    final List<String> names = [
      'Emma', 'Noah', 'Olivia', 'Liam', 'Ava', 'William', 'Sophia', 'Mason',
      'Isabella', 'James', 'Mia', 'Benjamin', 'Charlotte', 'Jacob', 'Amelia',
      'Michael', 'Harper', 'Elijah', 'Evelyn', 'Ethan', 'Abigail', 'Alexander',
      'Emily', 'Daniel', 'Elizabeth', 'Matthew', 'Sofia', 'Aiden', 'Madison',
      'Henry', 'Avery', 'Joseph', 'Ella', 'Jackson', 'Scarlett', 'Samuel',
      'Grace', 'Sebastian', 'Chloe', 'David', 'Victoria', 'Carter', 'Riley',
      'Wyatt', 'Aria', 'Jayden', 'Lily', 'John', 'Aubrey', 'Owen'
    ];
    
    final List<String> badgeTypes = [
      'Goal Ninja', 'Challenge Champion', 'Victory Master', 'Leadership Star',
      'Quest Hero', 'Team Captain', 'Problem Solver', 'Creative Genius'
    ];
    
    final List<UserModel> users = [];
    final random = Random();
    
    // Generate 25 random users
    for (int i = 0; i < 25; i++) {
      final name = names[random.nextInt(names.length)];
      final age = random.nextInt(7) + 8; // Ages 8-14
      final xp = random.nextInt(900) + 100; // XP between 100-999
      final coins = (random.nextInt(200) / 10); // Coins between 0-20.0
      
      // Random badges (0-3)
      final badgeCount = random.nextInt(4);
      final badges = <String>[];
      for (int j = 0; j < badgeCount; j++) {
        badges.add(badgeTypes[random.nextInt(badgeTypes.length)]);
      }
      
      users.add(UserModel(
        id: 'user-${i + 100}',
        name: name,
        age: age,
        xp: xp,
        coins: coins,
        badges: badges,
      ));
    }
    
    return users;
  }
  
  // Badge management methods (using existing addBadge method)
  
  bool hasBadge(BadgeType badgeType) {
    return _badges.any((badge) => badge.type == badgeType);
  }
  
  List<BadgeModel> getBadgesByCategory(String category) {
    // Filter badges by category if needed
    return _badges;
  }
  
  // Load badges from database
  Future<void> loadUserBadges() async {
    try {
      if (_user == null) return;
      
      final response = await _supabaseService.client
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', _user!.id);
      
      _badges.clear();
      for (var item in response as List) {
        try {
          final badgeData = item['badges'] as Map<String, dynamic>;
          final dbName = (badgeData['name'] as String?)?.trim() ?? '';
          final norm = dbName.toLowerCase();
          
          // Map DB badge names to our BadgeType groups
          BadgeType? badgeType;
          // Exact legacy names
          if (norm == 'goal ninja') badgeType = BadgeType.goalNinja;
          else if (norm == 'challenge champion') badgeType = BadgeType.challengeChampion;
          else if (norm == 'streak master') badgeType = BadgeType.streakMaster;
          else if (norm == 'helpful hero') badgeType = BadgeType.helpfulHero;
          else if (norm == 'knowledge seeker') badgeType = BadgeType.knowledgeSeeker;
          else if (norm == 'healthy habit hero') badgeType = BadgeType.healthyHabitHero;
          else if (norm == 'social butterfly') badgeType = BadgeType.socialButterfly;
          else if (norm == 'academic ace') badgeType = BadgeType.academicAce;
          else if (norm == 'questor friend') badgeType = BadgeType.questorFriend;
          else if (norm == 'victory veteran') badgeType = BadgeType.victoryVeteran;
          
          // Gratitude streak milestones → Streak Master group
          else if ({
            'seed of thanks','gratitude leaf','blossom of joy','ray of appreciation','tree of thanks',
            'flame of gratitude','world of thanks','peaceful heart','eternal gratitude'
          }.contains(norm)) {
            badgeType = BadgeType.streakMaster;
          }
          // Goals completed milestones → Goal Ninja group
          else if ({
            'starter vision','sharpshooter','step climber','achiever’s medal','achiever medal',
            'goal voyager','peak reacher','master planner','visionary eagle','legacy builder','infinite dreamer'
          }.contains(norm)) {
            badgeType = BadgeType.goalNinja;
          }
          // Mini-course milestones → Knowledge Seeker group
          else if ({
            'apprentice learner','curious mind','scholar’s cap','scholar cap',
            'critical thinker','wisdom keeper','sage of learning','mind innovator','knowledge dragon','eternal master'
          }.contains(norm)) {
            badgeType = BadgeType.knowledgeSeeker;
          }
          
          if (badgeType != null) {
            _badges.add(BadgeModel(
              id: item['id'],
              userId: item['user_id'],
              type: badgeType,
              earnedDate: DateTime.parse(item['earned_at']),
              description: badgeData['description'],
            ));
          } else {
            // Fallback: load unrecognized badges with default type to prevent data loss
            debugPrint('⚠️ Unrecognized badge name: "$dbName", using default type');
            _badges.add(BadgeModel(
              id: item['id'],
              userId: item['user_id'],
              type: BadgeType.goalNinja, // Default fallback
              earnedDate: DateTime.parse(item['earned_at']),
              description: badgeData['description'],
            ));
          }
        } catch (e) {
          debugPrint('Error parsing badge: $e');
        }
      }
      
      debugPrint('🏆 Total badges loaded: ${_badges.length}');
      // Note: UserModel has no badgeCount field; use badges.length directly where needed
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user badges: $e');
    }
  }

  // Public method to manually reinitialize user (for troubleshooting)
  Future<void> reinitializeUser() async {
    debugPrint('UserProvider: Manual reinitialize requested');
    await _initializeUser();
  }

  /// Reset onboarding status to view onboarding flow again
  /// This clears the onboarding completion flag but preserves user data
  Future<void> resetOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear onboarding completion flag
      await prefs.remove('has_completed_registration');
      await prefs.setBool('has_completed_onboarding', false);
      
      debugPrint('✅ Onboarding status reset - restart app to see onboarding');
    } catch (e) {
      debugPrint('❌ Error resetting onboarding status: $e');
      rethrow;
    }
  }
}
