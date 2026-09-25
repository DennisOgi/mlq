import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/models/user_model.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:my_leadership_quest/models/wallet_transaction_model.dart';
import 'package:my_leadership_quest/models/savings_goal_model.dart';

/// Service for all LeadWallet operations.
/// Internal Supabase ledger + Flutterwave payouts for withdrawals.
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // Lazy: hot restart / early route can construct this before Supabase init.
  SupabaseClient get _client => SupabaseService().client;

  /// Normalize wallet status from API/DB (handles stale cache and casing).
  static String normalizeWalletStatus(
    dynamic raw, {
    DateTime? activatedAt,
    double balance = 0,
  }) =>
      UserModel.normalizeWalletStatus(
        raw,
        activatedAt: activatedAt,
        balance: balance,
      );

  static DateTime? _parseActivatedAt(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

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
      // Use only columns that exist on profiles (legacy bank_* / is_sandbox_mode
      // fields were never migrated and cause PostgREST to fail the whole query).
      final response = await _client
          .from('profiles')
          .select(
              'wallet_balance, wallet_status, wallet_activated_at, withdrawal_bank_code, withdrawal_bank_name')
          .eq('id', userId)
          .single();

      final balance = (response['wallet_balance'] as num?)?.toDouble() ?? 0.0;
      final activatedAt = _parseActivatedAt(response['wallet_activated_at']);
      final bankCode = response['withdrawal_bank_code'] as String?;
      final bankName = response['withdrawal_bank_name'] as String?;
      final hasBankAccount = bankCode != null &&
          bankCode.isNotEmpty &&
          bankName != null &&
          bankName.isNotEmpty;

      return {
        'balance': balance,
        'status': normalizeWalletStatus(
          response['wallet_status'],
          activatedAt: activatedAt,
          balance: balance,
        ),
        'activated_at': response['wallet_activated_at'],
        'has_bank_account': hasBankAccount,
        'bank_provider': hasBankAccount ? 'flutterwave' : null,
        // Sandbox until a withdrawal bank account is linked.
        'is_sandbox': !hasBankAccount,
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

  /// Cancel a savings goal (returns funds to wallet).
  ///
  /// Refund + cancel happen atomically inside the secure `cancel_savings_goal`
  /// RPC. The client can no longer call `credit_wallet` directly.
  Future<bool> cancelSavingsGoal({
    required String userId,
    required String goalId,
  }) async {
    try {
      final result = await _client.rpc('cancel_savings_goal', params: {
        'p_goal_id': goalId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['success'] == true;
    } catch (e) {
      debugPrint('Error cancelling savings goal: $e');
      return false;
    }
  }

  // ─── Wallet Activation (Parent Consent) ─────────────────────────────

  /// Request activation in-app (Parent Portal). No email sent.
  Future<Map<String, dynamic>> requestActivationInApp({
    required String parentEmail,
  }) async {
    try {
      final result = await _client.rpc('request_wallet_activation', params: {
        'p_parent_email': parentEmail.trim().toLowerCase(),
      });
      final map = Map<String, dynamic>.from(result as Map);
      if (map['success'] == true) {
        return {'success': true, 'parent_email': map['parent_email']};
      }
      return {'success': false, 'error': map['error']?.toString() ?? 'Request failed'};
    } catch (e) {
      debugPrint('Error requesting in-app wallet activation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send parent consent email via wallet-consent edge function.
  Future<Map<String, dynamic>> sendActivationEmail({
    required String parentEmail,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'wallet-consent',
        body: {'parent_email': parentEmail.trim().toLowerCase()},
      );

      if (response.status == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true) {
          return {'success': true, 'parent_email': data['parent_email']};
        }
        return {'success': false, 'error': data['error'] ?? 'Failed to send email'};
      }

      final err = response.data is Map
          ? (response.data as Map)['error']?.toString()
          : 'Failed to send activation email (${response.status})';
      return {'success': false, 'error': err};
    } catch (e) {
      debugPrint('Error sending wallet activation email: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Legacy alias — prefer [sendActivationEmail].
  Future<String?> requestWalletActivation({
    required String userId,
    required String parentEmail,
  }) async {
    final result = await sendActivationEmail(parentEmail: parentEmail);
    if (result['success'] == true) return userId;
    return null;
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

  /// Admin: Activate wallet and grant payout consent (secure RPC).
  Future<bool> adminActivateWallet(String userId) async {
    try {
      final result = await _client.rpc('admin_activate_wallet', params: {
        'p_student_id': userId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['success'] == true;
    } catch (e) {
      debugPrint('Error activating wallet: $e');
      return false;
    }
  }

  /// Available balance in kobo (wallet minus pending withdrawals).
  Future<int> getAvailableBalanceKobo(String userId) async {
    try {
      final result = await _client.rpc('get_available_balance_kobo', params: {
        'p_user_id': userId,
      });
      return (result as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error fetching available balance: $e');
      return 0;
    }
  }

  // ─── Admin: Reward Disbursements ────────────────────────────────────

  /// Admin: Search students by name and/or school for reward issuance.
  Future<List<Map<String, dynamic>>> searchStudentsForReward({
    String? nameQuery,
    String? schoolQuery,
    int limit = 25,
  }) async {
    try {
      final name = nameQuery?.trim() ?? '';
      final school = schoolQuery?.trim() ?? '';

      if (name.length < 2 && school.length < 2) {
        return [];
      }

      // Admin-gated server RPC (avoids exposing a broad profiles query).
      final result = await _client.rpc('admin_search_students_for_reward', params: {
        'p_name': name,
        'p_school': school,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      debugPrint('Error searching students for reward: $e');
      return [];
    }
  }

  /// Admin: Get reward disbursements by status (via secure RPC).
  Future<List<Map<String, dynamic>>> getRewardDisbursements({
    String? status,
  }) async {
    try {
      final result = await _client.rpc(
        'admin_get_reward_disbursements',
        params: {'p_status': status},
      );
      final map = Map<String, dynamic>.from(result as Map);
      if (map['success'] != true) return [];
      final rows = map['disbursements'];
      if (rows is! List) return [];
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Error fetching reward disbursements: $e');
      return [];
    }
  }

  /// Admin: Get pending reward disbursements
  Future<List<Map<String, dynamic>>> getPendingDisbursements() async {
    final rows = await getRewardDisbursements(status: 'pending_approval');
    return rows.map((row) {
      return {
        ...row,
        'profiles': {
          'name': row['student_name'],
          'school_name': row['school_name'],
        },
      };
    }).toList();
  }

  /// Admin: Get completed/failed reward history
  Future<List<Map<String, dynamic>>> getDisbursementHistory() async {
    final all = await getRewardDisbursements();
    return all
        .where((row) => row['status'] != 'pending_approval')
        .toList();
  }

  /// Admin: Create a reward disbursement record (pending approval).
  Future<Map<String, dynamic>> createRewardDisbursement({
    required String studentId,
    required double amount,
    required String reason,
    String? challengeId,
  }) async {
    try {
      final response = await _client
          .from('reward_disbursements')
          .insert({
            'student_id': studentId,
            'amount': amount,
            'reason': reason,
            'challenge_id': challengeId,
          })
          .select('id')
          .single();
      return {'success': true, 'id': response['id']};
    } catch (e) {
      debugPrint('Error creating reward disbursement: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Create and immediately credit a reward to the student's LeadWallet.
  Future<Map<String, dynamic>> issueRewardDirectly({
    required String studentId,
    required double amount,
    required String reason,
    required String adminId,
    String? challengeId,
  }) async {
    try {
      final result = await _client.rpc('admin_issue_reward', params: {
        'p_student_id': studentId,
        'p_amount': amount,
        'p_reason': reason,
        if (challengeId != null) 'p_challenge_id': challengeId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error issuing reward directly: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Approve and process a reward disbursement
  Future<bool> approveAndProcessDisbursement({
    required String disbursementId,
    required String adminId,
  }) async {
    try {
      final result = await _client.rpc('admin_process_reward_disbursement', params: {
        'p_disbursement_id': disbursementId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['success'] == true;
    } catch (e) {
      debugPrint('Error approving disbursement: $e');
      return false;
    }
  }

  /// Admin: List pending withdrawal requests (admin-gated RPC; the underlying
  /// view exposed student PII to all authenticated users and is now locked down).
  Future<List<Map<String, dynamic>>> getPendingWithdrawalsAdmin() async {
    try {
      final result = await _client.rpc('admin_get_pending_withdrawals');
      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      debugPrint('Error fetching pending withdrawals: $e');
      return [];
    }
  }

  /// Admin: Approve a withdrawal request (does not send funds yet)
  Future<Map<String, dynamic>> adminApproveWithdrawal(String withdrawalId) async {
    try {
      final result = await _client.rpc('admin_approve_withdrawal', params: {
        'p_withdrawal_id': withdrawalId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error approving withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Reject a withdrawal request
  Future<Map<String, dynamic>> adminRejectWithdrawal(
    String withdrawalId, {
    String reason = 'Rejected by admin',
  }) async {
    try {
      final result = await _client.rpc('admin_reject_withdrawal', params: {
        'p_withdrawal_id': withdrawalId,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error rejecting withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Mark a stuck pending/approved/processing withdrawal as failed
  /// (releases reserved available balance; does not debit the ledger).
  Future<Map<String, dynamic>> adminFailWithdrawal(
    String withdrawalId, {
    String reason = 'Marked failed by admin',
  }) async {
    try {
      final result = await _client.rpc('admin_fail_withdrawal', params: {
        'p_withdrawal_id': withdrawalId,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error failing withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Mark processing/approved as paid and debit ledger (idempotent).
  Future<Map<String, dynamic>> adminCompleteWithdrawalPaid(
    String withdrawalId, {
    String? transferId,
    String? note,
  }) async {
    try {
      final result = await _client.rpc('admin_complete_withdrawal_paid', params: {
        'p_withdrawal_id': withdrawalId,
        'p_transfer_id': transferId,
        'p_note': note,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('Error completing withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Admin: Reject a reward disbursement (admin-gated RPC).
  Future<bool> rejectDisbursement(String disbursementId) async {
    try {
      final result = await _client.rpc('admin_reject_reward_disbursement', params: {
        'p_disbursement_id': disbursementId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['success'] == true;
    } catch (e) {
      debugPrint('Error rejecting disbursement: $e');
      return false;
    }
  }
}
