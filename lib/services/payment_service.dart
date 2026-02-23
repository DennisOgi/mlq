import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PaymentService {
  // Singleton
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final SupabaseClient _client = SupabaseService().client;

  /// Calls the Supabase Edge Function to verify a Flutterwave transaction
  /// and apply entitlements (subscription or coins) server-side.
  ///
  /// Returns true if verification succeeded and effects were applied.
  Future<bool> verifyFlutterwaveTransaction({
    required String transactionId,
    required String txRef,
    required String userId,
    required String type, // 'subscription' | 'coins'
    String? planId,
    String? planName,
    int? durationDays,
    int? coins,
    num? amount,
    String currency = 'NGN',
  }) async {
    try {
      final payload = {
        'transaction_id': transactionId,
        'tx_ref': txRef,
        'user_id': userId,
        'type': type,
        if (planId != null) 'plan_id': planId,
        if (planName != null) 'plan_name': planName,
        if (durationDays != null) 'duration_days': durationDays,
        if (coins != null) 'coins': coins,
        if (amount != null) 'amount': amount,
        'currency': currency,
      };

      debugPrint('Calling verify_flutterwave_txn with payload: $payload');
      
      final res = await _client.functions.invoke('verify_flutterwave_txn',
          body: payload);

      debugPrint('verify_flutterwave_txn response: ${res.data}');
      debugPrint('Response status code: ${res.status}');

      // Check for successful response
      if (res.status == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        if (data['status'] == 'ok' || data['success'] == true) {
          debugPrint('Payment verification successful');
          return true;
        } else {
          debugPrint('Payment verification failed: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint('Edge function call failed with status: ${res.status}');
      }
      
      return false;
    } catch (e) {
      debugPrint('Error verifying Flutterwave transaction: $e');
      return false;
    }
  }

  /// Legacy method for backward compatibility
  Future<bool> verifyTransaction({
    required String transactionId,
    required String txRef,
    required double amount,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = metadata?['user_id'] as String?;
    final planId = metadata?['plan_id'] as String?;
    final type = metadata?['subscription_type'] == 'upgrade' ? 'subscription' : 'coins';
    
    if (userId == null) {
      debugPrint('Missing user_id in metadata');
      return false;
    }

    return await verifyFlutterwaveTransaction(
      transactionId: transactionId,
      txRef: txRef,
      userId: userId,
      type: type,
      planId: planId,
      amount: amount,
      currency: currency,
    );
  }
}
