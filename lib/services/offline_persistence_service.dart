import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/models.dart';

class OfflinePersistenceService {
  static const String _userKey = 'cached_user_profile';
  static const String _leaderboardKey = 'cached_leaderboard';
  static const String _schoolLeaderboardKey = 'cached_school_leaderboard';
  static const String _schoolsKey = 'cached_schools';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _pendingActionsKey = 'pending_actions';

  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Pending actions queue for offline operations
  final List<Map<String, dynamic>> _pendingActions = [];

  // Optional external handler to process actions (e.g., in a Provider)
  Future<void> Function(Map<String, dynamic> actionData)? _actionHandler;

  OfflinePersistenceService() {
    _initializeConnectivityMonitoring();
    // Attempt to warm up pending actions from disk
    _loadPendingActions();
  }

  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) async {
      final wasOnline = _isOnline;
      // results is a List<ConnectivityResult>. Online if any result is not none
      final hasAny = results.any((r) => r != ConnectivityResult.none);
      _isOnline = hasAny;
      
      if (!wasOnline && _isOnline) {
        debugPrint('🌐 Connection restored - processing pending actions');
        await processPendingActions();
      } else if (wasOnline && !_isOnline) {
        debugPrint('📴 Connection lost - enabling offline mode');
      }
      
      _connectionController.add(_isOnline);
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }

  // User profile persistence
  Future<void> cacheUserProfile(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ User profile cached: ${user.name}');
    } catch (e) {
      debugPrint('❌ Error caching user profile: $e');
    }
  }

  Future<UserModel?> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final user = UserModel.fromJson(userData);
        debugPrint('📱 Loaded cached user profile: ${user.name}');
        return user;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached user profile: $e');
    }
    return null;
  }

  // Leaderboard persistence
  Future<void> cacheLeaderboard(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((u) => u.toJson()).toList();
      await prefs.setString(_leaderboardKey, jsonEncode(usersJson));
      debugPrint('✅ Leaderboard cached: ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error caching leaderboard: $e');
    }
  }

  Future<List<UserModel>> getCachedLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leaderboardJson = prefs.getString(_leaderboardKey);
      if (leaderboardJson != null) {
        final List<dynamic> usersData = jsonDecode(leaderboardJson);
        final users = usersData.map((data) => UserModel.fromJson(data)).toList();
        debugPrint('📱 Loaded cached leaderboard: ${users.length} users');
        return users;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached leaderboard: $e');
    }
    return [];
  }

  // School leaderboard persistence
  Future<void> cacheSchoolLeaderboard(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((u) => u.toJson()).toList();
      await prefs.setString(_schoolLeaderboardKey, jsonEncode(usersJson));
      debugPrint('✅ School leaderboard cached: ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error caching school leaderboard: $e');
    }
  }

  Future<List<UserModel>> getCachedSchoolLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leaderboardJson = prefs.getString(_schoolLeaderboardKey);
      if (leaderboardJson != null) {
        final List<dynamic> usersData = jsonDecode(leaderboardJson);
        final users = usersData.map((data) => UserModel.fromJson(data)).toList();
        debugPrint('📱 Loaded cached school leaderboard: ${users.length} users');
        return users;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached school leaderboard: $e');
    }
    return [];
  }

  // Schools persistence
  Future<void> cacheSchools(List<Map<String, dynamic>> schools) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schoolsKey, jsonEncode(schools));
      debugPrint('✅ Schools cached: ${schools.length} schools');
    } catch (e) {
      debugPrint('❌ Error caching schools: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedSchools() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolsJson = prefs.getString(_schoolsKey);
      if (schoolsJson != null) {
        final List<dynamic> schoolsData = jsonDecode(schoolsJson);
        final schools = schoolsData.cast<Map<String, dynamic>>();
        debugPrint('📱 Loaded cached schools: ${schools.length} schools');
        return schools;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached schools: $e');
    }
    return [];
  }

  // Pending actions for offline operations
  Future<void> addPendingAction(String action, Map<String, dynamic> data) async {
    try {
      final actionData = {
        'action': action,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      _pendingActions.add(actionData);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingActionsKey, jsonEncode(_pendingActions));
      
      debugPrint('📝 Added pending action: $action');
    } catch (e) {
      debugPrint('❌ Error adding pending action: $e');
    }
  }

  Future<void> _loadPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionsJson = prefs.getString(_pendingActionsKey);
      if (actionsJson != null) {
        final List<dynamic> actionsData = jsonDecode(actionsJson);
        _pendingActions.clear();
        _pendingActions.addAll(actionsData.cast<Map<String, dynamic>>());
        debugPrint('📱 Loaded ${_pendingActions.length} pending actions');
      }
    } catch (e) {
      debugPrint('❌ Error loading pending actions: $e');
    }
  }

  /// Register an external handler to process each pending action.
  void registerActionHandler(Future<void> Function(Map<String, dynamic> actionData) handler) {
    _actionHandler = handler;
  }

  /// Returns a copy of current pending actions.
  List<Map<String, dynamic>> getPendingActions() => List.unmodifiable(_pendingActions);

  /// Remove a specific action (after successful processing) and persist the queue.
  Future<void> removePendingAction(Map<String, dynamic> actionData) async {
    _pendingActions.remove(actionData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActionsKey, jsonEncode(_pendingActions));
  }

  /// Public method to process all pending actions. Uses external handler if set.
  Future<void> processPendingActions() async {
    if (_pendingActions.isEmpty) return;
    
    try {
      await _loadPendingActions();
      
      for (final actionData in List.from(_pendingActions)) {
        try {
          if (_actionHandler != null) {
            await _actionHandler!(actionData);
            _pendingActions.remove(actionData);
          } else {
            await _processSingleAction(actionData);
            _pendingActions.remove(actionData);
          }
        } catch (e) {
          debugPrint('❌ Failed to process pending action: ${actionData['action']} - $e');
          // Keep action in queue for next retry
        }
      }
      
      // Save updated pending actions
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingActionsKey, jsonEncode(_pendingActions));
      
      if (_pendingActions.isEmpty) {
        debugPrint('✅ All pending actions processed successfully');
      } else {
        debugPrint('⏳ ${_pendingActions.length} actions still pending');
      }
    } catch (e) {
      debugPrint('❌ Error processing pending actions: $e');
    }
  }

  Future<void> _processSingleAction(Map<String, dynamic> actionData) async {
    final action = actionData['action'] as String;
    final data = actionData['data'] as Map<String, dynamic>;
    
    switch (action) {
      case 'update_profile':
        // Process profile update
        break;
      case 'spend_coins':
        // Process coin spending
        break;
      case 'add_xp':
        // Process XP addition
        break;
      case 'create_daily_goal':
        // Placeholder: allow external handler to process, or implement here if desired
        break;
      case 'update_daily_goal':
        // Placeholder
        break;
      case 'delete_daily_goal':
        // Placeholder
        break;
      case 'complete_goal':
        // Process goal completion
        break;
      default:
        debugPrint('⚠️ Unknown pending action: $action');
    }
  }

  // Check if cached data is stale
  Future<bool> isCacheStale({Duration maxAge = const Duration(hours: 24)}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
      final isStale = DateTime.now().difference(lastSyncTime) > maxAge;
      
      debugPrint('📅 Cache age: ${DateTime.now().difference(lastSyncTime).inHours}h, stale: $isStale');
      return isStale;
    } catch (e) {
      debugPrint('❌ Error checking cache staleness: $e');
      return true;
    }
  }

  // Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_leaderboardKey);
      await prefs.remove(_schoolLeaderboardKey);
      await prefs.remove(_schoolsKey);
      await prefs.remove(_lastSyncKey);
      await prefs.remove(_pendingActionsKey);
      debugPrint('🗑️ All cached data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }
}
