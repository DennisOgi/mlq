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

      return response;
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      return [];
    }
  }

  // Get a user's active subscription
  Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    try {
      final response = await _client
          .from('user_subscriptions')
          .select('*, subscription_plans(*)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .single();

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

  // Check if user has an active premium subscription
  Future<bool> isPremium(String userId) async {
    final activeSubscription = await getActiveSubscription(userId);
    if (activeSubscription == null) return false;

    final planName = activeSubscription['subscription_plans']['name'];
    return planName == 'Premium';
  }

  // Check if user has any active subscription (including Basic)
  Future<bool> hasActiveSubscription(String userId) async {
    final activeSubscription = await getActiveSubscription(userId);
    return activeSubscription != null;
  }

  // Activate a trial subscription
  Future<bool> activateTrialSubscription(String userId) async {
    try {
      // Get the trial plan
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

      // Create the subscription
      await _client.from('user_subscriptions').insert({
        'id': _uuid.v4(),
        'user_id': userId,
        'plan_id': trialPlan['id'],
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_active': true,
        'auto_renew': false,
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
      // Get the plan to determine benefits
      final plan = await _client
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      // Award coins based on plan
      final features = plan['features'];
      if (features != null && features['coins'] != null) {
        final int coins = features['coins'];
        if (coins > 0) {
          // Get coin service to award coins
          // This would typically be injected, but for simplicity we're using a direct call
          final coinService = CoinService();
          await coinService.addCoins(
              userId: userId,
              amount: coins,
              description: 'Subscription bonus: ${plan['name']}',
              transactionType: 'subscription_bonus',
              referenceType: 'subscription_plan',
              referenceId: planId);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error applying subscription benefits: $e');
      return false;
    }
  }

  // Create a new subscription (without payment for now)
  Future<bool> createSubscription({
    required String userId,
    required String planId,
    required String planPeriod,
  }) async {
    try {
      // Get the plan
      final plan = await _client
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      // Calculate duration based on period
      int durationDays = plan['duration_days'];
      if (planPeriod == 'Quarterly') {
        durationDays = 90;
      } else if (planPeriod == 'Yearly') {
        durationDays = 365;
      }

      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: durationDays));

      // Deactivate any current subscriptions
      await _client
          .from('user_subscriptions')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('is_active', true);

      // Create the new subscription
      final subscriptionId = _uuid.v4();
      await _client.from('user_subscriptions').insert({
        'id': subscriptionId,
        'user_id': userId,
        'plan_id': planId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_active': true,
        'auto_renew': true,
      });

      // Apply benefits
      await applySubscriptionBenefits(userId, planId);

      return true;
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      return false;
    }
  }

  // Cancel a subscription
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      await _client.from('user_subscriptions').update({
        'is_active': false,
        'auto_renew': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      return true;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  // Check for expired subscriptions
  Future<void> checkForExpiredSubscriptions() async {
    try {
      final now = DateTime.now().toIso8601String();

      // Find expired subscriptions
      final expired = await _client
          .from('user_subscriptions')
          .select()
          .eq('is_active', true)
          .lt('end_date', now);

      // Deactivate each expired subscription
      for (final subscription in expired) {
        await _client
            .from('user_subscriptions')
            .update({'is_active': false, 'updated_at': now}).eq(
                'id', subscription['id']);

        // Here you would typically notify the user that their subscription has expired
      }
    } catch (e) {
      debugPrint('Error checking for expired subscriptions: $e');
    }
  }

  // ========== FREE TRIAL SYSTEM ==========

  // Get user's access level (trial, free, basic, premium)
  Future<String> getUserAccessLevel(String userId) async {
    try {
      final subscription = await getActiveSubscription(userId);
      if (subscription == null) return 'free';

      final planName = subscription['subscription_plans']['name'] as String;
      return planName.toLowerCase(); // 'trial', 'basic', 'premium'
    } catch (e) {
      debugPrint('Error getting user access level: $e');
      return 'free';
    }
  }

  // Check if trial is active
  Future<bool> isTrialActive(String userId) async {
    final level = await getUserAccessLevel(userId);
    return level == 'trial';
  }

  // Check if trial expired
  Future<bool> isTrialExpired(String userId) async {
    try {
      final subscription = await getActiveSubscription(userId);
      if (subscription == null) return false;

      final planName = subscription['subscription_plans']['name'] as String;
      if (planName != 'Trial') return false;

      final endDate = DateTime.parse(subscription['end_date'] as String);
      return DateTime.now().isAfter(endDate);
    } catch (e) {
      debugPrint('Error checking if trial expired: $e');
      return false;
    }
  }

  // Get trial days remaining
  Future<int> getTrialDaysRemaining(String userId) async {
    try {
      final subscription = await getActiveSubscription(userId);
      if (subscription == null) return 0;

      final planName = subscription['subscription_plans']['name'] as String;
      if (planName != 'Trial') return 0;

      final endDate = DateTime.parse(subscription['end_date'] as String);
      final remaining = endDate.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('Error getting trial days remaining: $e');
      return 0;
    }
  }

  // Check mini courses access
  Future<bool> canAccessMiniCourses(String userId) async {
    final level = await getUserAccessLevel(userId);
    return ['trial', 'basic', 'premium'].contains(level);
  }

  // Check basic challenges access
  Future<bool> canAccessBasicChallenges(String userId) async {
    final level = await getUserAccessLevel(userId);
    return ['trial', 'basic', 'premium'].contains(level);
  }

  // Check premium challenges access
  Future<bool> canAccessPremiumChallenges(String userId) async {
    final level = await getUserAccessLevel(userId);
    return level == 'premium';
  }

  // Check if trial is expiring soon (< 3 days)
  Future<bool> isTrialExpiringSoon(String userId) async {
    final daysRemaining = await getTrialDaysRemaining(userId);
    return daysRemaining > 0 && daysRemaining <= 3;
  }

  // Get comprehensive access status
  Future<Map<String, dynamic>> getUserAccessStatus(String userId) async {
    final level = await getUserAccessLevel(userId);
    final daysRemaining = await getTrialDaysRemaining(userId);
    final isExpiringSoon = await isTrialExpiringSoon(userId);

    return {
      'access_level': level,
      'is_trial': level == 'trial',
      'is_free': level == 'free',
      'is_basic': level == 'basic',
      'is_premium': level == 'premium',
      'trial_days_remaining': daysRemaining,
      'trial_expiring_soon': isExpiringSoon,
      'can_access_mini_courses': await canAccessMiniCourses(userId),
      'can_access_basic_challenges': await canAccessBasicChallenges(userId),
      'can_access_premium_challenges': await canAccessPremiumChallenges(userId),
    };
  }

  // Helper method: Get trial status (used by UI components)
  Future<Map<String, dynamic>> getTrialStatus(String userId) async {
    final level = await getUserAccessLevel(userId);
    final daysRemaining = await getTrialDaysRemaining(userId);

    return {
      'isOnTrial': level == 'trial',
      'daysRemaining': daysRemaining,
      'isExpiringSoon': daysRemaining > 0 && daysRemaining <= 3,
    };
  }

  // Helper method: Assign trial plan to new user
  Future<bool> assignTrialPlan(String userId) async {
    return await activateTrialSubscription(userId);
  }
}

class CoinService {
  // This is a placeholder for the actual CoinService
  // We'll implement this next
  Future<bool> addCoins({
    required String userId,
    required num amount,
    required String description,
    required String transactionType,
    String? referenceType,
    String? referenceId,
  }) async {
    // Will be implemented in the CoinService
    return true;
  }
}
