import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/user_provider.dart';
import '../../services/payment_service.dart';
import '../../services/flutterwave_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/flutterwave_webview_payment.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();
  bool _processing = false;
  String? _processingRef;
  int? _processingCoins;

  // Store payment data to preserve across WebView navigation
  double? _pendingAmount;
  int? _pendingCoins;
  String? _pendingTxRef;

  // Properly define userProvider as a getter

  UserProvider get userProvider =>
      Provider.of<UserProvider>(context, listen: false);

  // Coin packages priced at ₦5 per coin
  static const List<Map<String, dynamic>> coinPackages = [
    {'productId': 'coins_50', 'coins': 50, 'price': '₦250', 'tag': 'Starter'},
    {'productId': 'coins_100', 'coins': 100, 'price': '₦500', 'tag': 'Popular'},
    {'productId': 'coins_500', 'coins': 500, 'price': '₦2,500'},
    {'productId': 'coins_750', 'coins': 750, 'price': '₦3,750'},
    {
      'productId': 'coins_1000',
      'coins': 1000,
      'price': '₦5,000',
      'tag': 'Best Value'
    },
    {'productId': 'coins_2000', 'coins': 2000, 'price': '₦10,000'},
  ];

  // Parse price text like "₦2,000" to numeric amount (e.g., 2000)
  double _parseAmount(String priceText) {
    final digits = priceText.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(digits) ?? 0.0;
  }

  Future<void> _startFlutterwavePaymentForPackage(
      Map<String, dynamic> package) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _processingCoins = package['coins'] as int?;
    });
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You need to be logged in to purchase coins'),
              backgroundColor: Colors.red),
        );
        setState(() => _processing = false);
        return;
      }

      final txRef = _uuid.v4();
      _processingRef = txRef;
      final amount = _parseAmount(package['price'] as String);
      final totalCoins = (package['coins'] as int);

      // CRITICAL: Store values before WebView to preserve across navigation
      _pendingAmount = amount;
      _pendingCoins = totalCoins;
      _pendingTxRef = txRef;

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔑 [Shop] BEFORE WEBVIEW - Payment Initialization');
      debugPrint('🔑 Amount: $amount NGN');
      debugPrint('🔑 Coins: $totalCoins');
      debugPrint('🔑 TxRef: $txRef');
      debugPrint('🔑 User ID: ${user.id}');
      debugPrint(
          '🔑 Stored in instance: amount=$_pendingAmount, coins=$_pendingCoins, txRef=$_pendingTxRef');
      debugPrint('═══════════════════════════════════════════════════');

      // Create payment attempt record in database
      try {
        await SupabaseService().client.rpc('create_payment_attempt', params: {
          'p_user_id': user.id,
          'p_tx_ref': txRef,
          'p_amount': amount,
          'p_coins': totalCoins,
          'p_currency': 'NGN',
          'p_metadata': {
            'package_id': package['productId'],
            'initiated_at': DateTime.now().toIso8601String(),
          },
        });
        debugPrint('✅ [Shop] Payment attempt created in database');
      } catch (e) {
        debugPrint('⚠️ [Shop] Failed to create payment attempt: $e');
      }

      // Initialize payment using Flutterwave API (following official docs)
      final flwService = FlutterwaveService();
      final initResult = await flwService.initializePayment(
        email: user.email ?? 'user@example.com',
        name: user.name,
        amount: amount,
        currency: 'NGN',
        txRef: txRef,
        redirectUrl: 'https://mlq.app/redirect',
        phoneNumber: '',
        meta: {
          'type': 'coins',
          'coins': totalCoins,
          'user_id': user.id,
          'tx_ref': txRef,
          'amount': amount,
          'expires_at':
              DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        },
      );

      if (!initResult['success']) {
        throw Exception(initResult['error'] ?? 'Failed to initialize payment');
      }

      final paymentLink = initResult['link'];
      debugPrint(
          '✅ [Shop] Payment link generated: ${paymentLink.substring(0, 50)}...');

      // Open payment link in WebView
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
      debugPrint('🔑 [Shop] AFTER WEBVIEW - Payment Result');
      debugPrint('🔑 Result: ${paymentResult?.toString() ?? "null"}');
      debugPrint('🔑 Instance values still available:');
      debugPrint('🔑   - Coins: $_pendingCoins');
      debugPrint('🔑   - Amount: $_pendingAmount');
      debugPrint('🔑   - TxRef: $_pendingTxRef');
      debugPrint('═══════════════════════════════════════════════════');

      if (!mounted) return;

      if (paymentResult == null || paymentResult['status'] == 'cancelled') {
        debugPrint('⚠️ [Shop] Payment cancelled by user or WebView closed');
        // Check if backend (webhook) already completed the payment
        try {
          if (_pendingTxRef != null) {
            final attempt = await SupabaseService()
                .client
                .from('payment_attempts')
                .select('status, coins')
                .eq('tx_ref', _pendingTxRef!)
                .maybeSingle();

            if (attempt != null && attempt['status'] == 'completed') {
              // Refresh user profile to reflect new balance
              await Provider.of<UserProvider>(context, listen: false)
                  .reinitializeUser();
              final updatedUser =
                  Provider.of<UserProvider>(context, listen: false).user;
              debugPrint(
                  '✅ [Shop] Backend shows completed. New balance: ${updatedUser?.coins}');
              if (!mounted) return;
              // Trigger UI rebuild to show updated balance immediately
              setState(() => _processing = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Payment completed. Coins credited: +${attempt['coins'] ?? ''}\nNew balance: ${(updatedUser?.coins ?? 0).toInt()}'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [Shop] Attempt status check failed: $e');
        }

        // Fallback: treat as cancelled if no completion detected
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment cancelled'),
              backgroundColor: Colors.orange),
        );
        setState(() => _processing = false);
        return;
      }

      if (paymentResult['status'] == 'error') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${paymentResult['message']}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _processing = false);
        return;
      }

      // Payment successful - verify with backend
      final transactionId = paymentResult['transaction_id'] ?? '';
      if (transactionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Missing transaction ID'),
              backgroundColor: Colors.red),
        );
        setState(() => _processing = false);
        return;
      }

      // Use stored values (preserved across WebView navigation)
      if (_pendingTxRef == null ||
          _pendingCoins == null ||
          _pendingAmount == null) {
        debugPrint('═══════════════════════════════════════════════════');
        debugPrint('❌ [Shop] CRITICAL ERROR: Pending values are null!');
        debugPrint('❌ txRef: $_pendingTxRef');
        debugPrint('❌ coins: $_pendingCoins');
        debugPrint('❌ amount: $_pendingAmount');
        debugPrint('❌ This should NEVER happen with the fix!');
        debugPrint('═══════════════════════════════════════════════════');
        throw Exception('Payment data lost during WebView navigation');
      }

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('🔑 [Shop] VERIFYING PAYMENT WITH EDGE FUNCTION');
      debugPrint('🔑 Transaction ID: $transactionId');
      debugPrint('🔑 TxRef (from instance): $_pendingTxRef');
      debugPrint('🔑 Coins (from instance): $_pendingCoins');
      debugPrint('🔑 Amount (from instance): $_pendingAmount NGN');
      debugPrint('🔑 User ID: ${user.id}');
      debugPrint('═══════════════════════════════════════════════════');

      final ok = await PaymentService().verifyFlutterwaveTransaction(
        transactionId: transactionId,
        txRef: _pendingTxRef!,
        userId: user.id,
        type: 'coins',
        coins: _pendingCoins!,
        amount: _pendingAmount!,
        currency: 'NGN',
      );
      debugPrint('🔑 [Shop] Verification result: $ok');

      if (ok) {
        if (!mounted) return;
        debugPrint('✅ [Shop] Coins credited successfully: +$_pendingCoins');

        // Update payment attempt status to completed
        try {
          await SupabaseService()
              .client
              .rpc('update_payment_attempt_status', params: {
            'p_tx_ref': _pendingTxRef,
            'p_status': 'completed',
            'p_transaction_id': transactionId,
            'p_event_data': {'coins_credited': _pendingCoins},
          });
        } catch (e) {
          debugPrint('⚠️ [Shop] Failed to update payment status: $e');
        }

        // Refresh user profile from server to reflect new balance
        await Provider.of<UserProvider>(context, listen: false)
            .reinitializeUser();

        final updatedUser =
            Provider.of<UserProvider>(context, listen: false).user;
        debugPrint(
            '✅ [Shop] User profile refreshed. New balance: ${updatedUser?.coins}');

        if (!mounted) return;
        // Trigger UI rebuild to show updated balance immediately
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Coins purchased: +$_pendingCoins\nNew balance: ${updatedUser?.coins?.toInt() ?? 0} coins'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        if (!mounted) return;

        // If verification failed, check if webhook completed the attempt
        bool completedByWebhook = false;
        try {
          if (_pendingTxRef != null) {
            final attempt = await SupabaseService()
                .client
                .from('payment_attempts')
                .select('status, coins')
                .eq('tx_ref', _pendingTxRef!)
                .maybeSingle();
            if (attempt != null && attempt['status'] == 'completed') {
              completedByWebhook = true;
              // Refresh user profile
              await Provider.of<UserProvider>(context, listen: false)
                  .reinitializeUser();
              final updatedUser =
                  Provider.of<UserProvider>(context, listen: false).user;
              if (!mounted) return;
              // Trigger UI rebuild to show updated balance immediately
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ Payment completed. Coins credited: +${attempt['coins'] ?? ''}\nNew balance: ${(updatedUser?.coins ?? 0).toInt()}'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint(
              '⚠️ [Shop] Attempt status check (verify failed path) error: $e');
        }

        if (!completedByWebhook) {
          // Update payment attempt status to failed
          try {
            await SupabaseService()
                .client
                .rpc('update_payment_attempt_status', params: {
              'p_tx_ref': _pendingTxRef ?? '',
              'p_status': 'failed',
              'p_event_data': {'error': 'verification_failed'},
            });
          } catch (e) {
            debugPrint('⚠️ [Shop] Failed to update payment status: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Verification failed. Please contact support.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // Update payment attempt status to failed
      try {
        if (_pendingTxRef != null) {
          await SupabaseService()
              .client
              .rpc('update_payment_attempt_status', params: {
            'p_tx_ref': _pendingTxRef!,
            'p_status': 'failed',
            'p_event_data': {'error': e.toString()},
          });
        }
      } catch (updateError) {
        debugPrint('⚠️ [Shop] Failed to update payment status: $updateError');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Payment error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted)
        setState(() {
          _processing = false;
          _processingCoins = null;
          // Clear stored payment data
          _pendingAmount = null;
          _pendingCoins = null;
          _pendingTxRef = null;
        });
    }
  }

  // Avatars section has been hidden per product requirements.

  @override
  void initState() {
    super.initState();
    // Single tab: Buy Coins
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildCoinPackage(Map<String, dynamic> package) {
    final bool isProcessing =
        _processing && _processingCoins == (package['coins'] as int?);
    final String? tag = package['tag'] as String?;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.12), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Coin icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/coin.jpeg',
                    fit: BoxFit.cover,
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.monetization_on,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Coin details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      '${package['coins']} Coins',
                      style: AppTextStyles.heading3,
                    ),
                  ],
                ),
              ),
              // Price button
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () => _startFlutterwavePaymentForPackage(package),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isProcessing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Processing...', style: AppTextStyles.bodyBold),
                        ],
                      )
                    : Text(
                        package['price'],
                        style: AppTextStyles.bodyBold,
                      ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildAvatarItem(AvatarModel avatar) {
    // Explicitly cast to bool to ensure type safety
    final bool canAfford = (userProvider.user?.coins ?? 0) >= avatar.price;
    final bool isOwned = userProvider.hasAvatar(avatar.id);

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: avatar.imagePath.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.asset(
                              avatar.imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 64,
                                  color: AppColors.primary,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 64,
                            color: AppColors.primary,
                          ),
                  ),
                ),
                if (!isOwned)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${avatar.price} coins',
                            style: AppTextStyles.bodyBold
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Text(
                  avatar.name,
                  style: AppTextStyles.heading3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (isOwned) {
                      // Avatar already owned – allow user to set as profile
                      _showSetAsProfileDialog(avatar);
                      return;
                    }

                    if (!canAfford) {
                      // Not enough coins – do nothing (button disabled below)
                      return;
                    }

                    // User can afford and does not own the avatar yet – purchase flow
                    final bool success =
                        await userProvider.spendCoins(avatar.price.toDouble());
                    if (success) {
                      userProvider.addAvatar(avatar);
                      _showSetAsProfileDialog(avatar);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Purchased ${avatar.name}!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to purchase avatar. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOwned
                        ? AppColors.success
                        : canAfford
                            ? AppColors.secondary
                            : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isOwned
                        ? 'Use Avatar'
                        : canAfford
                            ? 'Purchase'
                            : 'Not enough coins',
                    style: AppTextStyles.bodyBold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0));
  }

  void _showSetAsProfileDialog(AvatarModel avatar) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Profile Picture?'),
        content:
            Text('Do you want to use ${avatar.name} as your profile picture?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              userProvider.updateUserProfile(
                avatarUrl: avatar.imagePath,
              );
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile picture updated!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using the userProvider getter - no need to initialize

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, size: 28),
            const SizedBox(width: 8),
            Text(
              'Shop',
              style: AppTextStyles.heading3.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          labelStyle: AppTextStyles.bodyBold,
          unselectedLabelStyle: AppTextStyles.body,
          tabs: const [
            Tab(text: 'Buy Coins', icon: Icon(Icons.monetization_on)),
          ],
        ),
      ),
      body: Column(
        children: [
          // User's current coins
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monetization_on,
                    color: AppColors.primary, size: 32),
                const SizedBox(width: 8),
                Text(
                  'Your Coins: ${userProvider.user?.coins.toStringAsFixed(1) ?? "0.0"}',
                  style: AppTextStyles.heading3,
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Buy Coins Tab
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Purchase Coins',
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ...coinPackages.map(_buildCoinPackage).toList(),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.info, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'You can also earn coins by:',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyBold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Setting a goal (0.5 coins)\n• Completing a goal (0.5 coins)\n• Completing challenges',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
