import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for parent portal - allows parents to view their children's analytics
/// Parents are existing app users whose email is set as parent_email by their children
class ParentPortalService {
  static final ParentPortalService _instance = ParentPortalService._internal();
  factory ParentPortalService() => _instance;
  ParentPortalService._internal();

  final _supabase = Supabase.instance.client;

  /// Get the current user's email
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
  
  /// Check if current user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Find all children who have set the current user's email as their parent_email
  Future<List<Map<String, dynamic>>> getMyChildren() async {
    try {
      final email = currentUserEmail;
      if (email == null) {
        debugPrint('ParentPortal: No authenticated user');
        return [];
      }

      debugPrint('ParentPortal: Looking for children with parent_email = $email');
      
      // Find all profiles where parent_email matches current user's email
      final children = await _supabase
          .from('profiles')
          .select('id, name, avatar_url, xp, monthly_xp, coins, badges, interests, created_at')
          .eq('parent_email', email.toLowerCase().trim());
      
      debugPrint('ParentPortal: Found ${(children as List).length} children');
      
      return List<Map<String, dynamic>>.from(children);
    } catch (e) {
      debugPrint('Error fetching children: $e');
      return [];
    }
  }

  /// Get detailed analytics for a specific child
  Future<Map<String, dynamic>> getChildAnalytics(String childId) async {
    try {
      // Verify this child has the current user as their parent
      final email = currentUserEmail;
      if (email == null) {
        return {'error': 'Not authenticated'};
      }

      // Check if this child belongs to the current parent
      final childProfile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', childId)
          .eq('parent_email', email.toLowerCase().trim())
          .maybeSingle();
      
      if (childProfile == null) {
        return {'error': 'Child not found or not linked to your account'};
      }
      
      // Fetch main goals
      final mainGoals = await _supabase
          .from('main_goals')
          .select('*')
          .eq('user_id', childId)
          .order('created_at', ascending: false);
      
      // Fetch daily goals (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final dailyGoals = await _supabase
          .from('daily_goals')
          .select('*')
          .eq('user_id', childId)
          .gte('date', thirtyDaysAgo.toIso8601String().split('T')[0])
          .order('date', ascending: false);
      
      // Fetch goal completions (last 30 days)
      final completions = await _supabase
          .from('goal_completions')
          .select('*')
          .eq('user_id', childId)
          .gte('completed_at', thirtyDaysAgo.toIso8601String())
          .order('completed_at', ascending: false);
      
      // Fetch challenge participation
      final challenges = await _supabase
          .from('user_challenges')
          .select('''
            *,
            challenges (
              id,
              title,
              description,
              start_date,
              end_date,
              coin_reward
            )
          ''')
          .eq('user_id', childId);
      
      // Fetch gratitude entries (last 30 days)
      final gratitudeEntries = await _supabase
          .from('gratitude_entries')
          .select('*')
          .eq('user_id', childId)
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false);
      
      // Calculate statistics
      final mainGoalsList = List<Map<String, dynamic>>.from(mainGoals);
      final dailyGoalsList = List<Map<String, dynamic>>.from(dailyGoals);
      final completionsList = List<Map<String, dynamic>>.from(completions);
      final challengesList = List<Map<String, dynamic>>.from(challenges);
      final gratitudeList = List<Map<String, dynamic>>.from(gratitudeEntries);
      
      // Calculate completion rates
      // Main goals use 'status' field ('completed') or 'completed_at' not null
      int completedMainGoals = mainGoalsList.where((g) => 
          g['status'] == 'completed' || g['completed_at'] != null).length;
      // Daily goals use 'is_completed' boolean field
      int completedDailyGoals = dailyGoalsList.where((g) => g['is_completed'] == true).length;
      
      // Calculate streak (consecutive days with completed goals)
      // Use daily goals completion for more accurate streak
      int currentStreak = _calculateStreakFromDailyGoals(dailyGoalsList);
      
      // Weekly activity data - combine goal completions and daily goals
      Map<String, int> weeklyActivity = _calculateWeeklyActivityFromDailyGoals(dailyGoalsList);
      
      return {
        'profile': childProfile,
        'main_goals': mainGoalsList,
        'daily_goals': dailyGoalsList,
        'completions': completionsList,
        'challenges': challengesList,
        'gratitude_entries': gratitudeList,
        'stats': {
          'total_xp': childProfile['xp'] ?? 0,
          'monthly_xp': childProfile['monthly_xp'] ?? 0,
          'coins': childProfile['coins'] ?? 0,
          'badges_count': (childProfile['badges'] as List?)?.length ?? 0,
          'main_goals_total': mainGoalsList.length,
          'main_goals_completed': completedMainGoals,
          'daily_goals_total': dailyGoalsList.length,
          'daily_goals_completed': completedDailyGoals,
          'main_goal_completion_rate': mainGoalsList.isNotEmpty 
              ? (completedMainGoals / mainGoalsList.length * 100).round() 
              : 0,
          'daily_goal_completion_rate': dailyGoalsList.isNotEmpty 
              ? (completedDailyGoals / dailyGoalsList.length * 100).round() 
              : 0,
          'current_streak': currentStreak,
          'challenges_joined': challengesList.length,
          'challenges_completed': challengesList.where((c) => c['is_completed'] == true).length,
          'gratitude_entries_count': gratitudeList.length,
          'weekly_activity': weeklyActivity,
        },
      };
    } catch (e) {
      debugPrint('Error fetching child analytics: $e');
      return {'error': 'Failed to fetch analytics'};
    }
  }

  /// Calculate streak from daily goals
  int _calculateStreakFromDailyGoals(List<Map<String, dynamic>> dailyGoals) {
    if (dailyGoals.isEmpty) return 0;
    
    // Group completed goals by date
    final completedByDate = <String, int>{};
    for (final goal in dailyGoals) {
      if (goal['is_completed'] != true) continue;
      
      final dateStr = goal['date']?.toString();
      if (dateStr == null) continue;
      
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      completedByDate[dateKey] = (completedByDate[dateKey] ?? 0) + 1;
    }
    
    if (completedByDate.isEmpty) return 0;
    
    // Calculate streak going backwards from today
    int streak = 0;
    final now = DateTime.now();
    
    for (int i = 0; i < 60; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      
      if (completedByDate.containsKey(dateKey) && completedByDate[dateKey]! > 0) {
        streak++;
      } else if (i == 0) {
        // Today - grace period, don't break streak
        continue;
      } else {
        // No completed goals on this day - streak broken
        break;
      }
    }
    
    return streak;
  }
  
  /// Calculate weekly activity from daily goals
  Map<String, int> _calculateWeeklyActivityFromDailyGoals(List<Map<String, dynamic>> dailyGoals) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activity = <String, int>{};
    
    for (final day in weekDays) {
      activity[day] = 0;
    }
    
    final now = DateTime.now();
    final weekStartDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    
    for (final goal in dailyGoals) {
      // Count completed goals
      if (goal['is_completed'] != true) continue;
      
      final dateStr = goal['date']?.toString();
      if (dateStr == null) continue;
      
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Check if within current week
      if (dateOnly.isAfter(weekStartDate.subtract(const Duration(days: 1))) &&
          dateOnly.isBefore(weekStartDate.add(const Duration(days: 7)))) {
        final dayIndex = dateOnly.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          activity[weekDays[dayIndex]] = (activity[weekDays[dayIndex]] ?? 0) + 1;
        }
      }
    }
    
    return activity;
  }
}
