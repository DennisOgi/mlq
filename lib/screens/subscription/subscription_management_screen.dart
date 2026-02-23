import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_leadership_quest/widgets/quest_button.dart';
import 'package:provider/provider.dart';
import 'upgrade_subscription_screen.dart';
import '../../providers/user_provider.dart';
import '../../services/subscription_service.dart';
import '../../services/coin_service.dart' as coin_svc;
import '../../constants/app_constants.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final coin_svc.CoinService _coinService = coin_svc.CoinService();

  bool _isLoading = true;
  Map<String, dynamic>? _activeSubscription;
  List<Map<String, dynamic>> _availablePlans = [];
  num _coinBalance = 0;
  late UserProvider _userProvider;

  // Fallback plans used if none are returned from Supabase (e.g., empty seed or RLS)
  // Prices and durations mirror the previous onboarding tier cards.
  static const List<Map<String, dynamic>> _fallbackPlans = [
    {
      'id': 'basic_monthly',
      'name': 'Basic',
      'description': 'Great for getting started with MLQ basics.',
      'price': 2500, // ₦2,500 monthly
      'duration_days': 30,
      'features': {
        'ai_coach': true,
        'coins': 500,
        'daily_goal_tracker': true,
        'challenges': 'basic_only',
        'weekly_reports': true,
        'courses_and_quiz': true,
        'premium_checkmark': false,
      },
      'is_active': true,
    },
    {
      'id': 'premium_monthly',
      'name': 'Premium',
      'description': 'Unlock all premium challenges and advanced features.',
      'price': 5000, // ₦5,000 monthly
      'duration_days': 30,
      'features': {
        'all_basic_features': true,
        'premium_checkmark': true,
        'coins': 1100,
        'unlimited_challenges': true,
        'communities': true,
      },
      'is_active': true,
    },
  ];

  // Global key for the plans section to enable scrolling to it
  final GlobalKey _plansKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Get UserProvider in initState to avoid context issues in async methods
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _loadData();
  }

  void _openPlansSheet() {
    // Never block the user; if no plans loaded, use fallback locally
    final plansSource = _availablePlans.isNotEmpty
        ? _availablePlans
        : List<Map<String, dynamic>>.from(_fallbackPlans);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final plans = plansSource
            .where((p) => (p['name'] as String?) != 'Trial')
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text('Choose Your Plan', style: AppTextStyles.heading3),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a plan to continue to secure payment',
                  style:
                      AppTextStyles.caption.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final name = plan['name'] as String? ?? 'Plan';
                      final price = plan['price'] ?? 0;
                      final durationDays = plan['duration_days'] ?? 30;
                      String durationText;
                      if (durationDays == 30) {
                        durationText = 'Monthly';
                      } else if (durationDays == 90) {
                        durationText = 'Quarterly';
                      } else if (durationDays == 365) {
                        durationText = 'Yearly';
                      } else {
                        durationText = '$durationDays days';
                      }

                      final isPopular = name.toLowerCase() == 'premium';

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isPopular
                                  ? AppColors.primary
                                  : Colors.grey.shade300),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name,
                                            style: AppTextStyles.heading3),
                                        if (isPopular) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondary,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'POPULAR',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        '₦$price · $durationText', // Naira symbol
                                        style: AppTextStyles.body),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          UpgradeSubscriptionScreen(
                                        planId: plan['id'],
                                        planName: name,
                                        price: price,
                                        duration: durationText,
                                      ),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    _loadData();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Continue'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Use the stored _userProvider instead of accessing context in async method
    final userId = _userProvider.user?.id;

    if (userId != null) {
      // Load subscription data
      final activeSubscription =
          await _subscriptionService.getActiveSubscription(userId);
      var availablePlans = await _subscriptionService.getAllPlans();
      // Robust fallback if DB has no rows or RLS blocks
      if (availablePlans.isEmpty) {
        availablePlans = List<Map<String, dynamic>>.from(_fallbackPlans);
      }
      final coinBalance = await _coinService.getUserCoins(userId);

      if (mounted) {
        setState(() {
          _activeSubscription = activeSubscription;
          _availablePlans = availablePlans;
          _coinBalance = coinBalance;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final bool isPremium = userProvider.user?.isPremium ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Subscription Plans',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current subscription info
                    _buildCurrentSubscriptionCard(context),
                    const SizedBox(height: 24),

                    // Coin balance
                    _buildCoinBalanceCard(),
                    const SizedBox(height: 24),

                    // Available plans if not premium
                    if (!isPremium) ...[
                      // Add key to this section for scrolling
                      Container(
                        key: _plansKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star,
                                    color: AppColors.secondary, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  'Choose Your Plan',
                                  style: AppTextStyles.heading2
                                      .copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select the perfect plan for your leadership journey',
                              style: AppTextStyles.body
                                  .copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                            ..._buildAvailablePlansCards(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],

                    // Subscription FAQ
                    ExpansionTile(
                      title: Text(
                        'Frequently Asked Questions',
                        style: AppTextStyles.bodyBold,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFaqItem('How do I cancel my subscription?',
                                  'You can cancel your subscription at any time by clicking the "Cancel Subscription" button. Your subscription will remain active until the end of your current billing period.'),
                              _buildFaqItem(
                                  'What happens to my coins when I cancel?',
                                  'Your coins will remain in your account even if you cancel your subscription. You can continue to use them to access premium features.'),
                              _buildFaqItem('How do I get more coins?',
                                  'You can earn coins by completing goals and challenges, or by purchasing a subscription plan.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentSubscriptionCard(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM dd, yyyy');

    if (_activeSubscription == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock Premium Features',
                style:
                    AppTextStyles.heading2.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Get unlimited access to premium challenges, advanced courses, and exclusive features.',
                style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QuestButton(
                text: 'View Plans',
                type: QuestButtonType.primary,
                onPressed: _openPlansSheet,
              ),
            ],
          ),
        ),
      );
    }

    final plan = _activeSubscription!['subscription_plans'];
    final startDate = DateTime.parse(_activeSubscription!['start_date']);
    final endDate = DateTime.parse(_activeSubscription!['end_date']);
    final isAutoRenew = _activeSubscription!['auto_renew'] ?? false;

    // Calculate days remaining
    final daysRemaining = endDate.difference(DateTime.now()).inDays;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Plan: ${plan['name']}',
                  style: AppTextStyles.heading3,
                ),
                _buildStatusBadge(plan['name']),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Start Date',
              formatter.format(startDate),
            ),
            _buildInfoRow(
              'Renewal Date',
              formatter.format(endDate),
            ),
            _buildInfoRow(
              'Auto-Renewal',
              isAutoRenew ? 'On' : 'Off',
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value:
                  1 - (daysRemaining / (endDate.difference(startDate).inDays)),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                daysRemaining < 7 ? Colors.orange : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$daysRemaining days remaining',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: QuestButton(
                    text: isAutoRenew
                        ? 'Turn Off Auto-Renewal'
                        : 'Turn On Auto-Renewal',
                    type: QuestButtonType.outline,
                    onPressed: () async {
                      // Toggle auto-renewal
                      await _toggleAutoRenewal(
                          _activeSubscription!['id'], !isAutoRenew);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: QuestButton(
                    text: 'Cancel Subscription',
                    type: QuestButtonType.outline,
                    onPressed: () async {
                      // Show confirmation dialog
                      final confirmed = await _showCancellationDialog();
                      if (confirmed == true) {
                        await _cancelSubscription(_activeSubscription!['id']);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String planName) {
    Color color;
    switch (planName.toLowerCase()) {
      case 'premium':
        color = Colors.purple;
        break;
      case 'basic':
        color = AppColors.primary;
        break;
      case 'trial':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        planName,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monetization_on,
                color: AppColors.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Coin Balance',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_coinBalance',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'coins available',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/shop');
                },
                child: Text(
                  'Buy More',
                  style: AppTextStyles.button.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getPlanFeatures(String planName) {
    switch (planName.toLowerCase()) {
      case 'basic':
        return [
          '500 coins per month',
          'Basic challenges access',
          'Leadership mini courses',
        ];
      case 'premium':
        return [
          'Premium subscription qualifies for rewards',
          '1000 coins per month',
          'Unlimited premium challenges',
          'Leadership mini courses',
          'Premium checkmark badge',
        ];
      default:
        return [
          'Access to premium features',
          'Enhanced learning experience',
        ];
    }
  }

  List<Widget> _buildAvailablePlansCards() {
    return _availablePlans.where((plan) => plan['name'] != 'Trial').map((plan) {
      final features = plan['features'] ?? {};
      final price = plan['price'] ?? 0;
      final durationDays = plan['duration_days'] ?? 30;
      final coins = features['coins'] ?? 0;

      String durationText;
      if (durationDays == 30) {
        durationText = 'Monthly';
      } else if (durationDays == 90) {
        durationText = 'Quarterly';
      } else if (durationDays == 365) {
        durationText = 'Yearly';
      } else {
        durationText = '$durationDays days';
      }

      final isPopular = plan['name'].toLowerCase() == 'premium';

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isPopular
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPopular ? null : Colors.white,
          border: Border.all(
            color: isPopular ? AppColors.primary : Colors.grey.shade300,
            width: isPopular ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPopular
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: isPopular ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['name'],
                            style: AppTextStyles.heading2.copyWith(
                              color:
                                  isPopular ? AppColors.primary : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            durationText,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₦${price.toString()}', // Naira symbol
                            style: AppTextStyles.heading2.copyWith(
                              color:
                                  isPopular ? AppColors.primary : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/$durationText',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    plan['description'] ?? 'Unlock premium features',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Features list
                  ..._getPlanFeatures(plan['name']).map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
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
                              feature,
                              style: AppTextStyles.body.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: isPopular
                          ? LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            )
                          : null,
                      color: isPopular ? null : AppColors.primary,
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        // Navigate to upgrade screen
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => UpgradeSubscriptionScreen(
                              planId: plan['id'],
                              planName: plan['name'],
                              price: price,
                              duration: durationText,
                            ),
                          ),
                        );
                        // Always reload after returning (handles cases where payment succeeded
                        // but flow returned falsey due to UI close/cancel)
                        if (mounted) {
                          _loadData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Choose ${plan['name']}',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildFeatureRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.body,
          ),
          Text(
            value,
            style: AppTextStyles.bodyBold,
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Future<bool?> _showCancellationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? You will still have access to premium features until the end of your current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NO, KEEP IT'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription(String subscriptionId) async {
    setState(() {
      _isLoading = true;
    });

    final success =
        await _subscriptionService.cancelSubscription(subscriptionId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh data
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel subscription'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoRenewal(String subscriptionId, bool autoRenew) async {
    // To be implemented with Supabase
    // This is a placeholder for now
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-renewal ${autoRenew ? 'enabled' : 'disabled'}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
