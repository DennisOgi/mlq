import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class CoinService {
  // Singleton pattern
  static final CoinService _instance = CoinService._internal();
  factory CoinService() => _instance;
  CoinService._internal();

  final SupabaseClient _client = SupabaseService().client;
  final _uuid = Uuid();

  // Get user's coin balance
  Future<num> getUserCoins(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('coins')
          .eq('id', userId)
          .single();
      
      return response['coins'] ?? 0;
    } catch (e) {
      debugPrint('Error fetching user coins: $e');
      return 0;
    }
  }

  // Positive awards are server-only. Negative amounts use spend_coins.
  Future<bool> addCoins({
    required String userId,
    required num amount,
    required String description,
    required String transactionType,
    String? referenceType,
    String? referenceId,
  }) async {
    try {
      if (amount > 0) {
        debugPrint(
          '⚠️ CoinService.addCoins award blocked ($amount). Server-only.',
        );
        return false;
      }
      if (amount < 0) {
        final result = await _client.rpc('spend_coins', params: {
          'p_amount': amount.abs(),
          'p_description': description,
          'p_reference_type': referenceType ?? transactionType,
          'p_reference_id': referenceId,
        });
        return result is Map && result['success'] == true;
      }
      return true;
    } catch (e) {
      debugPrint('Error adding coins: $e');
      return false;
    }
  }

  // Remove coins from user's balance
  Future<bool> removeCoins({
    required String userId, 
    required num amount, 
    required String description,
    required String transactionType,
    String? referenceType,
    String? referenceId,
  }) async {
    try {
      // Start a transaction
      return await _client.rpc('remove_coins', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_description': description,
        'p_transaction_type': transactionType,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
      });
    } catch (e) {
      debugPrint('Error removing coins: $e');
      return false;
    }
  }

  // Goal coin awards are server-only (complete_goal_secure). Client calls no-op.
  Future<bool> awardGoalCoins({
    required String userId,
    required String goalId,
    required bool isCompletion,
  }) async {
    debugPrint(
      '⚠️ awardGoalCoins ignored (goalId=$goalId, completion=$isCompletion). '
      'Awards are server-side only.',
    );
    return false;
  }

  // Award coins for completing challenges
  Future<bool> awardChallengeCoins({
    required String userId,
    required String challengeId,
    required num amount,
  }) async {
    try {
      return await addCoins(
        userId: userId,
        amount: amount,
        description: 'Completed challenge',
        transactionType: 'challenge_completion',
        referenceType: 'challenge',
        referenceId: challengeId,
      );
    } catch (e) {
      debugPrint('Error awarding challenge coins: $e');
      return false;
    }
  }

  // Check if user has enough coins
  Future<bool> hasEnoughCoins({
    required String userId,
    required num amount,
  }) async {
    try {
      final balance = await getUserCoins(userId);
      return balance >= amount;
    } catch (e) {
      debugPrint('Error checking user coins: $e');
      return false;
    }
  }

  // Get coin transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory(
    String userId,
    {int limit = 20, int offset = 0}
  ) async {
    try {
      final response = await _client
          .from('coin_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return response;
    } catch (e) {
      debugPrint('Error fetching coin transaction history: $e');
      return [];
    }
  }

  // Spend coins on premium content
  Future<bool> spendCoinsOnPremiumContent({
    required String userId,
    required String contentId,
    required String contentType,
    required num amount,
    required String description,
  }) async {
    try {
      // Check if user has enough coins
      if (!await hasEnoughCoins(userId: userId, amount: amount)) {
        return false;
      }
      
      // Remove coins
      return await removeCoins(
        userId: userId,
        amount: amount,
        description: description,
        transactionType: 'premium_purchase',
        referenceType: contentType,
        referenceId: contentId,
      );
    } catch (e) {
      debugPrint('Error spending coins on premium content: $e');
      return false;
    }
  }
}
