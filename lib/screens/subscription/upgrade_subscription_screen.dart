import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/payment_service.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_service.dart';
import '../../services/flutterwave_service.dart';
import '../../widgets/flutterwave_webview_payment.dart';

class UpgradeSubscriptionScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final num price;
  final String duration;

  const UpgradeSubscriptionScreen({
    Key? key,
    required this.planId,
    required this.planName,
    required this.price,
    required this.duration,
  }) : super(key: key);

  @override
  State<UpgradeSubscriptionScreen> createState() =>
      _UpgradeSubscriptionScreenState();
}

class _UpgradeSubscriptionScreenState extends State<UpgradeSubscriptionScreen> {
  final _uuid = const Uuid();
  bool _processingPayment = false;
  final PaymentService _paymentService = PaymentService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  int _durationDaysFromLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('monthly')) return 30;
    if (l.contains('quarter')) return 90;
    if (l.contains('year')) return 365;
    final match = RegExp(r'(\d+)\s*days').firstMatch(l);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 30;
    }
    return 30;
  }

  Future<Map<String, dynamic>> _getTrialInfo() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.id;
    if (userId == null) {
      return {'isOnTrial': false};
    }
    return await _subscriptionService.getTrialStatus(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Upgrade to ${widget.planName}',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trial info banner (if applicable)
            FutureBuilder<Map<String, dynamic>>(
              future: _getTrialInfo(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!['isOnTrial'] == true) {
                  final daysRemaining = snapshot.data!['daysRemaining'] as int;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent1.withOpacity(0.1),
                      border: Border.all(color: AppColors.accent1, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.accent1),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You have $daysRemaining day${daysRemaining != 1 ? 's' : ''} left in your free trial. Upgrade now to continue enjoying premium features!',
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Plan summary card
            _buildPlanSummaryCard(),
            const SizedBox(height: 24),

            // Benefits section
            _buildBenefitsSection(),
            const SizedBox(height: 24),

            // Payment section
            _buildPaymentSection(),
            const SizedBox(height: 32),

            // Terms and conditions
            _buildTermsSection(),
            const SizedBox(height: 24),

            // Payment button
            _buildPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.planName,
              style: AppTextStyles.heading1.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '₦${widget.price}', // Naira symbol
              style: AppTextStyles.heading1.copyWith(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.duration,
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = _getBenefitsForPlan(widget.planName);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: AppColors.secondary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'What You Get',
                  style:
                      AppTextStyles.heading3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...benefits.map((benefit) => _buildBenefitItem(benefit)),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 16,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              benefit,
              style: AppTextStyles.body.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Payment Methods',
                  style:
                      AppTextStyles.heading3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentMethodItem(Icons.credit_card, 'Debit/Credit Card',
                'Visa, Mastercard, Verve'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.tertiary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: AppColors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secure payment powered by Flutterwave',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold),
                Text(
                  subtitle,
                  style:
                      AppTextStyles.caption.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions',
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '• Your subscription will auto-renew unless cancelled\n'
            '• You can cancel anytime from your profile settings\n'
            '• Refunds are processed according to our refund policy\n'
            '• Premium features activate immediately after payment',
            style: AppTextStyles.caption.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: _processingPayment
              ? [Colors.grey, Colors.grey.shade400]
              : [AppColors.primary, AppColors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _processingPayment ? null : _startPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _processingPayment
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: AppTextStyles.button.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pay ₦${widget.price} Securely', // Naira symbol
                    style: AppTextStyles.button.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<String> _getBenefitsForPlan(String planName) {
    switch (planName.toLowerCase()) {
      case 'basic':
        return [
          'Access to basic challenges',
          '500 coins per month',
          'Leadership mini courses',
          'Email support',
          'Mobile app access',
        ];
      case 'premium':
        return [
          'Premium subscription qualifies for rewards',
          'Premium checkmark badge',
          'Unlimited premium challenges',
          'Leadership mini courses',
          'Create & manage Communities',
          '1000 coins per month',
          'Priority support',
        ];
      default:
        return [
          'Access to premium features',
          'Enhanced learning experience',
          'Priority support',
          'Advanced tracking tools',
        ];
    }
  }

  Future<void> _startPayment() async {
    if (_processingPayment) return;

    setState(() {
      _processingPayment = true;
    });

    // Make txRef visible to catch/finally blocks
    late final String txRef;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate transaction reference
      txRef = _uuid.v4();

      // Create payment attempt for subscription (align with coins flow)
      try {
        await SupabaseService().client.rpc('create_payment_attempt', params: {
          'p_user_id': user.id,
          'p_tx_ref': txRef,
          'p_amount': widget.price,
          'p_coins': 0,
          'p_currency': 'NGN',
          'p_metadata': {
            'subscription': true,
            'plan_id': widget.planId,
            'plan_name': widget.planName,
            'duration': widget.duration,
            'initiated_at': DateTime.now().toIso8601String(),
          },
        });
      } catch (e) {
        debugPrint('⚠️ [Subscription] Failed to create payment attempt: $e');
      }

      // Initialize payment using Flutterwave API (same as shop screen)
      final flwService = FlutterwaveService();
      final initResult = await flwService.initializePayment(
        email: user.email ?? 'user@example.com',
        name: user.name,
        amount: widget.price.toDouble(),
        currency: 'NGN',
        txRef: txRef,
        redirectUrl: 'https://mlq.app/redirect',
        phoneNumber: '',
        meta: {
          'type': 'subscription',
          'plan_id': widget.planId,
          'plan_name': widget.planName,
          'user_id': user.id,
          'duration': widget.duration,
          'tx_ref': txRef,
          'amount': widget.price,
          'expires_at':
              DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        },
      );

      if (!initResult['success']) {
        throw Exception(initResult['error'] ?? 'Failed to initialize payment');
      }

      final paymentLink = initResult['link'];
      debugPrint('✅ [Subscription] Payment link generated');
      debugPrint('Initiating Flutterwave payment...');
      debugPrint('Amount: ${widget.price}');
      debugPrint('Plan: ${widget.planName}');
      debugPrint('TxRef: $txRef');

      // Open payment link in WebView (same as shop screen)
      if (!mounted) return;
      final paymentResult =
          await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => FlutterwaveWebViewPayment(
            paymentUrl: paymentLink,
            redirectUrl: 'https://mlq.app/redirect',
            onSuccess: (data) {
              Navigator.of(context).pop(data);
            },
            onError: (error) {
              Navigator.of(context).pop({'status': 'error', 'message': error});
            },
            onCancel: () {
              Navigator.of(context).pop({'status': 'cancelled'});
            },
          ),
        ),
      );

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔑 [Subscription] Payment Result');
      debugPrint('🔑 Result: ${paymentResult?.toString() ?? "null"}');
      debugPrint('═══════════════════════════════════════════════════');

      if (!mounted) return;

      // Handle payment response
      final status = (paymentResult?['status'] ?? '').toString().toLowerCase();
      final isSuccessful = status == 'success' ||
          status == 'successful' ||
          status == 'completed';

      // Check if user closed the modal after successful payment
      final userClosedAfterPayment =
          (status.isEmpty || status == 'null' || status == 'cancelled') &&
              paymentResult?['transaction_id'] != null;

      // Also check for any response that has a transaction ID
      final hasTransactionId = paymentResult?['transaction_id'] != null &&
          paymentResult!['transaction_id'].toString().isNotEmpty;

      debugPrint(
          'Status analysis: isSuccessful=$isSuccessful, userClosedAfterPayment=$userClosedAfterPayment, hasTransactionId=$hasTransactionId');

      if ((isSuccessful || userClosedAfterPayment || hasTransactionId) &&
          paymentResult?['transaction_id'] != null) {
        // Verify payment with backend
        final success = await _verifyPaymentWithRetry(
          transactionId: paymentResult!['transaction_id'].toString(),
          txRef: txRef,
          userId: user.id,
          planId: widget.planId,
          amount: widget.price,
        );

        if (success) {
          // Payment successful - refresh user data to show premium status
          if (mounted) {
            debugPrint(
                '🔄 [Subscription] Refreshing user data after successful payment...');

            // Refresh user profile from server (like shop does)
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            await userProvider.reinitializeUser();

            // Refresh entitlements to update premium status
            await userProvider.refreshEntitlements();

            final updatedUser = userProvider.user;
            debugPrint(
                '✅ [Subscription] User profile refreshed. Premium: ${updatedUser?.isPremium}');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Payment successful! Welcome to ${widget.planName}!',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
                backgroundColor: AppColors.tertiary,
                duration: const Duration(seconds: 3),
              ),
            );

            // Return success to previous screen
            Navigator.of(context).pop(true);
          }
          return; // Exit successfully
        } else {
          throw Exception(
              'Payment verification failed. Please contact support if payment was deducted.');
        }
      } else if (status == 'cancelled' &&
          paymentResult?['transaction_id'] == null) {
        // Only treat as cancelled if there's no transaction ID
        throw Exception('Payment was cancelled');
      } else if (paymentResult?['transaction_id'] == null && !isSuccessful) {
        // No transaction ID and not successful = user cancelled before payment
        throw Exception('Payment was cancelled');
      } else {
        // Unknown status but might have transaction ID - check backend
        throw Exception(status.isNotEmpty ? status : 'Payment status unknown');
      }
    } catch (e) {
      debugPrint('Payment error: $e');

      // On cancel/close or error, verify if backend completed the attempt
      // Wait a bit for webhook to process, then check multiple times
      try {
        debugPrint(
            '🔍 [Subscription] Checking if payment was completed by webhook...');

        // Try checking 3 times with delays to give webhook time to process
        for (int i = 0; i < 3; i++) {
          if (i > 0) {
            await Future.delayed(Duration(seconds: i * 2)); // 0s, 2s, 4s
          }

          final attempt = await SupabaseService()
              .client
              .from('payment_attempts')
              .select('status, amount')
              .eq('tx_ref', txRef)
              .maybeSingle();

          debugPrint(
              '🔍 [Subscription] Attempt ${i + 1}/3: status = ${attempt?['status']}');

          if (attempt != null && attempt['status'] == 'completed') {
            if (mounted) {
              debugPrint(
                  '🔄 [Subscription] Payment completed by webhook, refreshing user data...');

              // Refresh user profile from server (like shop does)
              final userProvider =
                  Provider.of<UserProvider>(context, listen: false);
              await userProvider.reinitializeUser();

              // Refresh entitlements to update premium status
              await userProvider.refreshEntitlements();

              final updatedUser = userProvider.user;
              debugPrint(
                  '✅ [Subscription] User profile refreshed. Premium: ${updatedUser?.isPremium}');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Payment successful! Welcome to ${widget.planName}!',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.tertiary,
                  duration: const Duration(seconds: 3),
                ),
              );
              // Return success so parent screen refreshes subscription state
              Navigator.of(context).pop(true);
              return;
            }
          }
        }

        debugPrint('⚠️ [Subscription] Payment not completed after 3 checks');
      } catch (e2) {
        debugPrint('⚠️ [Subscription] Attempt status check failed: $e2');
      }

      if (mounted) {
        final errorMessage = _getUserFriendlyErrorMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                Future.delayed(const Duration(milliseconds: 500), () {
                  _startPayment();
                });
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingPayment = false;
        });
      }
    }
  }

  Future<bool> _verifyPaymentWithRetry({
    required String transactionId,
    required String txRef,
    required String userId,
    required String planId,
    required num amount,
  }) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Payment verification attempt $attempt/$maxRetries');

        final success = await _paymentService.verifyFlutterwaveTransaction(
          transactionId: transactionId,
          txRef: txRef,
          userId: userId,
          type: 'subscription',
          planId: planId,
          planName: widget.planName,
          durationDays: _durationDaysFromLabel(widget.duration),
          amount: amount,
          currency: 'NGN',
        );

        if (success) {
          debugPrint('Payment verification successful');
          return true;
        }

        debugPrint('Payment verification failed, attempt $attempt');

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        debugPrint('Payment verification error (attempt $attempt): $e');

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }

    debugPrint('Payment verification failed after $maxRetries attempts');
    return false;
  }

  String _getUserFriendlyErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('network') ||
        lowerError.contains('internet') ||
        lowerError.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (lowerError.contains('timeout') ||
        lowerError.contains('taking longer')) {
      return 'Request timed out. Please check your subscription status or try again.';
    } else if (lowerError.contains('cancelled')) {
      return 'Payment was cancelled. If you completed payment, please wait a moment and check your subscription status.';
    } else if (lowerError.contains('insufficient')) {
      return 'Payment declined - Insufficient funds. Please ensure your card has enough balance and try again. If issue persists, try a different card.';
    } else if (lowerError.contains('declined')) {
      return 'Payment was declined. Please try a different payment method.';
    } else if (lowerError.contains('expired')) {
      return 'Payment method expired. Please try again.';
    } else if (lowerError.contains('verification') ||
        lowerError.contains('unknown')) {
      return 'Payment status unclear. Please check your subscription status or contact support if money was deducted.';
    } else {
      return 'Payment processing issue. Please check your subscription status or try again.';
    }
  }
}
