import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/challenge_evaluator.dart';
import '../services/badge_service.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class GratitudeProvider with ChangeNotifier {
  List<GratitudeEntry> _entries = [];
  bool _isLoaded = false;
  final SupabaseService _supabaseService = SupabaseService();
  String? _loadedForUserId;
  StreamSubscription<AuthState>? _authSubscription;

  /// XP reward for gratitude entries (once per day)
  static const int gratitudeXpReward = 10;

  GratitudeProvider() {
    _setupAuthListener();
  }

  void _setupAuthListener() {
    try {
      _authSubscription = _supabaseService.client.auth.onAuthStateChange.listen(
        (data) {
          final event = data.event;
          final userId = data.session?.user.id;

          if (event == AuthChangeEvent.signedOut) {
            _loadedForUserId = null;
            clearEntries();
            return;
          }

          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.userUpdated ||
              event == AuthChangeEvent.tokenRefreshed) {
            if (_loadedForUserId != userId) {
              _loadedForUserId = userId;
              clearEntries();
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up gratitude auth listener: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Clear all entries and reset loaded state (for logout)
  void clearEntries() {
    _entries.clear();
    _isLoaded = false;
    notifyListeners();
  }

  List<GratitudeEntry> get entries => _entries;
  bool get isLoaded => _isLoaded;

  // Get entries for a specific date
  List<GratitudeEntry> getEntriesForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _entries
        .where((entry) =>
            entry.date.isAfter(startOfDay) && entry.date.isBefore(endOfDay))
        .toList();
  }

  // Get entries for the current week
  List<GratitudeEntry> getEntriesForCurrentWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endDate = startDate.add(const Duration(days: 7));

    return _entries
        .where((entry) =>
            entry.date.isAfter(startDate) && entry.date.isBefore(endDate))
        .toList();
  }

  /// Check if user has already posted a gratitude entry today (local check)
  bool hasPostedToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _entries.any((entry) =>
        entry.date.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
        entry.date.isBefore(endOfDay.add(const Duration(seconds: 1))));
  }

  /// Check if user has already posted today by querying the database
  /// This is the authoritative check to prevent XP farming exploits
  Future<bool> hasPostedTodayFromDatabase() async {
    if (!_supabaseService.isAuthenticated) return hasPostedToday();

    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabaseService.client
          .from('gratitude_entries')
          .select('id')
          .eq('user_id', _supabaseService.currentUser!.id)
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String())
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking database for today\'s entry: $e');
      // Fall back to local check if database query fails
      return hasPostedToday();
    }
  }

  /// Check if user can post today (hasn't posted yet)
  bool canPostToday() => !hasPostedToday();

  /// Check if user can post today by querying the database (authoritative)
  Future<bool> canPostTodayFromDatabase() async {
    return !(await hasPostedTodayFromDatabase());
  }

  /// Add a new gratitude entry
  /// Returns true if XP was awarded (first entry of the day), false otherwise
  /// Throws an exception if user has already posted today
  Future<bool> addEntry(GratitudeEntry entry,
      {bool enforceLimit = true}) async {
    // Check if user has already posted today (local check for UI)
    final localCheck = !hasPostedToday();

    if (enforceLimit && !localCheck) {
      throw Exception(
          'You can only add one gratitude entry per day. Come back tomorrow!');
    }

    // For XP award decision, use database check (authoritative) to prevent exploits
    // This is defense-in-depth - the database trigger also prevents duplicates
    bool shouldAwardXp = false;
    if (_supabaseService.isAuthenticated) {
      shouldAwardXp = await canPostTodayFromDatabase();
      debugPrint('Database check for XP eligibility: $shouldAwardXp');
    }

    try {
      // Add to local list first for immediate UI update
      _entries.add(entry);
      _entries.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();

      // Save to local storage
      await _saveEntries();

      // Sync to database if authenticated
      if (_supabaseService.isAuthenticated) {
        await _syncEntryToDatabase(entry);

        // Award XP only if database confirms this is the first entry today
        // This prevents XP farming via add/delete/repeat exploit
        if (shouldAwardXp) {
          try {
            await _supabaseService.addXp(gratitudeXpReward);
            debugPrint('Awarded $gratitudeXpReward XP for gratitude entry');
          } catch (e) {
            debugPrint('Failed to award XP for gratitude entry: $e');
          }
        } else {
          debugPrint(
              'XP not awarded - database shows entry already exists today');
        }
      }

      // Trigger gratitude-specific challenge evaluation
      try {
        await ChallengeEvaluator.instance.evaluateGratitudeChallenges();
      } catch (e) {
        debugPrint('Challenge evaluation after gratitude entry failed: $e');
      }

      // Trigger badge checks (UI notifications should be handled in screens where context exists)
      try {
        await BadgeService().checkForAchievements();
      } catch (e) {
        debugPrint('Badge evaluation after gratitude entry failed: $e');
      }

      return shouldAwardXp;
    } catch (e) {
      debugPrint('Error adding gratitude entry: $e');
      // Remove from local list if database sync fails
      _entries.removeWhere((e) => e.id == entry.id);
      notifyListeners();
      rethrow;
    }
  }

  // Update an existing entry
  Future<void> updateEntry(GratitudeEntry updatedEntry) async {
    final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      _entries[index] = updatedEntry;
      notifyListeners();

      await _saveEntries();

      // Sync to database if authenticated
      if (_supabaseService.isAuthenticated) {
        try {
          await _supabaseService.client
              .from('gratitude_entries')
              .update({
                'content': updatedEntry.content,
                'mood': updatedEntry.mood,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', updatedEntry.id)
              .eq('user_id', _supabaseService.currentUser!.id);
        } catch (e) {
          debugPrint('Error updating gratitude entry in database: $e');
        }
      }
    }
  }

  // Delete an entry
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();

    await _saveEntries();

    // Delete from database if authenticated
    if (_supabaseService.isAuthenticated) {
      try {
        await _supabaseService.client
            .from('gratitude_entries')
            .delete()
            .eq('id', id)
            .eq('user_id', _supabaseService.currentUser!.id);
      } catch (e) {
        debugPrint('Error deleting gratitude entry from database: $e');
      }
    }
  }

  // Load entries from SharedPreferences and sync with database
  Future<void> loadEntries() async {
    final currentUserId = _supabaseService.currentUser?.id;
    if (_isLoaded && _loadedForUserId == currentUserId) return;

    try {
      // First load from local storage for immediate display
      final prefs = await SharedPreferences.getInstance();
      _loadedForUserId = currentUserId;
      final cacheKey = currentUserId != null
          ? 'gratitude_entries_$currentUserId'
          : 'gratitude_entries';
      final entriesJson = prefs.getStringList(cacheKey) ?? [];

      _entries = entriesJson
          .map((json) => GratitudeEntry.fromJson(jsonDecode(json)))
          .toList();

      // Sort entries by date (newest first)
      _entries.sort((a, b) => b.date.compareTo(a.date));

      _isLoaded = true;
      notifyListeners();

      // Then sync with database if authenticated
      if (_supabaseService.isAuthenticated) {
        await _syncWithDatabase();
      }
    } catch (e) {
      debugPrint('Error loading gratitude entries: $e');
      _entries = [];
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Save entries to SharedPreferences
  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabaseService.currentUser?.id;
      final cacheKey = currentUserId != null
          ? 'gratitude_entries_$currentUserId'
          : 'gratitude_entries';
      final entriesJson =
          _entries.map((entry) => jsonEncode(entry.toJson())).toList();

      await prefs.setStringList(cacheKey, entriesJson);
    } catch (e) {
      debugPrint('Error saving gratitude entries: $e');
    }
  }

  // Sync a single entry to database
  Future<void> _syncEntryToDatabase(GratitudeEntry entry) async {
    try {
      await _supabaseService.client.from('gratitude_entries').insert({
        'id': entry.id,
        'user_id': _supabaseService.currentUser!.id,
        'content': entry.content,
        'mood': entry.mood,
        'date': entry.date.toIso8601String(),
        'created_at': entry.date.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Gratitude entry synced to database: ${entry.id}');
    } catch (e) {
      debugPrint('Error syncing gratitude entry to database: $e');
      rethrow;
    }
  }

  // Sync all entries with database
  Future<void> _syncWithDatabase() async {
    try {
      // Fetch entries from database
      final response = await _supabaseService.client
          .from('gratitude_entries')
          .select()
          .eq('user_id', _supabaseService.currentUser!.id)
          .order('created_at', ascending: false);

      final databaseEntries = (response as List)
          .map((json) => GratitudeEntry(
                id: json['id'],
                content: json['content'],
                date: DateTime.parse(json['date']),
                mood: json['mood'] ?? 'happy',
              ))
          .toList();

      // Merge with local entries (database takes precedence)
      final Map<String, GratitudeEntry> mergedEntries = {};

      // Add local entries first
      for (final entry in _entries) {
        mergedEntries[entry.id] = entry;
      }

      // Override with database entries (they take precedence)
      for (final entry in databaseEntries) {
        mergedEntries[entry.id] = entry;
      }

      _entries = mergedEntries.values.toList();
      _entries.sort((a, b) => b.date.compareTo(a.date));

      // Save merged entries to local storage
      await _saveEntries();
      notifyListeners();

      debugPrint(
          'Gratitude entries synced with database: ${_entries.length} entries');
    } catch (e) {
      debugPrint('Error syncing with database: $e');
      // Don't rethrow - we can continue with local entries
    }
  }
}
