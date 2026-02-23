import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/secure_goal_service.dart';
import '../services/challenge_evaluator.dart';
import '../services/offline_persistence_service.dart';

// Result status for adding a daily goal
enum AddDailyGoalStatus {
  createdOnline,
  queuedOffline,
  limitReached,
  failed,
}

class GoalProvider extends ChangeNotifier {
  final _supabaseService = SupabaseService();
  final OfflinePersistenceService _offlineService = OfflinePersistenceService();
  List<MainGoalModel> _mainGoals = [];
  List<DailyGoalModel> _dailyGoals = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _initInProgress = false;
  StreamSubscription<AuthState>? _authSub;

  // Stream controller for goal completion events
  final _goalCompletionController = StreamController<MainGoalModel>.broadcast();
  Stream<MainGoalModel> get goalCompletionStream =>
      _goalCompletionController.stream;

  // Stream controller for expired goals notification
  final _expiredGoalsController =
      StreamController<List<MainGoalModel>>.broadcast();
  Stream<List<MainGoalModel>> get expiredGoalsStream =>
      _expiredGoalsController.stream;

  // Reference to UserProvider for XP updates
  dynamic _userProvider;

  /// Set UserProvider reference for XP updates
  void setUserProvider(dynamic userProvider) {
    _userProvider = userProvider;
  }

  // Initialize goals from database - public method that can be called from outside
  Future<void> initGoals() async {
    if (_isInitialized || _initInProgress)
      return; // Prevent multiple initializations

    _initInProgress = true;
    _isLoading = true;
    notifyListeners();

    try {
      // First, try to load from local storage (scoped per user) to have data immediately available
      await _loadMainGoals();
      await _loadDailyGoals();

      // Then attempt to sync with Supabase if authenticated
      if (_supabaseService.isAuthenticated) {
        // Synchronize any temporary goals first
        await synchronizeTempGoals();
        try {
          // Load main goals from Supabase
          final mainGoals = await _supabaseService.fetchMainGoals();
          if (mainGoals.isNotEmpty) {
            _mainGoals = mainGoals;
            // Save to local storage for future use
            await _saveMainGoals();
            debugPrint('Loaded ${mainGoals.length} main goals from Supabase');
          } else if (_mainGoals.isEmpty) {
            debugPrint('No main goals found in Supabase');
          }

          // Load daily goals from Supabase
          final dailyGoals = await _supabaseService.fetchDailyGoals();
          if (dailyGoals.isNotEmpty) {
            _dailyGoals = dailyGoals;
            // Save to local storage for future use
            await _saveDailyGoals();
            debugPrint('Loaded ${dailyGoals.length} daily goals from Supabase');
          } else if (_dailyGoals.isEmpty) {
            debugPrint('No daily goals found in Supabase');
          }
        } catch (e) {
          debugPrint('Error syncing with Supabase: $e');
          // We already loaded from local storage, so we have fallback data
        }
      } else {
        debugPrint('User not authenticated, using local storage data only');
      }
      // If we are authenticated, attempt to process any pending offline actions now
      if (_supabaseService.isAuthenticated) {
        try {
          await _offlineService.processPendingActions();
        } catch (e) {
          debugPrint('Error processing pending actions during init: $e');
        }
      }

      // Check for expired goals after loading
      await checkExpiredGoals();

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing goals: $e');
      _isLoading = false;
      notifyListeners();
    } finally {
      _initInProgress = false;
    }
  }

  // Filter out archived AND expired goals from main goals list
  // Users should only see active goals - expired goals should be archived
  List<MainGoalModel> get mainGoals => _mainGoals
      .where((goal) => !goal.isArchived && goal.status != 'expired')
      .toList();

  // Get expired but not archived goals (for prompting user to archive)
  List<MainGoalModel> get expiredGoals => _mainGoals
      .where((goal) => !goal.isArchived && goal.status == 'expired')
      .toList();

  // Get only archived goals
  List<MainGoalModel> get archivedGoals =>
      _mainGoals.where((goal) => goal.isArchived).toList();

  // Get count of active (non-archived) goals
  int get activeGoalsCount => mainGoals.length;

  // Get completed but not archived goals
  List<MainGoalModel> get completedGoals =>
      mainGoals.where((goal) => goal.isCompleted).toList();

  // Get only active main goals that can have daily goals created for them
  // Filters out: archived, completed, and expired goals
  List<MainGoalModel> get activeMainGoalsForDailyGoals => _mainGoals
      .where((goal) =>
          !goal.isArchived &&
          !goal.isCompleted &&
          !goal.isExpired &&
          goal.status == 'active')
      .toList();

  // Get an archived goal by ID (for orphaned daily goals display)
  MainGoalModel? getArchivedGoalById(String goalId) {
    try {
      return _mainGoals.firstWhere((goal) => goal.id == goalId);
    } catch (e) {
      return null;
    }
  }

  // Check if a main goal is valid for creating daily goals
  bool isMainGoalValidForDailyGoal(String mainGoalId) {
    final goal = getMainGoalById(mainGoalId);
    if (goal == null) return false;
    return !goal.isArchived &&
        !goal.isCompleted &&
        !goal.isExpired &&
        goal.status == 'active';
  }

  // Get the reason why a main goal is not valid for daily goals
  String? getMainGoalInvalidReason(String mainGoalId) {
    final goal = getMainGoalById(mainGoalId);
    if (goal == null) return 'Goal not found';
    if (goal.isArchived) return 'This goal has been archived';
    if (goal.isCompleted) {
      return 'This goal is already completed. Archive it and create a new goal.';
    }
    if (goal.isExpired) {
      return 'This goal has expired. Archive it and create a new goal.';
    }
    if (goal.status != 'active') {
      return 'This goal is not active (status: ${goal.status})';
    }
    return null;
  }

  // Check if a daily goal can be completed (main goal must be active)
  bool canCompleteDailyGoal(String dailyGoalId) {
    final dailyGoal = getDailyGoalById(dailyGoalId);
    if (dailyGoal == null) return false;
    if (dailyGoal.isCompleted) return false;
    return isMainGoalValidForDailyGoal(dailyGoal.mainGoalId);
  }

  // Get the reason why a daily goal cannot be completed
  String? getDailyGoalBlockedReason(String dailyGoalId) {
    final dailyGoal = getDailyGoalById(dailyGoalId);
    if (dailyGoal == null) return 'Daily goal not found';
    if (dailyGoal.isCompleted) return null; // Already completed, not blocked
    return getMainGoalInvalidReason(dailyGoal.mainGoalId);
  }

  List<DailyGoalModel> get dailyGoals => _dailyGoals;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Get daily goals for today
  List<DailyGoalModel> get todayGoals {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _dailyGoals.where((goal) {
      return goal.date.isAfter(startOfDay) && goal.date.isBefore(endOfDay);
    }).toList();
  }

  Map<DateTime, List<DailyGoalModel>> get weeklyGoals {
    final Map<DateTime, List<DailyGoalModel>> result = {};
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final goalsForDay = _dailyGoals.where((goal) {
        return goal.date.isAfter(startOfDay) && goal.date.isBefore(endOfDay);
      }).toList();

      result[date] = goalsForDay;
    }

    return result;
  }

  Map<DateTime, double> get weeklyCompletionRates {
    final weekGoals = weeklyGoals;
    final Map<DateTime, double> result = {};
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    // Ensure we have entries for all 7 days of the week
    for (int i = 0; i < 7; i++) {
      final date =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
      final goals = weekGoals[date] ?? [];

      if (goals.isEmpty) {
        result[date] = 0.0;
      } else {
        final completedCount = goals.where((goal) => goal.isCompleted).length;
        result[date] = completedCount / goals.length;
      }
    }

    return result;
  }

  // Initialize with empty data
  GoalProvider() {
    // Initialize empty goals lists
    _mainGoals = [];
    _dailyGoals = [];
    // Note: We don't call initGoals() here because it's async
    // It will be called explicitly from main.dart
    // Register offline action handler so queued actions can be processed on reconnect
    _offlineService.registerActionHandler(_handlePendingAction);
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub =
        _supabaseService.client.auth.onAuthStateChange.listen((data) async {
      switch (data.event) {
        case AuthChangeEvent.signedOut:
          // Clear in-memory goals and stop reading previous user's local cache
          _mainGoals = [];
          _dailyGoals = [];
          _isInitialized = false;
          // Also clear all goals from SharedPreferences to prevent leakage
          await _clearAllGoalsCache();
          notifyListeners();
          break;
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          // Clear any existing goals first, then reload for the new/current user
          _mainGoals = [];
          _dailyGoals = [];
          _isInitialized = false;
          await initGoals();
          break;
        default:
          break;
      }
    });
  }

  // Clear all goals cache from SharedPreferences (more aggressive than clearGoals)
  Future<void> _clearAllGoalsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Remove all goal-related keys to prevent any cross-user leakage
      for (final key in keys) {
        if (key.contains('main_goals') || key.contains('daily_goals')) {
          await prefs.remove(key);
          debugPrint('Cleared goals cache key on auth change: $key');
        }
      }
    } catch (e) {
      debugPrint('Error clearing all goals cache: $e');
    }
  }

  // Save main goals to SharedPreferences
  String _keyFor(String base) {
    final uid = _supabaseService.currentUser?.id;
    return uid != null ? '${base}_$uid' : '${base}_guest';
  }

  Future<void> _saveMainGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mainGoalsJson = _mainGoals.map((goal) => goal.toJson()).toList();
      await prefs.setString(_keyFor('main_goals'), jsonEncode(mainGoalsJson));
      debugPrint('Main goals saved successfully (${_mainGoals.length} goals)');
    } catch (e) {
      debugPrint('Error saving main goals: $e');
    }
  }

  // Load main goals from SharedPreferences
  Future<void> _loadMainGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only load if authenticated and user ID is available
      if (!_supabaseService.isAuthenticated ||
          _supabaseService.currentUser?.id == null) {
        _mainGoals = [];
        debugPrint(
            'No main goals loaded - user not authenticated or no user ID');
        return;
      }

      final key = _keyFor('main_goals');
      final mainGoalsString = prefs.getString(key);

      if (mainGoalsString != null && mainGoalsString.isNotEmpty) {
        final List<dynamic> mainGoalsJson = jsonDecode(mainGoalsString);
        _mainGoals =
            mainGoalsJson.map((json) => MainGoalModel.fromJson(json)).toList();
        debugPrint(
            'Loaded ${_mainGoals.length} main goals from local storage for user ${_supabaseService.currentUser!.id}');
      } else {
        // Initialize with empty list if none are stored
        _mainGoals = [];
        debugPrint(
            'No stored main goals found for user ${_supabaseService.currentUser!.id}');
      }
    } catch (e) {
      debugPrint('Error loading main goals: $e');
      _mainGoals = [];
    }
  }

  // Save daily goals to SharedPreferences
  Future<void> _saveDailyGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dailyGoalsJson = _dailyGoals.map((goal) => goal.toJson()).toList();
      await prefs.setString(_keyFor('daily_goals'), jsonEncode(dailyGoalsJson));
      debugPrint(
          'Daily goals saved successfully (${_dailyGoals.length} goals)');
    } catch (e) {
      debugPrint('Error saving daily goals: $e');
    }
  }

  // Load daily goals from SharedPreferences
  Future<void> _loadDailyGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only load if authenticated and user ID is available
      if (!_supabaseService.isAuthenticated ||
          _supabaseService.currentUser?.id == null) {
        _dailyGoals = [];
        debugPrint(
            'No daily goals loaded - user not authenticated or no user ID');
        return;
      }

      final key = _keyFor('daily_goals');
      final dailyGoalsString = prefs.getString(key);

      if (dailyGoalsString != null && dailyGoalsString.isNotEmpty) {
        final List<dynamic> dailyGoalsJson = jsonDecode(dailyGoalsString);
        _dailyGoals = dailyGoalsJson
            .map((json) => DailyGoalModel.fromJson(json))
            .toList();
        debugPrint(
            'Loaded ${_dailyGoals.length} daily goals from storage for user ${_supabaseService.currentUser!.id}');
      } else {
        _dailyGoals = [];
        debugPrint(
            'No stored daily goals found for user ${_supabaseService.currentUser!.id}');
      }
    } catch (e) {
      debugPrint('Error loading daily goals: $e');
      _dailyGoals = [];
    }
  }

  // Explicitly clear goals and their persisted cache for current user scope
  Future<void> clearGoals() async {
    try {
      _mainGoals = [];
      _dailyGoals = [];
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor('main_goals'));
      await prefs.remove(_keyFor('daily_goals'));
      notifyListeners();
    } catch (_) {}
  }

  // Add a main goal
  Future<void> addMainGoal(MainGoalModel goal) async {
    // Limit to 3 active (non-archived) main goals as per requirements
    // Use activeGoalsCount which filters out archived goals
    if (activeGoalsCount >= 3) {
      debugPrint(
          'Cannot add goal: active goal limit reached (${activeGoalsCount}/3)');
      return;
    }

    try {
      // Save to Supabase first and get the updated goal with UUID
      final updatedGoal = await _supabaseService.saveMainGoal(goal);

      // Then add the updated goal (with proper UUID) to local state
      _mainGoals.add(updatedGoal);

      // Also save to local storage for persistence
      await _saveMainGoals();

      notifyListeners();

      debugPrint('Goal added successfully with ID: ${updatedGoal.id}');
    } catch (e) {
      debugPrint('Error saving main goal: $e');
      rethrow; // Rethrow to allow handling in the UI
    }
  }

  // Update a main goal
  Future<void> updateMainGoal(MainGoalModel updatedGoal) async {
    final index = _mainGoals.indexWhere((goal) => goal.id == updatedGoal.id);
    if (index != -1) {
      try {
        // Save to Supabase first and get the updated goal
        final serverUpdatedGoal =
            await _supabaseService.updateMainGoal(updatedGoal);

        // Then update local state with the server-updated goal
        _mainGoals[index] = serverUpdatedGoal;

        // Also update in local storage
        await _saveMainGoals();

        notifyListeners();

        debugPrint(
            'Goal updated successfully with ID: ${serverUpdatedGoal.id}');
      } catch (e) {
        debugPrint('Error updating main goal: $e');
        rethrow; // Rethrow to allow handling in the UI
      }
    }
  }

  // Delete a main goal
  Future<void> deleteMainGoal(String goalId) async {
    final index = _mainGoals.indexWhere((goal) => goal.id == goalId);
    if (index != -1) {
      _mainGoals.removeAt(index);

      // Save to local storage
      await _saveMainGoals();

      notifyListeners();

      // Try to delete from Supabase if available, otherwise just log
      try {
        if (_supabaseService.isAuthenticated) {
          await _supabaseService.deleteMainGoal(goalId);
        }
      } catch (e) {
        debugPrint('Error deleting main goal from Supabase: $e');
        // Method not available yet, would need a clean rebuild
      }
    }
  }

  // Archive a main goal
  Future<bool> archiveMainGoal(String goalId) async {
    try {
      final index = _mainGoals.indexWhere((goal) => goal.id == goalId);
      if (index == -1) {
        debugPrint('Goal not found for archival: $goalId');
        return false;
      }

      final goal = _mainGoals[index];

      // Validate goal can be archived
      if (!goal.canBeArchived) {
        debugPrint(
            'Goal cannot be archived (not completed or expired): $goalId');
        return false;
      }

      // Create archived version
      final archivedGoal = goal.copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        status: 'archived',
        completedAt:
            goal.completedAt ?? (goal.isCompleted ? DateTime.now() : null),
      );

      // Update in Supabase (this triggers the database trigger to delete orphaned daily goals)
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.updateMainGoal(archivedGoal);
      }

      // Update local state
      _mainGoals[index] = archivedGoal;
      await _saveMainGoals();

      // Delete orphaned daily goals locally (incomplete daily goals linked to this main goal)
      final orphanedGoalsCount = _dailyGoals
          .where((dg) => dg.mainGoalId == goalId && !dg.isCompleted)
          .length;
      _dailyGoals.removeWhere((dailyGoal) =>
          dailyGoal.mainGoalId == goalId && !dailyGoal.isCompleted);
      await _saveDailyGoals();

      if (orphanedGoalsCount > 0) {
        debugPrint(
            'Deleted $orphanedGoalsCount orphaned daily goals for archived main goal: $goalId');
      }

      notifyListeners();

      debugPrint('Goal archived successfully: $goalId');
      return true;
    } catch (e) {
      debugPrint('Error archiving goal: $e');
      return false;
    }
  }

  // Unarchive a goal (restore to active)
  Future<bool> unarchiveMainGoal(String goalId) async {
    try {
      final index = _mainGoals.indexWhere((goal) => goal.id == goalId);
      if (index == -1) return false;

      final goal = _mainGoals[index];

      // Check if user has space for another active goal
      if (activeGoalsCount >= 3) {
        debugPrint('Cannot unarchive: active goal limit reached (3/3)');
        return false;
      }

      // Create unarchived version
      final unarchivedGoal = goal.copyWith(
        isArchived: false,
        archivedAt: null,
        status: goal.isCompleted ? 'completed' : 'active',
      );

      // Update in Supabase
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.updateMainGoal(unarchivedGoal);
      }

      // Update local state
      _mainGoals[index] = unarchivedGoal;
      await _saveMainGoals();
      notifyListeners();

      debugPrint('Goal unarchived successfully: $goalId');
      return true;
    } catch (e) {
      debugPrint('Error unarchiving goal: $e');
      return false;
    }
  }

  // Check for expired goals and update their status
  // Returns list of newly expired goals for notification
  Future<List<MainGoalModel>> checkExpiredGoals() async {
    final List<MainGoalModel> newlyExpiredGoals = [];
    try {
      final now = DateTime.now();
      bool hasChanges = false;

      for (int i = 0; i < _mainGoals.length; i++) {
        final goal = _mainGoals[i];

        // Skip archived goals
        if (goal.isArchived) continue;

        // Check if goal is expired
        if (goal.endDate.isBefore(now) &&
            goal.status == 'active' &&
            !goal.isCompleted) {
          final expiredGoal = goal.copyWith(status: 'expired');
          _mainGoals[i] = expiredGoal;
          newlyExpiredGoals.add(expiredGoal);

          // Persist to server
          if (_supabaseService.isAuthenticated) {
            await _supabaseService.updateMainGoal(expiredGoal);
          }

          hasChanges = true;
          debugPrint('Goal expired: ${goal.title}');
        }
      }

      if (hasChanges) {
        await _saveMainGoals();
        notifyListeners();

        // Emit to stream so UI can show notification
        if (newlyExpiredGoals.isNotEmpty) {
          _expiredGoalsController.add(newlyExpiredGoals);
        }
      }
    } catch (e) {
      debugPrint('Error checking expired goals: $e');
    }
    return newlyExpiredGoals;
  }

  // Add a daily goal
  Future<AddDailyGoalStatus> addDailyGoal(DailyGoalModel goal) async {
    // Enforce max 3 daily goals per day (local guard)
    final today = DateTime.now();
    final sameDayGoals =
        _dailyGoals.where((g) => _isSameDay(g.date, today)).length;
    const maxDailyGoals = 3;
    if (sameDayGoals >= maxDailyGoals) {
      debugPrint(
          'Daily goal limit reached ($maxDailyGoals). New goal not added.');
      return AddDailyGoalStatus.limitReached;
    }
    try {
      // Save to Supabase first if authenticated
      DailyGoalModel updatedGoal;
      if (_supabaseService.isAuthenticated) {
        updatedGoal = await _supabaseService.saveDailyGoal(goal);
        _dailyGoals.add(updatedGoal);
      } else {
        // Generate a temporary ID for offline mode
        updatedGoal =
            goal.copyWith(id: 'temp_${DateTime.now().millisecondsSinceEpoch}');
        _dailyGoals.add(updatedGoal);
        // Queue for later creation
        await _offlineService.addPendingAction('create_daily_goal', {
          'goal': updatedGoal.toJson(),
        });
      }

      // Always save to local storage for persistence
      await _saveDailyGoals();
      notifyListeners();

      debugPrint('Daily goal added with ID: ${updatedGoal.id}');
      // Return appropriate status
      return _supabaseService.isAuthenticated
          ? AddDailyGoalStatus.createdOnline
          : AddDailyGoalStatus.queuedOffline;
    } catch (e) {
      debugPrint('Error adding daily goal: $e');
      try {
        // Fall back to local storage if Supabase fails
        final tempGoal =
            goal.copyWith(id: 'temp_${DateTime.now().millisecondsSinceEpoch}');
        _dailyGoals.add(tempGoal);
        // Queue for later creation
        await _offlineService.addPendingAction('create_daily_goal', {
          'goal': tempGoal.toJson(),
        });
        await _saveDailyGoals();
        notifyListeners();
        return AddDailyGoalStatus.queuedOffline;
      } catch (e2) {
        debugPrint('Fallback add daily goal also failed: $e2');
        return AddDailyGoalStatus.failed;
      }
    }
  }

  // Update a daily goal
  Future<void> updateDailyGoal(DailyGoalModel updatedGoal) async {
    final index = _dailyGoals.indexWhere((goal) => goal.id == updatedGoal.id);
    if (index != -1) {
      try {
        if (_supabaseService.isAuthenticated &&
            !updatedGoal.id.startsWith('temp_')) {
          // Update in Supabase first
          final savedGoal = await _supabaseService.updateDailyGoal(updatedGoal);
          _dailyGoals[index] = savedGoal;
        } else {
          // Fall back to local storage
          _dailyGoals[index] = updatedGoal;
          await _saveDailyGoals();
          // Queue for later update if offline or temp ID
          await _offlineService.addPendingAction('update_daily_goal', {
            'goal': updatedGoal.toJson(),
          });
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error updating daily goal: $e');
        // Fall back to local storage if Supabase fails
        _dailyGoals[index] = updatedGoal;
        await _saveDailyGoals();
        // Queue for later update
        await _offlineService.addPendingAction('update_daily_goal', {
          'goal': updatedGoal.toJson(),
        });
        notifyListeners();
      }
    }
  }

  // Delete a daily goal
  Future<void> deleteDailyGoal(String goalId) async {
    final index = _dailyGoals.indexWhere((g) => g.id == goalId);
    if (index != -1 && _dailyGoals[index].isCompleted) {
      debugPrint(
          'Refusing to delete a completed goal - prevents quota exploit');
      return;
    }
    try {
      if (_supabaseService.isAuthenticated && !goalId.startsWith('temp_')) {
        // Delete from Supabase first
        await _supabaseService.deleteDailyGoal(goalId);
      }

      _dailyGoals.removeWhere((goal) => goal.id == goalId);
      await _saveDailyGoals(); // Always update local cache
      // Queue for later delete if offline or temp ID
      if (!_supabaseService.isAuthenticated || goalId.startsWith('temp_')) {
        await _offlineService.addPendingAction('delete_daily_goal', {
          'goalId': goalId,
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting daily goal: $e');
      // Still remove from local cache if Supabase fails
      _dailyGoals.removeWhere((goal) => goal.id == goalId);
      await _saveDailyGoals();
      await _offlineService.addPendingAction('delete_daily_goal', {
        'goalId': goalId,
      });
      notifyListeners();
    }
  }

  // Secure daily goal completion with anti-gaming measures
  Future<bool> toggleDailyGoalCompletion(String goalId) async {
    final index = _dailyGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) return false;

    final goal = _dailyGoals[index];

    // If completing the goal, prefer secure service when online
    if (!goal.isCompleted) {
      // Check if main goal is still valid for completion
      final mainGoal = getMainGoalById(goal.mainGoalId);
      if (mainGoal == null) {
        debugPrint('Cannot complete daily goal: main goal not found');
        return false;
      }

      // Block completion if main goal is archived
      if (mainGoal.isArchived) {
        debugPrint('Cannot complete daily goal: main goal is archived');
        return false;
      }

      // Block completion if main goal is expired (and not completed)
      if (mainGoal.isExpired) {
        debugPrint('Cannot complete daily goal: main goal has expired');
        return false;
      }

      // Check if goal is temporary (offline created) and sync first
      if (goal.id.startsWith('temp_')) {
        debugPrint(
            'Goal has temporary ID, attempting synchronization first...');
        try {
          await synchronizeTempGoals();
          // The goal at the same index should now have a permanent ID
          if (index >= _dailyGoals.length ||
              _dailyGoals[index].id.startsWith('temp_')) {
            debugPrint('Goal synchronization failed or incomplete');
            return false;
          }
          // Update the goal reference to the synced version
          final syncedGoal = _dailyGoals[index];
          goalId = syncedGoal.id;
          debugPrint('Goal synchronized successfully, new ID: $goalId');
        } catch (e) {
          debugPrint('Error synchronizing temporary goal: $e');
          return false;
        }
      }

      // Check authentication status with detailed logging
      final isAuth = _supabaseService.isAuthenticated;
      final user = _supabaseService.currentUser;

      debugPrint(
          'Goal completion auth check: isAuthenticated=$isAuth, userId=${user?.id ?? "null"}');

      if (!isAuth) {
        debugPrint('User must be online & authenticated to complete goals');
        // Queue secure completion for later
        await _offlineService.addPendingAction('complete_goal', {
          'goalId': goalId,
        });
        return false;
      }

      // OPTIMISTIC UPDATE: Update UI immediately for better UX
      _dailyGoals[index] = goal.copyWith(isCompleted: true);
      _addXpToMainGoal(goal.mainGoalId, goal.xpValue);
      notifyListeners(); // Show checkmark immediately

      // Then verify with server in background
      try {
        final secureService = SecureGoalService();
        // Initialize with UserProvider for immediate XP updates
        if (_userProvider != null) {
          secureService.initialize(_userProvider);
        }
        final success = await secureService.completeDailyGoal(goalId);

        if (success) {
          // Server confirmed - persist to cache
          await _saveDailyGoals();
          await _saveMainGoals();
          debugPrint('Goal completion confirmed by server: $goalId');
          // Trigger goal-related challenge evaluation (badge checks handled by SecureGoalService)
          try {
            await ChallengeEvaluator.instance.evaluateGoalChallenges();
          } catch (_) {}
          return true;
        } else {
          // Server rejected - rollback optimistic update
          debugPrint(
              'Goal completion rejected by server, rolling back: $goalId');
          _dailyGoals[index] = goal.copyWith(isCompleted: false);
          _removeXpFromMainGoal(goal.mainGoalId, goal.xpValue);
          notifyListeners();
          return false;
        }
      } catch (e) {
        // Network error - rollback optimistic update
        debugPrint('Goal completion network error, rolling back: $e');
        _dailyGoals[index] = goal.copyWith(isCompleted: false);
        _removeXpFromMainGoal(goal.mainGoalId, goal.xpValue);
        notifyListeners();
        return false;
      }
    } else {
      // Uncompleting a goal (less secure, but logged)
      try {
        if (_supabaseService.isAuthenticated && !goal.id.startsWith('temp_')) {
          final updatedGoal = goal.copyWith(isCompleted: false);
          final savedGoal = await _supabaseService.updateDailyGoal(updatedGoal);
          _dailyGoals[index] = savedGoal;
          _removeXpFromMainGoal(goal.mainGoalId, goal.xpValue);
          await _saveDailyGoals();
          await _saveMainGoals(); // Also save main goals since XP was updated
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('Error uncompleting goal: $e');
        return false;
      }
    }

    return false;
  }

  // Refresh main goals from Supabase and persist locally
  Future<void> _refreshMainGoalsFromServer() async {
    try {
      if (_supabaseService.isAuthenticated) {
        final fresh = await _supabaseService.fetchMainGoals();
        if (fresh.isNotEmpty) {
          _mainGoals = fresh;
          await _saveMainGoals();
          notifyListeners();
          debugPrint('Main goals refreshed from server: ${fresh.length} items');
        } else {
          debugPrint('No main goals returned from server on refresh.');
        }
      } else {
        debugPrint('Skipped main goals refresh: not authenticated');
      }
    } catch (e) {
      debugPrint('Error refreshing main goals from server: $e');
    }
  }

  // Best-effort background persistence of XP to Supabase to prevent drift
  Future<void> _persistMainGoalXp(MainGoalModel goal) async {
    if (!_supabaseService.isAuthenticated) return;
    try {
      // Fire-and-forget style persistence; local state already updated
      await _supabaseService.updateMainGoal(goal);
      debugPrint(
          'Persisted XP to server for goal ${goal.id}: ${goal.currentXp}/${goal.totalXpRequired}');
    } catch (e) {
      debugPrint('Non-blocking XP persist failed for ${goal.id}: $e');
    }
  }

  // Add XP to a main goal
  void _addXpToMainGoal(String mainGoalId, int xpAmount) {
    final index = _mainGoals.indexWhere((goal) => goal.id == mainGoalId);
    if (index != -1) {
      final goal = _mainGoals[index];
      final wasCompleted = goal.isCompleted;
      final updatedGoal = goal.copyWith(currentXp: goal.currentXp + xpAmount);
      final isNowCompleted = updatedGoal.isCompleted;

      // Detect completion
      if (!wasCompleted && isNowCompleted) {
        // Goal just completed!
        final completedGoal = updatedGoal.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
        );
        _mainGoals[index] = completedGoal;
        debugPrint('🎉 Goal completed: ${completedGoal.title}');

        // Trigger completion callback (UI will listen)
        _onGoalCompleted(completedGoal);
      } else {
        _mainGoals[index] = updatedGoal;
      }

      debugPrint(
          'Added XP to main goal ${updatedGoal.title} (${updatedGoal.id}): +$xpAmount → ${updatedGoal.currentXp}/${updatedGoal.totalXpRequired}');
      // Proactively notify so any listeners depending on this list refresh immediately
      notifyListeners();
      // Persist to server in background to keep remote in sync
      // Intentionally not awaited by callers of toggleDailyGoalCompletion
      // ignore: unawaited_futures
      _persistMainGoalXp(_mainGoals[index]);
    } else {
      debugPrint(
          'Main goal not found for XP update. mainGoalId=$mainGoalId; XP to add=$xpAmount');
    }
  }

  // Callback for goal completion (UI can listen to this via stream)
  void _onGoalCompleted(MainGoalModel goal) {
    // Emit to stream so UI can show celebration dialog
    debugPrint('🎉 Goal completion event triggered for: ${goal.title}');
    _goalCompletionController.add(goal);

    // Trigger challenge evaluation for main goal completion
    // This is in addition to the daily goal evaluation to ensure main goal challenges are checked
    try {
      ChallengeEvaluator.instance.evaluateGoalChallenges();
    } catch (e) {
      debugPrint('Challenge evaluation after main goal completion failed: $e');
    }
  }

  // Remove XP from a main goal (used for rollback on failed completion)
  void _removeXpFromMainGoal(String mainGoalId, int xpAmount) {
    final index = _mainGoals.indexWhere((goal) => goal.id == mainGoalId);
    if (index != -1) {
      final goal = _mainGoals[index];
      final newXp = goal.currentXp - xpAmount;
      final clampedXp = newXp < 0 ? 0 : newXp;

      // If removing XP takes goal below completion threshold, revert status
      final wasCompleted = goal.isCompleted;
      final willBeCompleted = clampedXp >= goal.totalXpRequired;

      MainGoalModel updatedGoal;
      if (wasCompleted && !willBeCompleted) {
        // Revert completion status
        updatedGoal = goal.copyWith(
          currentXp: clampedXp,
          status: 'active',
          clearCompletedAt: true,
        );
        debugPrint(
            '⚠️ Goal completion reverted due to XP rollback: ${goal.title}');
      } else {
        updatedGoal = goal.copyWith(currentXp: clampedXp);
      }

      _mainGoals[index] = updatedGoal;
      notifyListeners();
      // Persist to server in background to keep remote in sync
      // ignore: unawaited_futures
      _persistMainGoalXp(updatedGoal);
    }
  }

  // Get daily goals for a specific date
  List<DailyGoalModel> getDailyGoalsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return _dailyGoals.where((goal) {
      return goal.date.isAfter(startOfDay) && goal.date.isBefore(endOfDay);
    }).toList();
  }

  // Get daily goals for a specific main goal
  List<DailyGoalModel> getDailyGoalsForMainGoal(String mainGoalId) {
    return _dailyGoals.where((goal) => goal.mainGoalId == mainGoalId).toList();
  }

  // Get main goal by ID
  MainGoalModel? getMainGoalById(String goalId) {
    try {
      return _mainGoals.firstWhere((goal) => goal.id == goalId);
    } catch (e) {
      return null;
    }
  }

  // Helper to compare two dates ignoring the time
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // These methods were duplicates of the ones already defined at lines 73 and 94
  // Removed to fix duplicate definition errors

  // Get daily goal by ID
  DailyGoalModel? getDailyGoalById(String goalId) {
    try {
      return _dailyGoals.firstWhere((goal) => goal.id == goalId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has a streak of completed daily goals.
  ///
  /// Streak logic:
  /// - A day counts toward the streak if the user completed AT LEAST ONE goal that day
  /// - Days with no goals set are skipped (don't break the streak)
  /// - Today is given a grace period (streak doesn't break if no completions yet today)
  /// - The streak breaks when we find a day where goals were set but NONE were completed
  int getCurrentStreak() {
    int streak = 0;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    // Track consecutive days with at least one completion
    int daysChecked = 0;
    int daysWithoutActivity = 0;
    const maxGapDays = 1; // Allow 1 day gap (for grace period on today)
    const maxDaysToCheck = 60; // Check up to 60 days back

    for (int i = 0; i < maxDaysToCheck; i++) {
      final date = todayOnly.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay =
          DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      // Get all goals for this day (inclusive of start and end)
      final goalsForDay = _dailyGoals.where((goal) {
        final goalDate =
            DateTime(goal.date.year, goal.date.month, goal.date.day);
        return goalDate.isAtSameMomentAs(startOfDay) ||
            (goal.date.isAfter(startOfDay) && goal.date.isBefore(endOfDay));
      }).toList();

      // Check if any goals were completed this day
      final completedGoalsForDay =
          goalsForDay.where((goal) => goal.isCompleted).toList();

      if (completedGoalsForDay.isNotEmpty) {
        // User completed at least one goal this day - streak continues!
        streak++;
        daysWithoutActivity = 0; // Reset gap counter
      } else if (goalsForDay.isEmpty) {
        // No goals set for this day - skip it (don't break streak)
        // But if we're on day 0 (today), give grace period
        if (i == 0) {
          // Today with no goals yet - don't count but don't break
          continue;
        }
        daysWithoutActivity++;
        // If too many days without any activity, break the streak
        if (daysWithoutActivity > maxGapDays && streak > 0) {
          break;
        }
      } else {
        // Goals were set but NONE completed - this breaks the streak
        // Exception: if this is today (i == 0), give grace period
        if (i == 0) {
          continue; // Grace period for today
        }
        break;
      }

      daysChecked++;
    }

    return streak;
  }

  // Synchronize temporary goals with Supabase
  Future<bool> synchronizeTempGoals() async {
    // Force check authentication state
    final user = _supabaseService.currentUser;
    final isAuth = _supabaseService.isAuthenticated;

    debugPrint(
        'Synchronization attempt: user ${user != null ? "exists" : "is null"}, isAuth=$isAuth');

    if (!isAuth || user == null) {
      debugPrint(
          'Cannot synchronize goals: User not authenticated (user: ${user?.email ?? "null"}, isAuth: $isAuth)');
      return false;
    }

    debugPrint('Starting synchronization of temporary goals...');
    bool hasChanges = false;

    // Find all temporary goals (with temp_ prefix)
    final tempGoals =
        _dailyGoals.where((goal) => goal.id.startsWith('temp_')).toList();
    debugPrint('Found ${tempGoals.length} temporary goals to synchronize');

    if (tempGoals.isEmpty) {
      debugPrint('No temporary goals to synchronize');
      return false;
    }

    // Process each temporary goal
    for (int i = 0; i < tempGoals.length; i++) {
      final tempGoal = tempGoals[i];
      try {
        // Save to Supabase to get a permanent ID
        final permanentGoal = await _supabaseService.saveDailyGoal(tempGoal);

        // Replace the temporary goal with the permanent one
        final index = _dailyGoals.indexWhere((goal) => goal.id == tempGoal.id);
        if (index != -1) {
          _dailyGoals[index] = permanentGoal;
          hasChanges = true;
          debugPrint('Synchronized goal: ${tempGoal.id} → ${permanentGoal.id}');
        }
      } catch (e) {
        debugPrint('Error synchronizing goal ${tempGoal.id}: $e');
      }
    }

    if (hasChanges) {
      // Save the updated goals to local storage
      await _saveDailyGoals();
      notifyListeners();
      debugPrint('Temporary goals synchronized successfully');
    }

    return hasChanges;
  }

  // Handle processing of queued offline actions on reconnect
  Future<void> _handlePendingAction(Map<String, dynamic> actionData) async {
    final action = actionData['action'] as String?;
    final data = (actionData['data'] as Map<String, dynamic>?);
    if (action == null || data == null) return;

    switch (action) {
      case 'create_daily_goal':
        final goalJson = data['goal'] as Map<String, dynamic>;
        final localGoal = DailyGoalModel.fromJson(goalJson);
        // If already has permanent ID, skip
        if (!localGoal.id.startsWith('temp_')) return;
        // Create on server
        final created = await _supabaseService.saveDailyGoal(localGoal);
        // Replace local temp goal
        final idx = _dailyGoals.indexWhere((g) => g.id == localGoal.id);
        if (idx != -1) {
          _dailyGoals[idx] = created;
          await _saveDailyGoals();
          notifyListeners();
        }
        break;
      case 'update_daily_goal':
        final goalJson = data['goal'] as Map<String, dynamic>;
        final localGoal = DailyGoalModel.fromJson(goalJson);
        // If temp, try to sync temp goals first to obtain permanent ID
        if (localGoal.id.startsWith('temp_')) {
          await synchronizeTempGoals();
          final matched = _dailyGoals.firstWhere(
            (g) =>
                g.title == localGoal.title &&
                _isSameDay(g.date, localGoal.date),
            orElse: () => localGoal,
          );
          if (!matched.id.startsWith('temp_')) {
            final serverUpdated = await _supabaseService
                .updateDailyGoal(localGoal.copyWith(id: matched.id));
            final idx = _dailyGoals.indexWhere((g) => g.id == matched.id);
            if (idx != -1) {
              _dailyGoals[idx] = serverUpdated;
              await _saveDailyGoals();
              notifyListeners();
            }
            break;
          } else {
            // Still temp, leave action for next cycle
            throw Exception('Goal still temporary, will retry');
          }
        } else {
          final serverUpdated =
              await _supabaseService.updateDailyGoal(localGoal);
          final idx = _dailyGoals.indexWhere((g) => g.id == localGoal.id);
          if (idx != -1) {
            _dailyGoals[idx] = serverUpdated;
            await _saveDailyGoals();
            notifyListeners();
          }
        }
        break;
      case 'delete_daily_goal':
        final goalId = data['goalId'] as String;
        if (goalId.startsWith('temp_')) {
          // No server delete required
          _dailyGoals.removeWhere((g) => g.id == goalId);
          await _saveDailyGoals();
          notifyListeners();
          break;
        }
        await _supabaseService.deleteDailyGoal(goalId);
        _dailyGoals.removeWhere((g) => g.id == goalId);
        await _saveDailyGoals();
        notifyListeners();
        break;
      case 'complete_goal':
        final goalId = data['goalId'] as String;
        // Only attempt secure completion when authenticated
        if (_supabaseService.isAuthenticated) {
          await toggleDailyGoalCompletion(goalId);
        } else {
          throw Exception('Not authenticated');
        }
        break;
      default:
        // Unknown action: ignore
        break;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _goalCompletionController.close();
    _expiredGoalsController.close();
    super.dispose();
  }
}
