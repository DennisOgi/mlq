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
/// - One-time parent consent required for wallet activation (not per withdrawal)
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

  // Lazy: avoid touching Supabase before initialize() (hot restart / early routes).
  SupabaseClient get _client => SupabaseService().client;

  // Expose client for direct database access when needed
  SupabaseClient get client => _client;

  /// True when Flutterwave keys are in TEST/sandbox mode (only Access Bank works).
  bool isFlutterwaveSandbox = false;

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
          isFlutterwaveSandbox = data['is_sandbox'] == true;
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

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true) {
          return {
            'success': true,
            'account_name': data['account_name'],
            'account_number': data['account_number'],
          };
        }
        return {
          'success': false,
          'error': _friendlyValidationError(
            data['error']?.toString() ?? 'Validation failed',
          ),
        };
      }

      return {'success': false, 'error': 'Validation failed'};
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error validating account: $e');
      final raw = _extractFunctionError(e);
      return {'success': false, 'error': _friendlyValidationError(raw)};
    }
  }

  String _extractFunctionError(Object e) {
    try {
      // FunctionException from functions_client exposes .details on 4xx/5xx.
      final details = (e as dynamic).details;
      if (details is Map && details['error'] != null) {
        return details['error'].toString();
      }
    } catch (_) {}
    return e.toString();
  }

  String _friendlyValidationError(String raw) {
    if (raw.contains('only 044 is allowed') ||
        raw.contains('Test mode only supports Access Bank')) {
      return 'Test mode only supports Access Bank. Please select Access Bank '
          'to validate an account, or use live Flutterwave keys for other banks.';
    }
    if (RegExp(r'could not connect to your bank', caseSensitive: false)
        .hasMatch(raw)) {
      return 'Bank lookup is temporarily unavailable. Please try again in a '
          'few minutes, or use a different Nigerian bank account.';
    }
    if (raw.startsWith('FunctionException')) {
      return 'Could not validate this account. Please check the bank and '
          'account number, then try again.';
    }
    return raw;
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

      final reference = generateTransferReference(userId);

      final result = await _client.rpc('create_withdrawal_request', params: {
        'p_amount_kobo': amountKobo,
        'p_bank_code': accountBank,
        'p_account_number': accountNumber,
        'p_account_name': accountName,
        'p_flutterwave_reference': reference,
      });

      final map = Map<String, dynamic>.from(result as Map);
      if (map['success'] != true) {
        return {
          'success': false,
          'error': map['error']?.toString() ?? 'Withdrawal request failed',
        };
      }

      return {
        'success': true,
        'withdrawal_id': map['withdrawal_id'],
        'reference': reference,
        'status': 'pending_admin_approval',
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

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true) {
          return {
            'success': true,
            'transfer_id': data['transfer_id'],
            'reference': data['reference'],
            'status': data['status'] ?? 'processing',
            'simulated': data['simulated'] == true,
          };
        }
        return {
          'success': false,
          'error': _friendlyPayoutError(data['error']?.toString()),
          'error_code': data['error_code'],
        };
      }

      return {
        'success': false,
        'error': _friendlyPayoutError(response.data?.toString()),
      };
    } on FunctionException catch (e) {
      final details = e.details;
      String? message;
      if (details is Map) {
        message = details['error']?.toString();
      }
      debugPrint('❌ [FlutterwaveWallet] Error processing withdrawal: $e');
      return {
        'success': false,
        'error': _friendlyPayoutError(message ?? e.reasonPhrase ?? e.toString()),
      };
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error processing withdrawal: $e');
      return {'success': false, 'error': _friendlyPayoutError(e.toString())};
    }
  }

  String _friendlyPayoutError(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return 'Transfer failed. Please try again.';
    if (text.contains('FunctionException')) {
      final match = RegExp(r'error:\s*([^,}]+)').firstMatch(text);
      if (match != null) {
        return _friendlyPayoutError(match.group(1));
      }
    }
    if (RegExp(r'ip whitelisting', caseSensitive: false).hasMatch(text)) {
      return 'Flutterwave blocked the payout: IP whitelisting is required.\n\n'
          'Fix in Flutterwave Dashboard:\n'
          '1. Settings → Whitelisted IP addresses → Add 0.0.0.0 (sandbox) or your server IPs\n'
          '2. Settings → Business preference → Security → Transfer preferences → API or API + Dashboard\n\n'
          'Supabase Edge Functions use dynamic IPs, so use 0.0.0.0 for sandbox testing.';
    }
    return text;
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

  // ─── Transaction Status & History ───────────────────────────────────

  /// Sync a stuck processing withdrawal against Flutterwave transfer status.
  /// Finalizes to paid (with ledger debit) or failed when Flutterwave reports
  /// a terminal status; otherwise returns still-processing.
  Future<Map<String, dynamic>> syncWithdrawalStatus({
    required String withdrawalId,
  }) async {
    try {
      debugPrint('🔄 [FlutterwaveWallet] Syncing withdrawal: $withdrawalId');
      final response = await _client.functions.invoke(
        'flutterwave_sync_withdrawal',
        body: {'withdrawal_id': withdrawalId},
      );

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true) {
          return {
            'success': true,
            'status': data['status'],
            'transfer_id': data['transfer_id'],
            'flutterwave_status': data['flutterwave_status'],
            'message': data['message'],
            'simulated': data['simulated'] == true,
            'already_final': data['already_final'] == true,
          };
        }
        return {
          'success': false,
          'error': data['error']?.toString() ?? 'Sync failed',
        };
      }

      return {'success': false, 'error': 'Sync failed'};
    } on FunctionException catch (e) {
      final details = e.details;
      String? message;
      if (details is Map) {
        message = details['error']?.toString();
      }
      debugPrint('❌ [FlutterwaveWallet] Error syncing withdrawal: $e');
      return {
        'success': false,
        'error': message ?? e.reasonPhrase ?? e.toString(),
      };
    } catch (e) {
      debugPrint('❌ [FlutterwaveWallet] Error syncing withdrawal: $e');
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

  /// Cancel a pending withdrawal request.
  ///
  /// Uses the secure `cancel_withdrawal_request` RPC (a direct table update
  /// failed under RLS for the `pending_admin_approval` state the app uses).
  Future<bool> cancelWithdrawalRequest(String withdrawalId) async {
    try {
      final result = await _client.rpc('cancel_withdrawal_request', params: {
        'p_withdrawal_id': withdrawalId,
      });
      final map = Map<String, dynamic>.from(result as Map);
      return map['success'] == true;
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
