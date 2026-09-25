import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class SubscriptionService {
  // Singleton pattern
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final SupabaseClient _client = SupabaseService().client;
  final _uuid = Uuid();

  // Get all subscription plans
  Future<List<Map<String, dynamic>>> getAllPlans() async {
    try {
      final response = await _client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price', ascending: true);

      return response
          .where((plan) =>
              (plan['name'] as String? ?? '').toLowerCase() != 'yearly')
          .toList();
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      return [];
    }
  }

  // Get a user's active (in-period) subscription
  Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('user_subscriptions')
          .select('*, subscription_plans(*)')
          .eq('user_id', userId)
          .gt('end_date', now)
          .or('is_active.eq.true,cancelled_at.not.is.null')
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching active subscription: $e');
      return null;
    }
  }

  // Check if user is on a trial subscription
  Future<bool> isOnTrial(String userId) async {
    final activeSubscription = await getActiveSubscription(userId);
    if (activeSubscription == null) return false;

    final planName = activeSubscription['subscription_plans']['name'];
    return planName == 'Trial';
  }

  // Check if user has an active paid subscription (Monthly/Quarterly/legacy)
  Future<bool> isPremium(String userId) async {
    final activeSubscription = await getActiveSubscription(userId);
    if (activeSubscription == null) return false;

    final plan = activeSubscription['subscription_plans'];
    if (plan == null) return false;
    final planName = (plan['name'] as String? ?? '').toLowerCase();
    final price = (plan['price'] as num?) ?? 0;
    if (price > 0) return true;
    return planName == 'premium' ||
        planName == 'monthly' ||
        planName == 'quarterly' ||
        planName == 'basic' ||
        planName == 'trial';
  }

  // Check if user has any active subscription (including Trial)
  Future<bool> hasActiveSubscription(String userId) async {
    final activeSubscription = await getActiveSubscription(userId);
    return activeSubscription != null;
  }

  // Activate a trial subscription (idempotent)
  Future<bool> activateTrialSubscription(String userId) async {
    try {
      if (await hasActiveSubscription(userId)) {
        debugPrint('Trial/subscription already active for $userId');
        await _client.rpc('sync_profile_premium_flag', params: {
          'p_user_id': userId,
        });
        return true;
      }

      final trialPlans = await _client
          .from('subscription_plans')
          .select()
          .eq('name', 'Trial')
          .eq('is_active', true);

      if (trialPlans.isEmpty) {
        debugPrint('No active trial plan found');
        return false;
      }

      final trialPlan = trialPlans[0];
      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: trialPlan['duration_days']));

      await _client.from('user_subscriptions').insert({
        'id': _uuid.v4(),
        'user_id': userId,
        'plan_id': trialPlan['id'],
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_active': true,
        'auto_renew': false,
      });

      await _client.rpc('sync_profile_premium_flag', params: {
        'p_user_id': userId,
      });

      return true;
    } catch (e) {
      debugPrint('Error activating trial subscription: $e');
      return false;
    }
  }

  // Apply subscription benefits
  Future<bool> applySubscriptionBenefits(String userId, String planId) async {
    try {
      final plan = await _client
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      final features = plan['features'];
      if (features != null && features['coins'] != null) {
        final int coins = features['coins'];
        if (coins > 0) {
          debugPrint(
            'Subscription coin bonus should be granted server-side '
            '(plan=${plan['name']} coins=$coins)',
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error applying subscription benefits: $e');
      return false;
    }
  }

  // Create a new subscription WITHOUT payment — blocked for production safety.
  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String planPeriod,
  }) async {
    debugPrint(
      '⚠️ createSubscription blocked — use Flutterwave checkout instead '
      '(user=$userId plan=$planId period=$planPeriod)',
    );
    return false;
  }

  // Cancel a subscription — keeps access until end_date
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      final result = await _client.rpc(
        'cancel_user_subscription',
        params: {'p_subscription_id': subscriptionId},
      );
      return result == true;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  Future<bool> setAutoRenewal(String subscriptionId, bool autoRenew) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('user_subscriptions')
          .update({
            'auto_renew': autoRenew,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error updating auto-renewal: $e');
      return false;
    }
  }

  // Expire caller's past-due subscriptions and sync premium cache
  Future<void> checkForExpiredSubscriptions() async {
    try {
      await _client.rpc('expire_my_subscriptions');
    } catch (e) {
      debugPrint('Error checking for expired subscriptions: $e');
    }
  }

  // ========== FREE TRIAL SYSTEM ==========

  Future<String> getUserAccessLevel(String userId) async {
    try {
      final subscription = await getActiveSubscription(userId);
      if (subscription == null) return 'free';

      final planName = subscription['subscription_plans']['name'] as String;
      return planName.toLowerCase();
    } catch (e) {
      debugPrint('Error getting user access level: $e');
      return 'free';
    }
  }

  Future<bool> isTrialActive(String userId) async {
    final level = await getUserAccessLevel(userId);
    return level == 'trial';
  }

  /// True when user previously had a Trial that ended and has no current access.
  Future<bool> isTrialExpired(String userId) async {
    try {
      if (await hasActiveSubscription(userId)) return false;

      final pastTrials = await _client
          .from('user_subscriptions')
          .select('id, end_date, subscription_plans!inner(name)')
          .eq('user_id', userId)
          .eq('subscription_plans.name', 'Trial')
          .lt('end_date', DateTime.now().toIso8601String())
          .limit(1);

      return pastTrials.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if trial expired: $e');
      return false;
    }
  }

  Future<int> getTrialDaysRemaining(String userId) async {
    try {
      final subscription = await getActiveSubscription(userId);
      if (subscription == null) return 0;

      final planName = subscription['subscription_plans']['name'] as String;
      if (planName != 'Trial') return 0;

      final endDate = DateTime.parse(subscription['end_date'] as String);
      final remaining = endDate.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) return 0;
      final days = (remaining.inMilliseconds / Duration.millisecondsPerDay)
          .ceil();
      return days < 1 ? 1 : days;
    } catch (e) {
      debugPrint('Error getting trial days remaining: $e');
      return 0;
    }
  }

  bool _hasPremiumAccess(String level) {
    return [
      'trial',
      'basic',
      'premium',
      'monthly',
      'quarterly',
      'yearly',
    ].contains(level);
  }

  Future<bool> canAccessMiniCourses(String userId) async {
    final level = await getUserAccessLevel(userId);
    return _hasPremiumAccess(level);
  }

  Future<bool> canAccessBasicChallenges(String userId) async {
    final level = await getUserAccessLevel(userId);
    return _hasPremiumAccess(level);
  }

  Future<bool> canAccessPremiumChallenges(String userId) async {
    final level = await getUserAccessLevel(userId);
    return _hasPremiumAccess(level);
  }

  Future<bool> isTrialExpiringSoon(String userId) async {
    final daysRemaining = await getTrialDaysRemaining(userId);
    return daysRemaining > 0 && daysRemaining <= 3;
  }

  Future<Map<String, dynamic>> getUserAccessStatus(String userId) async {
    final level = await getUserAccessLevel(userId);
    final daysRemaining = await getTrialDaysRemaining(userId);
    final isExpiringSoon = await isTrialExpiringSoon(userId);
    final trialExpired = await isTrialExpired(userId);

    return {
      'access_level': level,
      'is_trial': level == 'trial',
      'is_free': level == 'free',
      'is_basic': level == 'basic',
      'is_premium': _hasPremiumAccess(level),
      'trial_days_remaining': daysRemaining,
      'trial_expiring_soon': isExpiringSoon,
      'trial_expired': trialExpired,
      'can_access_mini_courses': await canAccessMiniCourses(userId),
      'can_access_basic_challenges': await canAccessBasicChallenges(userId),
      'can_access_premium_challenges': await canAccessPremiumChallenges(userId),
    };
  }

  Future<Map<String, dynamic>> getTrialStatus(String userId) async {
    final level = await getUserAccessLevel(userId);
    final daysRemaining = await getTrialDaysRemaining(userId);
    final trialExpired = await isTrialExpired(userId);

    return {
      'isOnTrial': level == 'trial',
      'daysRemaining': daysRemaining,
      'isExpiringSoon': daysRemaining > 0 && daysRemaining <= 3,
      'isExpired': trialExpired,
    };
  }

  Future<bool> assignTrialPlan(String userId) async {
    return await activateTrialSubscription(userId);
  }
}
