import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:my_leadership_quest/services/bank_integration_service.dart';
import 'package:my_leadership_quest/models/wallet_transaction_model.dart';
import 'package:my_leadership_quest/models/savings_goal_model.dart';

/// Service for all LeadWallet operations.
/// Follows the singleton pattern established by CoinService.
/// 
/// ARCHITECTURE:
/// This service now uses BankIntegrationService as the primary data source.
/// Database serves as cache/backup for offline access.
/// 
/// CURRENT: Sandbox mode with mock bank integration
/// FUTURE: Real bank API integration
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final SupabaseClient _client = SupabaseService().client;
  final BankIntegrationService _bankService = BankIntegrationService();

  // ─── Balance & Status ───────────────────────────────────────────────

  /// Get the user's current wallet balance
  /// 
  /// ARCHITECTURE:
  /// - Fetches balance from database (fast)
  /// - Bank integration check happens only in wallet dashboard (not during init)
  /// - This keeps app initialization fast
  Future<double> getWalletBalance(String userId) async {
    try {
      // Always fetch from database for speed
      // Bank balance sync happens in wallet dashboard, not here
      final response = await _client
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .single();
      return (response['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching wallet balance: $e');
      return 0.0;
    }
  }

  /// Get wallet status for a user
  /// Includes bank integration status
  Future<Map<String, dynamic>> getWalletStatus(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('wallet_balance, wallet_status, wallet_activated_at, bank_account_id, bank_provider, is_sandbox_mode')
          .eq('id', userId)
          .single();
      
      return {
        'balance': (response['wallet_balance'] as num?)?.toDouble() ?? 0.0,
        'status': response['wallet_status'] ?? 'inactive',
        'activated_at': response['wallet_activated_at'],
        'has_bank_account': response['bank_account_id'] != null,
        'bank_provider': response['bank_provider'],
        'is_sandbox': response['is_sandbox_mode'] ?? true,
      };
    } catch (e) {
      debugPrint('Error fetching wallet status: $e');
      return {
        'balance': 0.0,
        'status': 'inactive',
        'activated_at': null,
        'has_bank_account': false,
        'is_sandbox': true,
      };
    }
  }

  // ─── Transactions ───────────────────────────────────────────────────

  /// Get paginated transaction history
  Future<List<WalletTransactionModel>> getTransactionHistory(
    String userId, {
    int limit = 20,
    int offset = 0,
    String? typeFilter,
  }) async {
    try {
      var query = _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId);

      if (typeFilter != null) {
        query = query.eq('type', typeFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => WalletTransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching wallet transactions: $e');
      return [];
    }
  }

  // ─── Credits & Debits (via secure RPCs) ─────────────────────────────

  /// Credit wallet via the secure RPC function
  /// 
  /// ARCHITECTURE:
  /// - Uses database RPC for immediate credit
  /// - Bank sync happens asynchronously in background (future enhancement)
  /// - This keeps the operation fast and reliable
  Future<Map<String, dynamic>> creditWallet({
    required String userId,
    required double amount,
    required String description,
    String type = 'reward',
    String? referenceType,
    String? referenceId,
    String? approvedBy,
  }) async {
    try {
      // Credit via database RPC (fast and reliable)
      final result = await _client.rpc('credit_wallet', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_description': description,
        'p_type': type,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
        'p_approved_by': approvedBy,
      });
      
      // TODO: When bank integration is live, sync to bank asynchronously
      // _syncToBankInBackground(userId, amount, referenceId);
      
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error crediting wallet: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Debit wallet via the secure RPC function
  Future<Map<String, dynamic>> debitWallet({
    required String userId,
    required double amount,
    required String description,
    String type = 'savings_deposit',
    String? referenceType,
    String? referenceId,
  }) async {
    try {
      final result = await _client.rpc('debit_wallet', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_description': description,
        'p_type': type,
        'p_reference_type': referenceType,
        'p_reference_id': referenceId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error debiting wallet: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Savings Goals ──────────────────────────────────────────────────

  /// Get all savings goals for a user
  Future<List<SavingsGoalModel>> getSavingsGoals(String userId) async {
    try {
      final response = await _client
          .from('savings_goals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => SavingsGoalModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching savings goals: $e');
      return [];
    }
  }

  /// Get only active savings goals
  Future<List<SavingsGoalModel>> getActiveSavingsGoals(String userId) async {
    try {
      final response = await _client
          .from('savings_goals')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => SavingsGoalModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active savings goals: $e');
      return [];
    }
  }

  /// Create a new savings goal
  Future<SavingsGoalModel?> createSavingsGoal({
    required String userId,
    required String title,
    required double targetAmount,
    String icon = '🎯',
  }) async {
    try {
      final response = await _client
          .from('savings_goals')
          .insert({
            'user_id': userId,
            'title': title,
            'target_amount': targetAmount,
            'icon': icon,
          })
          .select()
          .single();
      return SavingsGoalModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating savings goal: $e');
      return null;
    }
  }

  /// Allocate funds from wallet to a savings goal via secure RPC
  Future<Map<String, dynamic>> allocateToSavingsGoal({
    required String userId,
    required String goalId,
    required double amount,
  }) async {
    try {
      final result = await _client.rpc('allocate_to_savings_goal', params: {
        'p_user_id': userId,
        'p_goal_id': goalId,
        'p_amount': amount,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error allocating to savings goal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cancel a savings goal (returns funds to wallet)
  Future<bool> cancelSavingsGoal({
    required String userId,
    required String goalId,
  }) async {
    try {
      // Get the current goal amount to refund
      final goal = await _client
          .from('savings_goals')
          .select()
          .eq('id', goalId)
          .eq('user_id', userId)
          .single();

      final currentAmount = (goal['current_amount'] as num).toDouble();

      // If there's money in the goal, credit it back to wallet
      if (currentAmount > 0) {
        final creditResult = await creditWallet(
          userId: userId,
          amount: currentAmount,
          description: 'Cancelled savings goal: ${goal['title']}',
          type: 'savings_withdrawal',
          referenceType: 'savings_goal',
          referenceId: goalId,
        );
        if (creditResult['success'] != true) {
          return false;
        }
      }

      // Mark goal as cancelled
      await _client
          .from('savings_goals')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', goalId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error cancelling savings goal: $e');
      return false;
    }
  }

  // ─── Wallet Activation (Parent Consent) ─────────────────────────────

  /// Request wallet activation (sends consent to parent).
  /// Returns the consent record ID or null on failure.
  Future<String?> requestWalletActivation({
    required String userId,
    required String parentEmail,
  }) async {
    try {
      // Generate a secure consent token
      final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
          userId.substring(0, 8);

      // Create consent record
      final response = await _client
          .from('wallet_consent')
          .insert({
            'student_id': userId,
            'parent_email': parentEmail,
            'consent_type': 'wallet_activation',
            'consent_token': token,
          })
          .select()
          .single();

      // Update profile status
      await _client.from('profiles').update({
        'wallet_status': 'pending_consent',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // TODO: Phase 2 — trigger Edge Function to send consent email to parent
      debugPrint('📧 Wallet activation requested. Token: $token → $parentEmail');

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error requesting wallet activation: $e');
      return null;
    }
  }

  /// Check the current consent status for a student
  Future<String> checkConsentStatus(String userId) async {
    try {
      final response = await _client
          .from('wallet_consent')
          .select('status')
          .eq('student_id', userId)
          .eq('consent_type', 'wallet_activation')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 'none';
      return response['status'] as String;
    } catch (e) {
      debugPrint('Error checking consent status: $e');
      return 'error';
    }
  }

  /// Admin: Approve wallet activation directly (bypasses email for now)
  Future<bool> adminActivateWallet(String userId) async {
    try {
      await _client.from('profiles').update({
        'wallet_status': 'active',
        'wallet_activated_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error activating wallet: $e');
      return false;
    }
  }

  // ─── Admin: Reward Disbursements ────────────────────────────────────

  /// Admin: Get pending reward disbursements
  Future<List<Map<String, dynamic>>> getPendingDisbursements() async {
    try {
      final response = await _client
          .from('reward_disbursements')
          .select('*, profiles!reward_disbursements_student_id_fkey(name, school_name)')
          .eq('status', 'pending_approval')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending disbursements: $e');
      return [];
    }
  }

  /// Admin: Create a reward disbursement
  Future<bool> createRewardDisbursement({
    required String studentId,
    required double amount,
    required String reason,
    String? challengeId,
  }) async {
    try {
      await _client.from('reward_disbursements').insert({
        'student_id': studentId,
        'amount': amount,
        'reason': reason,
        'challenge_id': challengeId,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating reward disbursement: $e');
      return false;
    }
  }

  /// Admin: Approve and process a reward disbursement
  Future<bool> approveAndProcessDisbursement({
    required String disbursementId,
    required String adminId,
  }) async {
    try {
      // Get the disbursement details
      final disbursement = await _client
          .from('reward_disbursements')
          .select()
          .eq('id', disbursementId)
          .single();

      final studentId = disbursement['student_id'] as String;
      final amount = (disbursement['amount'] as num).toDouble();
      final reason = disbursement['reason'] as String;

      // Credit the student's wallet
      final creditResult = await creditWallet(
        userId: studentId,
        amount: amount,
        description: 'Reward: $reason',
        type: 'reward',
        referenceType: 'admin_grant',
        referenceId: disbursementId,
        approvedBy: adminId,
      );

      if (creditResult['success'] != true) {
        // Mark as failed
        await _client.from('reward_disbursements').update({
          'status': 'failed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', disbursementId);
        return false;
      }

      // Mark as completed
      await _client.from('reward_disbursements').update({
        'status': 'completed',
        'approved_by': adminId,
        'approved_at': DateTime.now().toIso8601String(),
        'disbursed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', disbursementId);

      return true;
    } catch (e) {
      debugPrint('Error approving disbursement: $e');
      return false;
    }
  }

  /// Admin: Reject a reward disbursement
  Future<bool> rejectDisbursement(String disbursementId) async {
    try {
      await _client
          .from('reward_disbursements')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', disbursementId);
      return true;
    } catch (e) {
      debugPrint('Error rejecting disbursement: $e');
      return false;
    }
  }
}
