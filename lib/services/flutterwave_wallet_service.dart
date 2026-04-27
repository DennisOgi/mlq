import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';

/// Flutterwave Wallet Integration Service - MVP Version
/// 
/// ARCHITECTURE (MVP):
/// - Internal Supabase ledger as source of truth
/// - Flutterwave Transfer API for withdrawals only
/// - No per-student Flutterwave subaccounts (simpler, safer)
/// - All secret API calls via Supabase Edge Functions
/// 
/// SECURITY:
/// - Flutter app NEVER calls Flutterwave directly
/// - All transfers via backend Edge Functions
/// - Webhook verification for transfer status
/// - Parent consent required for withdrawals
/// - Admin approval for high-value withdrawals
/// 
/// FLOW:
/// 1. Student earns achievement → Ledger credit (pending/approved)
/// 2. Parent/admin approves → Balance increases
/// 3. Student requests withdrawal → Creates withdrawal_request
/// 4. Parent/admin approves withdrawal → Edge Function calls Flutterwave Transfer API
/// 5. Webhook confirms success/failure → Ledger updates
/// 
/// FUTURE: Can upgrade to Flutterwave Payout Subaccounts for advanced features
class FlutterwaveWalletService {
  static final FlutterwaveWalletService _instance = FlutterwaveWalletService._internal();
  factory FlutterwaveWalletService() => _instance;
  FlutterwaveWalletService._internal();

  final SupabaseClient _client = SupabaseService().client;

  // Expose client for direct database access when needed
  SupabaseClient get client => _client;

  // ─── Bank Account Management ────────────────────────────────────────

  /// Get list of Nigerian banks from Flutterwave
  /// 
  /// Called when user is setting up withdrawal bank account.
  Future<List<Map<String, dynamic>>> getNigerianBanks() async {
    try {
      final response = await _client.functions.invoke('flutterwave_get_banks');

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        if (data['success'] == true && data['banks'] is List) {
          return List<Map<String, dynamic>>.from(data['banks']);
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error fetching banks: $e');
      return [];
    }
  }

  /// Validate and resolve bank account details
  /// 
  /// Verifies account number and returns account holder name.
  /// MUST be called before saving bank account for withdrawals.
  Future<Map<String, dynamic>> validateBankAccount({
    required String accountNumber,
    required String accountBank,
  }) async {
    try {
      debugPrint('🔍 [FlutterwaveWallet] Validating account: $accountNumber');

      final response = await _client.functions.invoke(
        'flutterwave_validate_account',
        body: {
          'account_number': accountNumber,
          'account_bank': accountBank,
        },
      );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        return {
          'success': data['success'] ?? false,
          'account_name': data['account_name'],
          'account_number': data['account_number'],
        };
      }

      return {'success': false, 'error': 'Validation failed'};
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error validating account: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Withdrawal Requests ────────────────────────────────────────────

  /// Create a withdrawal request
  /// 
  /// Student initiates withdrawal. Does NOT call Flutterwave yet.
  /// Creates a pending withdrawal_request that requires approval.
  Future<Map<String, dynamic>> createWithdrawalRequest({
    required String userId,
    required int amountKobo, // Store in kobo (₦1 = 100 kobo)
    required String accountBank,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      debugPrint('💸 [FlutterwaveWallet] Creating withdrawal request: ₦${amountKobo / 100}');

      // Check wallet balance (in kobo)
      final balance = await _getWalletBalanceKobo(userId);
      if (balance < amountKobo) {
        return {
          'success': false,
          'error': 'Insufficient balance. Available: ₦${balance / 100}',
        };
      }

      // Check parent consent
      final consentStatus = await _checkPayoutConsent(userId);
      if (consentStatus != 'approved') {
        return {
          'success': false,
          'error': 'Parent consent required for withdrawals',
        };
      }

      // Generate unique reference
      final reference = generateTransferReference(userId);

      // Create withdrawal request
      final response = await _client.from('withdrawal_requests').insert({
        'student_id': userId,
        'amount_kobo': amountKobo,
        'bank_code': accountBank,
        'account_number': accountNumber,
        'account_name': accountName,
        'status': 'pending_parent_approval',
        'flutterwave_reference': reference,
      }).select().single();

      return {
        'success': true,
        'withdrawal_id': response['id'],
        'reference': reference,
        'status': 'pending_parent_approval',
      };
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error creating withdrawal request: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Process approved withdrawal (calls Flutterwave Transfer API)
  /// 
  /// Called by backend/admin after withdrawal is approved.
  /// This is the ONLY method that actually moves money via Flutterwave.
  Future<Map<String, dynamic>> processWithdrawal({
    required String withdrawalId,
  }) async {
    try {
      debugPrint('🏧 [FlutterwaveWallet] Processing withdrawal: $withdrawalId');

      // Get withdrawal details
      final withdrawal = await _client
          .from('withdrawal_requests')
          .select()
          .eq('id', withdrawalId)
          .single();

      if (withdrawal['status'] != 'approved') {
        return {
          'success': false,
          'error': 'Withdrawal not approved. Status: ${withdrawal['status']}',
        };
      }

      // Call Edge Function to execute Flutterwave transfer
      final response = await _client.functions.invoke(
        'flutterwave_process_withdrawal',
        body: {'withdrawal_id': withdrawalId},
      );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        if (data['success'] == true) {
          return {
            'success': true,
            'transfer_id': data['transfer_id'],
            'reference': data['reference'],
            'status': 'processing',
          };
        }
        throw Exception(data['error']?.toString() ?? 'Transfer failed');
      }

      throw Exception('Transfer failed');
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error processing withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get wallet balance in kobo (₦1 = 100 kobo)
  /// 
  /// Calculated from approved transactions in ledger.
  Future<int> _getWalletBalanceKobo(String userId) async {
    try {
      // Sum all successful/approved transactions
      final response = await _client.rpc('get_wallet_balance_kobo', params: {
        'p_user_id': userId,
      });

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error fetching balance: $e');
      return 0;
    }
  }

  // ─── Consent Management ─────────────────────────────────────────────

  /// Check payout consent status
  Future<String> _checkPayoutConsent(String userId) async {
    try {
      final response = await _client
          .from('wallet_consent')
          .select('status')
          .eq('student_id', userId)
          .eq('consent_type', 'payout_approval')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 'none';
      return response['status'] as String;
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error checking consent: $e');
      return 'error';
    }
  }

  // ─── Transaction Status & History ───────────────────────────────────

  /// Get transfer status from Flutterwave
  /// 
  /// Used to check status of pending transfers.
  Future<Map<String, dynamic>> getTransferStatus(String transferId) async {
    try {
      final response = await _client.functions.invoke(
        'flutterwave_get_transfer_status',
        body: {'transfer_id': transferId},
      );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        return {
          'success': true,
          'status': data['status'],
          'data': data['data'],
        };
      }

      return {'success': false, 'error': 'Failed to fetch status'};
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error fetching transfer status: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update transaction status (called by webhook handler)
  Future<void> updateTransactionStatus({
    required String transactionId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('wallet_transactions').update({
        'status': status,
        'metadata': metadata,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('bank_transaction_id', transactionId);

      debugPrint('✅ [FlutterwaveWallet] Updated transaction $transactionId to $status');
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error updating transaction status: $e');
    }
  }

  // ─── Withdrawal Management ──────────────────────────────────────────

  /// Get pending withdrawal requests for a student
  Future<List<Map<String, dynamic>>> getWithdrawalRequests(String userId) async {
    try {
      final response = await _client
          .from('withdrawal_requests')
          .select()
          .eq('student_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error fetching withdrawals: $e');
      return [];
    }
  }

  /// Cancel a pending withdrawal request
  Future<bool> cancelWithdrawalRequest(String withdrawalId) async {
    try {
      await _client.from('withdrawal_requests').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', withdrawalId);

      return true;
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error cancelling withdrawal: $e');
      return false;
    }
  }

  // ─── Utility Methods ────────────────────────────────────────────────

  /// Generate unique reference for transfers
  /// Format: MLQ-{user_prefix}-{timestamp}
  String generateTransferReference(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userPrefix = userId.substring(0, 8);
    return 'MLQ-$userPrefix-$timestamp';
  }

  /// Convert Naira to Kobo (₦1 = 100 kobo)
  int nairaToKobo(double naira) {
    return (naira * 100).round();
  }

  /// Convert Kobo to Naira
  double koboToNaira(int kobo) {
    return kobo / 100.0;
  }
}
