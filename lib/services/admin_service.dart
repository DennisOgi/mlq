import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/challenge_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import 'supabase_service.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();

  static AdminService get instance => _instance;

  factory AdminService() {
    return _instance;
  }

  Future<List<Map<String, dynamic>>> getTopMonthlyUsers({int limit = 3}) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id,name,avatar_url,school_id,school_name,monthly_xp,xp,coins')
          .order('monthly_xp', ascending: false)
          .order('updated_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching top monthly users: $e');
      return [];
    }
  }

  Future<int> sendMonthlyWinnersCongrats({DateTime? now}) async {
    try {
      final n = now ?? DateTime.now();
      final monthKey = '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}';
      final winners = await getTopMonthlyUsers(limit: 3);
      if (winners.isEmpty) return 0;

      final List<Map<String, dynamic>> inserts = [];
      final List<Map<String, dynamic>> winnerUpserts = [];
      for (var i = 0; i < winners.length; i++) {
        final row = winners[i];
        final userId = (row['id'] ?? '').toString();
        if (userId.isEmpty) continue;
        final rank = i + 1;
        final relatedId = 'monthly_winner:$monthKey:$rank';

        final existing = await _client
            .from('notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('type', 'leaderboard')
            .eq('related_id', relatedId)
            .maybeSingle();
        if (existing != null) continue;

        final name = (row['name'] ?? 'Champion').toString();
        final title = rank == 1
            ? '🏆 ${name.toUpperCase()} — #1 User of the Month!'
            : '🎉 ${name.toUpperCase()} — Top $rank User of the Month!';
        final message = rank == 1
            ? 'You topped the MLQ Monthly Leaderboard for $monthKey. Your consistency is legendary — keep leading by example!'
            : 'You placed #$rank on the MLQ Monthly Leaderboard for $monthKey. Amazing effort — keep going!';

        inserts.add({
          'user_id': userId,
          'title': title,
          'message': message,
          'type': 'leaderboard',
          'related_id': relatedId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        winnerUpserts.add({
          'month_key': monthKey,
          'rank': rank,
          'user_id': userId,
          'name': row['name'],
          'avatar_url': row['avatar_url'],
          'school_name': row['school_name'],
          'monthly_xp': row['monthly_xp'],
          'awarded_at': n.toIso8601String(),
        });
      }

      if (inserts.isEmpty) return 0;
      await _client.from('notifications').insert(inserts);

      // Also persist the monthly winners snapshot for Hall of Fame.
      // Idempotent by (month_key, rank) unique index.
      if (winnerUpserts.isNotEmpty) {
        try {
          await _client
              .from('monthly_winners')
              .upsert(winnerUpserts, onConflict: 'month_key,rank');
        } catch (e) {
          debugPrint('Error upserting monthly_winners: $e');
        }
      }
      return inserts.length;
    } catch (e) {
      debugPrint('Error sending monthly winners congrats: $e');
      return 0;
    }
  }

  // ===== Structured Challenge Rules Management =====
  // Replace (upsert) all rules for a given challenge by first deleting then inserting new set
  Future<bool> replaceChallengeRules(
      String challengeId, List<Map<String, dynamic>> rules) async {
    try {
      // Wrap in a transaction-ish sequence
      await _client
          .from('challenge_rules')
          .delete()
          .eq('challenge_id', challengeId);
      if (rules.isEmpty) return true;
      // Ensure challenge_id is set on each rule
      final rows = rules.map((r) {
        final m = Map<String, dynamic>.from(r);
        m['challenge_id'] = challengeId;
        // Cleanup nulls for optional fields to avoid DB errors
        if (!m.containsKey('window_value_days') ||
            m['window_value_days'] == null) m['window_value_days'] = null;
        if (!m.containsKey('category_filter') ||
            (m['category_filter'] as String?)?.isEmpty == true)
          m['category_filter'] = null;
        if (!m.containsKey('group_id')) m['group_id'] = null;
        if (!m.containsKey('group_operator') ||
            (m['group_operator'] as String?)!.isEmpty)
          m['group_operator'] = 'all';
        return m;
      }).toList();
      await _client.from('challenge_rules').insert(rows);
      return true;
    } catch (e) {
      debugPrint('Error replacing challenge rules: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchChallengeRules(
      String challengeId) async {
    try {
      final resp = await _client
          .from('challenge_rules')
          .select('*')
          .eq('challenge_id', challengeId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(resp as List);
    } catch (e) {
      debugPrint('Error fetching challenge rules: $e');
      return [];
    }
  }

  Future<bool> deleteChallengeRules(String challengeId) async {
    try {
      await _client
          .from('challenge_rules')
          .delete()
          .eq('challenge_id', challengeId);
      return true;
    } catch (e) {
      debugPrint('Error deleting challenge rules: $e');
      return false;
    }
  }

  AdminService._internal();

  // Get Supabase client
  SupabaseClient get _client => SupabaseService.instance.client;

  // Get SupabaseService instance
  SupabaseService get _supabaseService => SupabaseService.instance;

  // Check if user is admin
  Future<bool> isAdmin({UserProvider? userProvider}) async {
    try {
      // If UserProvider is passed, use it directly
      if (userProvider != null) {
        final UserModel? currentUser = userProvider.user;
        if (currentUser != null && currentUser.isAdmin) {
          return true;
        }
      }

      // If not set in UserModel or UserProvider not passed, check Supabase admin_users table
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('admin_users')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final isUserAdmin = response != null;

      // If user is admin in database and UserProvider is passed, update the model
      if (isUserAdmin &&
          userProvider != null &&
          userProvider.user != null &&
          !userProvider.user!.isAdmin) {
        // Update the user model with admin status
        userProvider.updateUser(userProvider.user!.copyWith(isAdmin: true));
      }

      return isUserAdmin;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Get all challenges from Supabase
  Future<List<ChallengeModel>> getAllChallenges() async {
    try {
      final response = await _client.from('challenges').select('*');

      return (response as List)
          .map((challenge) => ChallengeModel.fromJson(challenge))
          .toList();
    } catch (e) {
      debugPrint('Error getting challenges: $e');
      return [];
    }
  }

  // Create a new challenge
  Future<bool> createChallenge(ChallengeModel challenge) async {
    try {
      // Important: insert with explicit id so that challenge_rules.challenge_id matches
      final payload = {
        'id': challenge.id,
        ...challenge.toJson(),
      };
      await _client.from('challenges').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      return false;
    }
  }

  // Update an existing challenge
  Future<bool> updateChallenge(String id, ChallengeModel challenge) async {
    try {
      await _client.from('challenges').update(challenge.toJson()).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating challenge: $e');
      return false;
    }
  }

  // Delete a challenge
  Future<bool> deleteChallenge(String id) async {
    try {
      await _client.from('challenges').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting challenge: $e');
      return false;
    }
  }

  // Create admin user (only to be used by existing admins)
  Future<bool> createAdminUser(String email) async {
    try {
      // Resolve user id by email via profiles table (email should be mirrored there)
      final row = await _client
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (row == null) {
        debugPrint('createAdminUser: No profile found for email: $email');
        return false;
      }

      final userId = row['id'] as String?;
      if (userId == null || userId.isEmpty) {
        debugPrint('createAdminUser: Profile row missing id for email: $email');
        return false;
      }

      // Insert into admin_users (idempotent). If a unique constraint exists on user_id use upsert.
      await _client.from('admin_users').upsert({
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      return true;
    } catch (e) {
      debugPrint('Error creating admin user: $e');
      return false;
    }
  }

  // Remove admin privileges
  Future<bool> removeAdminUser(String userId) async {
    try {
      await _client.from('admin_users').delete().eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Error removing admin user: $e');
      return false;
    }
  }

  // Get all admin users (join with profiles to fetch name/email)
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final response = await _client
          .from('admin_users')
          .select('user_id, profiles (id, name, email)');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting admin users: $e');
      return [];
    }
  }

  // Get participants for a specific challenge
  Future<List<Map<String, dynamic>>> getChallengeParticipants(
      String challengeId) async {
    try {
      final response = await _client
          .from('user_challenges')
          .select('*, profiles(id, name, email)')
          .eq('challenge_id', challengeId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting challenge participants: $e');
      return [];
    }
  }

  // Award XP to challenge winners
  Future<bool> awardChallengeXp({
    required String challengeId,
    required String userId,
    required int xpAmount,
    bool markAsWinner = true,
  }) async {
    try {
      debugPrint(
          'Awarding $xpAmount XP to user $userId for challenge $challengeId');

      // 1. Verify the challenge exists
      final challengeResponse = await _client
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .single();

      if (challengeResponse == null) {
        debugPrint('Challenge not found: $challengeId');
        return false;
      }

      // 2. Verify the user is a participant in this challenge
      final participantResponse = await _client
          .from('user_challenges')
          .select('*')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .single();

      if (participantResponse == null) {
        debugPrint(
            'User $userId is not a participant in challenge $challengeId');
        return false;
      }

      // 3. Add XP to the user's profile (using existing SupabaseService method)
      await _supabaseService.addXpToUser(userId, xpAmount);

      // 4. If markAsWinner is true, update the participant record to indicate winner status
      if (markAsWinner) {
        await _client
            .from('user_challenges')
            .update({
              'is_completed': true,
              'completion_date': DateTime.now().toIso8601String(),
            })
            .eq('challenge_id', challengeId)
            .eq('user_id', userId);
      }

      debugPrint(
          'Successfully awarded $xpAmount XP to user $userId for challenge $challengeId');
      return true;
    } catch (e) {
      debugPrint('Error awarding challenge XP: $e');
      return false;
    }
  }

  // Get analytics data for the admin dashboard
  Future<Map<String, dynamic>> getAnalyticsData() async {
    try {
      // Get basic counts from database
      final usersResponse = await _client.from('profiles').select('id');
      final totalUsers = usersResponse.length;

      final challengesResponse =
          await _client.from('challenges').select('id,title');
      final totalChallenges = challengesResponse.length;

      // Calculate active users: any user with activity in last 30 days across core features
      final sinceIso =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final Set<String> activeUserIds = {};
      try {
        final goals = await _client
            .from('daily_goals')
            .select('user_id, updated_at')
            .gte('updated_at', sinceIso);
        for (final r in (goals as List)) {
          final uid = (r['user_id'] ?? '').toString();
          if (uid.isNotEmpty) activeUserIds.add(uid);
        }
      } catch (_) {}
      try {
        final completions = await _client
            .from('goal_completions')
            .select('user_id, completed_at')
            .gte('completed_at', sinceIso);
        for (final r in (completions as List)) {
          final uid = (r['user_id'] ?? '').toString();
          if (uid.isNotEmpty) activeUserIds.add(uid);
        }
      } catch (_) {}
      try {
        final convos = await _client
            .from('ai_coach_conversations')
            .select('user_id, updated_at')
            .gte('updated_at', sinceIso);
        for (final r in (convos as List)) {
          final uid = (r['user_id'] ?? '').toString();
          if (uid.isNotEmpty) activeUserIds.add(uid);
        }
      } catch (_) {}
      try {
        final courses = await _client
            .from('user_course_progress')
            .select('user_id, completed_at, started_at')
            .or('completed_at.gte.$sinceIso,started_at.gte.$sinceIso');
        for (final r in (courses as List)) {
          final uid = (r['user_id'] ?? '').toString();
          if (uid.isNotEmpty) activeUserIds.add(uid);
        }
      } catch (_) {}
      try {
        final posts = await _client
            .from('posts')
            .select('user_id, created_at')
            .gte('created_at', sinceIso);
        for (final r in (posts as List)) {
          final uid = (r['user_id'] ?? '').toString();
          if (uid.isNotEmpty) activeUserIds.add(uid);
        }
      } catch (_) {}
      final activeUsers = activeUserIds.length;

      // Get challenge participations
      final participationsResponse =
          await _client.from('user_challenges').select('*');
      final totalParticipations = participationsResponse.length;

      // Calculate completion rate
      final completedParticipations =
          participationsResponse.where((p) => p['is_completed'] == true).length;
      final completionRate = totalParticipations > 0
          ? completedParticipations / totalParticipations
          : 0.0;

      // Get challenge engagement data
      final challengeLabels = <String>[];
      final challengeData = <int>[];

      for (final challenge in challengesResponse) {
        challengeLabels.add(challenge['title'] ?? 'Unknown');
        final participantCount = participationsResponse
            .where((p) => p['challenge_id'] == challenge['id'])
            .length;
        challengeData.add(participantCount);
      }

      // Simple user activity sparkline (last 7 days based on goal completions)
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final Map<int, int> dowCounts = {
        0: 0,
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0
      };
      try {
        final since7 =
            DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
        final recent = await _client
            .from('goal_completions')
            .select('completed_at')
            .gte('completed_at', since7);
        for (final r in (recent as List)) {
          final ts = DateTime.tryParse((r['completed_at'] ?? '').toString());
          if (ts != null) {
            final idx = (ts.weekday % 7); // 1..7 -> 1..6,0
            dowCounts[idx] = (dowCounts[idx] ?? 0) + 1;
          }
        }
      } catch (_) {}
      final userActivityData = List.generate(
          7,
          (i) => {
                'day': weekdays[i],
                'count': dowCounts[i] ?? 0,
              });

      return {
        'total_users': totalUsers,
        'active_users': activeUsers,
        'total_challenges': totalChallenges,
        'total_participations': totalParticipations,
        'completion_rate': completionRate,
        'avg_session_duration': 24.5,
        'challenge_engagement': {
          'labels': challengeLabels.take(10).toList(),
          'data': challengeData.take(10).toList(),
        },
        'user_activity': {
          'labels': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          'data': userActivityData,
        },
      };
    } catch (e) {
      debugPrint('Error getting analytics data: $e');
      // Return fallback data
      return {
        'total_users': 0,
        'active_users': 0,
        'total_challenges': 0,
        'total_participations': 0,
        'completion_rate': 0.0,
        'avg_session_duration': 0.0,
        'challenge_engagement': {
          'labels': ['No Data'],
          'data': [0],
        },
        'user_activity': {
          'labels': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          'data': [
            {'day': 'Mon', 'count': 0},
            {'day': 'Tue', 'count': 0},
            {'day': 'Wed', 'count': 0},
            {'day': 'Thu', 'count': 0},
            {'day': 'Fri', 'count': 0},
            {'day': 'Sat', 'count': 0},
            {'day': 'Sun', 'count': 0},
          ],
        },
      };
    }
  }

  // ===== Community Management =====

  /// Get all pending community requests
  Future<List<Map<String, dynamic>>> getPendingCommunities() async {
    try {
      final response = await _client
          .from('communities')
          .select('*, profiles!communities_created_by_fkey(name)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      debugPrint('Fetched ${(response as List).length} pending communities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending communities: $e');
      return [];
    }
  }

  /// Get all communities (for admin overview)
  Future<List<Map<String, dynamic>>> getAllCommunities() async {
    try {
      final response = await _client
          .from('communities')
          .select('*, profiles!communities_created_by_fkey(name)')
          .order('created_at', ascending: false);
      debugPrint('Fetched ${(response as List).length} communities');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all communities: $e');
      return [];
    }
  }

  /// Approve a community request
  Future<bool> approveCommunity(String communityId) async {
    try {
      await _client
          .from('communities')
          .update({'status': 'active'}).eq('id', communityId);

      // Also add the creator as an owner member if not already
      final community = await _client
          .from('communities')
          .select('created_by')
          .eq('id', communityId)
          .single();

      final creatorId = community['created_by'];

      // Check if membership exists (table uses composite key, not id column)
      final existing = await _client
          .from('community_members')
          .select('community_id')
          .eq('community_id', communityId)
          .eq('user_id', creatorId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('community_members').insert({
          'community_id': communityId,
          'user_id': creatorId,
          'role': 'owner',
          'status': 'active',
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error approving community: $e');
      return false;
    }
  }

  /// Reject a community request
  Future<bool> rejectCommunity(String communityId, {String? reason}) async {
    try {
      await _client.from('communities').update({
        'status': 'rejected',
        if (reason != null) 'rejection_reason': reason,
      }).eq('id', communityId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting community: $e');
      return false;
    }
  }

  /// Suspend an active community
  Future<bool> suspendCommunity(String communityId, {String? reason}) async {
    try {
      await _client.from('communities').update({
        'status': 'suspended',
        if (reason != null) 'suspension_reason': reason,
      }).eq('id', communityId);
      return true;
    } catch (e) {
      debugPrint('Error suspending community: $e');
      return false;
    }
  }

  /// Reactivate a suspended community
  Future<bool> reactivateCommunity(String communityId) async {
    try {
      await _client
          .from('communities')
          .update({'status': 'active'}).eq('id', communityId);
      return true;
    } catch (e) {
      debugPrint('Error reactivating community: $e');
      return false;
    }
  }

  // ===== Maintenance Notice Management =====

  /// Create a maintenance notice that will be shown to all users
  Future<bool> createMaintenanceNotice({
    required String title,
    required String message,
    String priority = 'normal',
    DateTime? endTime,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client.from('maintenance_notices').insert({
        'title': title,
        'message': message,
        'priority': priority,
        'is_active': true,
        'end_time': endTime?.toIso8601String(),
        'created_by': userId,
      });

      // Also create notifications for all users with FCM tokens
      await _sendMaintenanceNotificationToAllUsers(title, message, priority);

      return true;
    } catch (e) {
      debugPrint('Error creating maintenance notice: $e');
      return false;
    }
  }

  /// Send push notification to all users about maintenance
  Future<void> _sendMaintenanceNotificationToAllUsers(
    String title,
    String message,
    String priority,
  ) async {
    try {
      // Insert notifications for all users
      final users =
          await _client.from('profiles').select('id').not('id', 'is', null);

      final notifications = (users as List)
          .map((user) => {
                'user_id': user['id'],
                'title': priority == 'critical' ? '⚠️ $title' : '📢 $title',
                'message': message,
                'type': 'system',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      if (notifications.isNotEmpty) {
        // Insert in batches to avoid timeout
        const batchSize = 100;
        for (var i = 0; i < notifications.length; i += batchSize) {
          final batch = notifications.skip(i).take(batchSize).toList();
          await _client.from('notifications').insert(batch);
        }
      }

      debugPrint(
          'Sent maintenance notification to ${notifications.length} users');
    } catch (e) {
      debugPrint('Error sending maintenance notifications: $e');
    }
  }

  /// Get all maintenance notices (for admin view)
  Future<List<Map<String, dynamic>>> getAllMaintenanceNotices() async {
    try {
      final response = await _client
          .from('maintenance_notices')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting maintenance notices: $e');
      return [];
    }
  }

  /// Get active maintenance notices (for user view)
  Future<List<Map<String, dynamic>>> getActiveMaintenanceNotices() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('maintenance_notices')
          .select('*')
          .eq('is_active', true)
          .or('end_time.is.null,end_time.gt.$now')
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting active maintenance notices: $e');
      return [];
    }
  }

  /// Deactivate a maintenance notice
  Future<bool> deactivateMaintenanceNotice(String noticeId) async {
    try {
      await _client.from('maintenance_notices').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', noticeId);
      return true;
    } catch (e) {
      debugPrint('Error deactivating maintenance notice: $e');
      return false;
    }
  }

  /// Delete a maintenance notice
  Future<bool> deleteMaintenanceNotice(String noticeId) async {
    try {
      await _client.from('maintenance_notices').delete().eq('id', noticeId);
      return true;
    } catch (e) {
      debugPrint('Error deleting maintenance notice: $e');
      return false;
    }
  }
}
