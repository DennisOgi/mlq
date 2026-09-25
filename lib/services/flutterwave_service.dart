import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlutterwaveService {
  static final FlutterwaveService _instance = FlutterwaveService._internal();
  factory FlutterwaveService() => _instance;
  FlutterwaveService._internal();

  /// Stable HTTPS redirect used after checkout.
  /// Do not use https://mlq.app/redirect — that host currently returns HTTP 500.
  static const paymentRedirectUrl =
      'https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/payment-redirect';

  /// Payment methods shown on Flutterwave checkout (NGN).
  /// Requires Bank Transfer enabled under Flutterwave → Settings →
  /// Business Preferences → Payment Methods. If "Enable Dashboard Payment
  /// Options" is ON, dashboard toggles override this list.
  static const String defaultPaymentOptions =
      'card,banktransfer,ussd,account';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialize payment and get payment link
  /// This follows Flutterwave's official documentation
  Future<Map<String, dynamic>> initializePayment({
    required String email,
    required String name,
    required double amount,
    required String currency,
    required String txRef,
    required String redirectUrl,
    String? phoneNumber,
    Map<String, dynamic>? meta,
    String paymentOptions = defaultPaymentOptions,
  }) async {
    try {
      debugPrint('🔑 [FlutterwaveService] Initializing payment...');
      debugPrint('🔑 Amount: $amount');
      debugPrint('🔑 Currency: $currency');
      debugPrint('🔑 TxRef: $txRef');
      debugPrint('🔑 Email: $email');
      debugPrint('🔑 Payment options: $paymentOptions');

      // Use Edge Function to initialize payment server-side.
      // This avoids exposing Flutterwave secret keys to the client and prevents RLS issues.
      final res = await _supabase.functions.invoke(
        'flutterwave_init_payment',
        body: {
          'tx_ref': txRef,
          'amount': amount,
          'currency': currency,
          'redirect_url': redirectUrl,
          'email': email,
          'name': name,
          'phone_number': phoneNumber ?? '',
          'payment_options': paymentOptions,
          'meta': meta ?? {},
        },
      );

      debugPrint('🔑 [FlutterwaveService] Edge init status: ${res.status}');
      debugPrint('🔑 [FlutterwaveService] Edge init data: ${res.data}');

      if (res.status == 200 && res.data is Map) {
        final data = res.data as Map;
        final link = data['link']?.toString();
        if (data['success'] == true && (link ?? '').isNotEmpty) {
          return {
            'success': true,
            'link': link,
            'data': data['data'],
          };
        }
        throw Exception(data['error']?.toString() ?? 'Payment initialization failed');
      }

      // Supabase functions.invoke may return non-Map data for failures; normalize.
      throw Exception('Payment initialization failed');
    } catch (e) {
      debugPrint('❌ [FlutterwaveService] Error: $e');
      
      // Provide helpful error messages
      String userMessage = e.toString();
      if (userMessage.contains('insufficient')) {
        userMessage = 'Payment declined due to insufficient funds. Please:\n'
            '1. Ensure your card has enough balance\n'
            '2. Check if your card is enabled for online transactions\n'
            '3. Try a different card or payment method\n'
            '4. Contact your bank if issue persists';
      }
      
      return {
        'success': false,
        'error': userMessage,
      };
    }
  }
}
