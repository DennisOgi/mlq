import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  // ===== USER ANALYTICS =====

  Future<Map<String, dynamic>> getUserAnalytics() async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));
      final last7Days = now.subtract(const Duration(days: 7));
      final yesterday = now.subtract(const Duration(days: 1));

      // Total users
      final totalUsersResp = await _client
          .from('profiles')
          .select('id, created_at, is_premium, school_id');
      final totalUsers = totalUsersResp.length;

      // Premium users
      final premiumUsers =
          (totalUsersResp as List).where((u) => u['is_premium'] == true).length;

      // School users
      final schoolUsers =
          (totalUsersResp).where((u) => u['school_id'] != null).length;

      // New users (last 30 days)
      final newUsers = (totalUsersResp).where((u) {
        final created = DateTime.tryParse(u['created_at'] ?? '');
        return created != null && created.isAfter(last30Days);
      }).length;

      // Active users (last 7 days) - users with any activity
      final activeUserIds = await _getActiveUserIds(last7Days);
      final activeUsers7d = activeUserIds.length;

      // Daily active users (yesterday)
      final dauIds = await _getActiveUserIds(yesterday);
      final dau = dauIds.length;

      // User growth trend (last 30 days)
      final userGrowth = await _getUserGrowthTrend(30);

      // User retention (7-day, 30-day)
      final retention = await _getUserRetention();

      // User engagement by feature
      final featureEngagement = await _getFeatureEngagement(last30Days);

      return {
        'total_users': totalUsers,
        'premium_users': premiumUsers,
        'school_users': schoolUsers,
        'free_users': totalUsers - premiumUsers - schoolUsers,
        'new_users_30d': newUsers,
        'active_users_7d': activeUsers7d,
        'dau': dau,
        'premium_conversion_rate':
            totalUsers > 0 ? (premiumUsers / totalUsers * 100) : 0.0,
        'user_growth': userGrowth,
        'retention': retention,
        'feature_engagement': featureEngagement,
      };
    } catch (e) {
      debugPrint('Error getting user analytics: $e');
      return _getEmptyUserAnalytics();
    }
  }

  // ===== ENGAGEMENT ANALYTICS =====

  Future<Map<String, dynamic>> getEngagementAnalytics() async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));

      // Goals
      final goalsData = await _getGoalsAnalytics(last30Days);

      // Challenges
      final challengesData = await _getChallengesAnalytics(last30Days);

      // Mini courses
      final coursesData = await _getCoursesAnalytics(last30Days);

      // Victory Wall
      final victoryWallData = await _getVictoryWallAnalytics(last30Days);

      // AI Coach
      final aiCoachData = await _getAICoachAnalytics(last30Days);

      // Gratitude Journal
      final gratitudeData = await _getGratitudeAnalytics(last30Days);

      return {
        'goals': goalsData,
        'challenges': challengesData,
        'courses': coursesData,
        'victory_wall': victoryWallData,
        'ai_coach': aiCoachData,
        'gratitude': gratitudeData,
      };
    } catch (e) {
      debugPrint('Error getting engagement analytics: $e');
      return {};
    }
  }

  // ===== REVENUE ANALYTICS =====

  Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      final now = DateTime.now();
      final last30Days = now.subtract(const Duration(days: 30));

      // Subscription revenue
      final subscriptions = await _client
          .from('user_subscriptions')
          .select('*, subscription_plans(price)')
          .gte('created_at', last30Days.toIso8601String());

      double totalRevenue = 0;
      int paidSubscriptions = 0;

      for (final sub in (subscriptions as List)) {
        final plan = sub['subscription_plans'];
        if (plan != null) {
          final price = double.tryParse(plan['price']?.toString() ?? '0') ?? 0;
          if (price > 0) {
            totalRevenue += price;
            paidSubscriptions++;
          }
        }
      }

      // Coin purchases
      final coinPurchases = await _client
          .from('payment_attempts')
          .select('amount, status, created_at')
          .eq('status', 'successful')
          .gte('created_at', last30Days.toIso8601String());

      double coinRevenue = 0;
      for (final purchase in (coinPurchases as List)) {
        coinRevenue +=
            double.tryParse(purchase['amount']?.toString() ?? '0') ?? 0;
      }

      // Revenue trend
      final revenueTrend = await _getRevenueTrend(30);

      // MRR (Monthly Recurring Revenue)
      final mrr = await _calculateMRR();

      // ARPU (Average Revenue Per User)
      final totalUsersResp = await _client.from('profiles').select('id');
      final arpu =
          totalUsersResp.isNotEmpty ? totalRevenue / totalUsersResp.length : 0;

      return {
        'total_revenue_30d': totalRevenue,
        'subscription_revenue': totalRevenue - coinRevenue,
        'coin_revenue': coinRevenue,
        'paid_subscriptions': paidSubscriptions,
        'mrr': mrr,
        'arpu': arpu,
        'revenue_trend': revenueTrend,
      };
    } catch (e) {
      debugPrint('Error getting revenue analytics: $e');
      return {
        'total_revenue_30d': 0,
        'subscription_revenue': 0,
        'coin_revenue': 0,
        'paid_subscriptions': 0,
        'mrr': 0,
        'arpu': 0,
        'revenue_trend': [],
      };
    }
  }

  // ===== CONTENT ANALYTICS =====

  Future<Map<String, dynamic>> getContentAnalytics() async {
    try {
      // Challenge performance
      final challenges = await _client
          .from('challenges')
          .select('id, title, type, created_at');

      final challengePerformance = <Map<String, dynamic>>[];

      for (final challenge in (challenges as List)) {
        final participants = await _client
            .from('user_challenges')
            .select('id, is_completed, progress')
            .eq('challenge_id', challenge['id']);

        final totalParticipants = participants.length;
        final completed = (participants as List)
            .where((p) => p['is_completed'] == true)
            .length;
        final avgProgress = totalParticipants > 0
            ? (participants).fold<int>(
                    0, (sum, p) => sum + (p['progress'] as int? ?? 0)) /
                totalParticipants
            : 0.0;

        challengePerformance.add({
          'id': challenge['id'],
          'title': challenge['title'],
          'type': challenge['type'],
          'participants': totalParticipants,
          'completed': completed,
          'completion_rate': totalParticipants > 0
              ? (completed / totalParticipants * 100)
              : 0.0,
          'avg_progress': avgProgress,
        });
      }

      // Sort by participants
      challengePerformance.sort((a, b) =>
          (b['participants'] as int).compareTo(a['participants'] as int));

      // Course completion rates
      final courseProgress = await _client
          .from('user_course_progress')
          .select('completed, progress_percentage');

      final totalCourseAttempts = courseProgress.length;
      final completedCourses =
          (courseProgress as List).where((c) => c['completed'] == true).length;
      final avgCourseProgress = totalCourseAttempts > 0
          ? (courseProgress).fold<int>(0,
                  (sum, c) => sum + (c['progress_percentage'] as int? ?? 0)) /
              totalCourseAttempts
          : 0.0;

      // Badge distribution
      final badges = await _client.from('user_badges').select('badge_id');
      final badgeCount = <String, int>{};
      for (final badge in (badges as List)) {
        final id = badge['badge_id'] as String;
        badgeCount[id] = (badgeCount[id] ?? 0) + 1;
      }

      return {
        'challenge_performance': challengePerformance.take(20).toList(),
        'total_challenges': challenges.length,
        'course_completion_rate': totalCourseAttempts > 0
            ? (completedCourses / totalCourseAttempts * 100)
            : 0.0,
        'avg_course_progress': avgCourseProgress,
        'total_badges_earned': badges.length,
        'unique_badges': badgeCount.length,
      };
    } catch (e) {
      debugPrint('Error getting content analytics: $e');
      return {};
    }
  }

  // ===== HELPER METHODS =====

  Future<Set<String>> _getActiveUserIds(DateTime since) async {
    final Set<String> activeIds = {};
    final sinceIso = since.toIso8601String();

    try {
      // Goals
      final goals = await _client
          .from('daily_goals')
          .select('user_id')
          .gte('updated_at', sinceIso);
      for (final r in (goals as List)) {
        final uid = r['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) activeIds.add(uid);
      }

      // Goal completions
      final completions = await _client
          .from('goal_completions')
          .select('user_id')
          .gte('completed_at', sinceIso);
      for (final r in (completions as List)) {
        final uid = r['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) activeIds.add(uid);
      }

      // Posts
      final posts = await _client
          .from('posts')
          .select('user_id')
          .gte('created_at', sinceIso);
      for (final r in (posts as List)) {
        final uid = r['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) activeIds.add(uid);
      }

      // Courses
      final courses = await _client
          .from('user_course_progress')
          .select('user_id')
          .gte('last_accessed_at', sinceIso);
      for (final r in (courses as List)) {
        final uid = r['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) activeIds.add(uid);
      }

      // AI Coach
      final coach = await _client
          .from('ai_coach_conversations')
          .select('user_id')
          .gte('updated_at', sinceIso);
      for (final r in (coach as List)) {
        final uid = r['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) activeIds.add(uid);
      }
    } catch (e) {
      debugPrint('Error getting active user IDs: $e');
    }

    return activeIds;
  }

  Future<List<Map<String, dynamic>>> _getUserGrowthTrend(int days) async {
    final trend = <Map<String, dynamic>>[];
    final now = DateTime.now();

    try {
      final allUsers = await _client.from('profiles').select('created_at');

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final count = (allUsers as List).where((u) {
          final created = DateTime.tryParse(u['created_at'] ?? '');
          return created != null &&
              created.year == date.year &&
              created.month == date.month &&
              created.day == date.day;
        }).length;

        trend.add({'date': dateStr, 'count': count});
      }
    } catch (e) {
      debugPrint('Error getting user growth trend: $e');
    }

    return trend;
  }

  Future<Map<String, dynamic>> _getUserRetention() async {
    try {
      final now = DateTime.now();
      final day7 = now.subtract(const Duration(days: 7));
      final day30 = now.subtract(const Duration(days: 30));

      // Users who signed up 7 days ago
      final users7d = await _client
          .from('profiles')
          .select('id, created_at')
          .lte('created_at', day7.toIso8601String())
          .gte('created_at',
              day7.subtract(const Duration(days: 1)).toIso8601String());

      // Check how many are still active
      final active7d = await _getActiveUserIds(day7);
      final retained7d =
          (users7d as List).where((u) => active7d.contains(u['id'])).length;
      final retention7d =
          users7d.isNotEmpty ? (retained7d / users7d.length * 100) : 0.0;

      // Users who signed up 30 days ago
      final users30d = await _client
          .from('profiles')
          .select('id, created_at')
          .lte('created_at', day30.toIso8601String())
          .gte('created_at',
              day30.subtract(const Duration(days: 1)).toIso8601String());

      final active30d = await _getActiveUserIds(day30);
      final retained30d =
          (users30d as List).where((u) => active30d.contains(u['id'])).length;
      final retention30d =
          users30d.isNotEmpty ? (retained30d / users30d.length * 100) : 0.0;

      return {
        'day_7': retention7d,
        'day_30': retention30d,
      };
    } catch (e) {
      debugPrint('Error calculating retention: $e');
      return {'day_7': 0.0, 'day_30': 0.0};
    }
  }

  Future<Map<String, int>> _getFeatureEngagement(DateTime since) async {
    final sinceIso = since.toIso8601String();

    try {
      final goals = await _client
          .from('daily_goals')
          .select('id')
          .gte('created_at', sinceIso);
      final challenges = await _client
          .from('user_challenges')
          .select('id')
          .gte('created_at', sinceIso);
      final courses = await _client
          .from('user_course_progress')
          .select('id')
          .gte('started_at', sinceIso);
      final posts =
          await _client.from('posts').select('id').gte('created_at', sinceIso);
      final gratitude = await _client
          .from('gratitude_entries')
          .select('id')
          .gte('created_at', sinceIso);
      final coach = await _client
          .from('ai_coach_messages')
          .select('id')
          .gte('created_at', sinceIso);

      return {
        'goals': goals.length,
        'challenges': challenges.length,
        'courses': courses.length,
        'victory_wall': posts.length,
        'gratitude': gratitude.length,
        'ai_coach': coach.length,
      };
    } catch (e) {
      debugPrint('Error getting feature engagement: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getGoalsAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final dailyGoals = await _client
          .from('daily_goals')
          .select('*')
          .gte('created_at', sinceIso);
      final mainGoals = await _client
          .from('main_goals')
          .select('*')
          .gte('created_at', sinceIso);
      final completions = await _client
          .from('goal_completions')
          .select('*')
          .gte('completed_at', sinceIso);

      final totalDaily = dailyGoals.length;
      final completedDaily =
          (dailyGoals as List).where((g) => g['is_completed'] == true).length;

      return {
        'total_daily_goals': totalDaily,
        'completed_daily_goals': completedDaily,
        'completion_rate':
            totalDaily > 0 ? (completedDaily / totalDaily * 100) : 0.0,
        'total_main_goals': mainGoals.length,
        'total_completions': completions.length,
      };
    } catch (e) {
      debugPrint('Error getting goals analytics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getChallengesAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final participations = await _client
          .from('user_challenges')
          .select('*')
          .gte('start_date', sinceIso);
      final completed = (participations as List)
          .where((p) => p['is_completed'] == true)
          .length;

      return {
        'total_participations': participations.length,
        'completed': completed,
        'completion_rate': participations.isNotEmpty
            ? (completed / participations.length * 100)
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting challenges analytics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getCoursesAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final progress = await _client
          .from('user_course_progress')
          .select('*')
          .gte('started_at', sinceIso);
      final completed =
          (progress as List).where((p) => p['completed'] == true).length;

      return {
        'total_started': progress.length,
        'completed': completed,
        'completion_rate':
            progress.isNotEmpty ? (completed / progress.length * 100) : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting courses analytics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getVictoryWallAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final posts =
          await _client.from('posts').select('*').gte('created_at', sinceIso);
      final comments = await _client
          .from('post_comments')
          .select('*')
          .gte('created_at', sinceIso);
      final likes = await _client
          .from('post_likes')
          .select('*')
          .gte('created_at', sinceIso);

      return {
        'total_posts': posts.length,
        'total_comments': comments.length,
        'total_likes': likes.length,
        'avg_engagement': posts.isNotEmpty
            ? ((comments.length + likes.length) / posts.length)
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting victory wall analytics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getAICoachAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final conversations = await _client
          .from('ai_coach_conversations')
          .select('*')
          .gte('created_at', sinceIso);
      final messages = await _client
          .from('ai_coach_messages')
          .select('*')
          .gte('created_at', sinceIso);

      return {
        'total_conversations': conversations.length,
        'total_messages': messages.length,
        'avg_messages_per_conversation': conversations.isNotEmpty
            ? (messages.length / conversations.length)
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting AI coach analytics: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getGratitudeAnalytics(DateTime since) async {
    try {
      final sinceIso = since.toIso8601String();

      final entries = await _client
          .from('gratitude_entries')
          .select('*')
          .gte('created_at', sinceIso);

      return {
        'total_entries': entries.length,
      };
    } catch (e) {
      debugPrint('Error getting gratitude analytics: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _getRevenueTrend(int days) async {
    final trend = <Map<String, dynamic>>[];
    final now = DateTime.now();

    try {
      final subscriptions = await _client
          .from('user_subscriptions')
          .select('created_at, subscription_plans(price)');

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        double revenue = 0;
        for (final sub in (subscriptions as List)) {
          final created = DateTime.tryParse(sub['created_at'] ?? '');
          if (created != null &&
              created.year == date.year &&
              created.month == date.month &&
              created.day == date.day) {
            final plan = sub['subscription_plans'];
            if (plan != null) {
              revenue += double.tryParse(plan['price']?.toString() ?? '0') ?? 0;
            }
          }
        }

        trend.add({'date': dateStr, 'revenue': revenue});
      }
    } catch (e) {
      debugPrint('Error getting revenue trend: $e');
    }

    return trend;
  }

  Future<double> _calculateMRR() async {
    try {
      final activeSubscriptions = await _client
          .from('user_subscriptions')
          .select('subscription_plans(price, duration_days)')
          .eq('is_active', true);

      double mrr = 0;
      for (final sub in (activeSubscriptions as List)) {
        final plan = sub['subscription_plans'];
        if (plan != null) {
          final price = double.tryParse(plan['price']?.toString() ?? '0') ?? 0;
          final days = plan['duration_days'] as int? ?? 30;
          // Normalize to monthly
          mrr += (price / days) * 30;
        }
      }

      return mrr;
    } catch (e) {
      debugPrint('Error calculating MRR: $e');
      return 0;
    }
  }

  Map<String, dynamic> _getEmptyUserAnalytics() {
    return {
      'total_users': 0,
      'premium_users': 0,
      'school_users': 0,
      'free_users': 0,
      'new_users_30d': 0,
      'active_users_7d': 0,
      'dau': 0,
      'premium_conversion_rate': 0.0,
      'user_growth': [],
      'retention': {'day_7': 0.0, 'day_30': 0.0},
      'feature_engagement': {},
    };
  }
}
