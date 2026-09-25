import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/wallet_transaction_model.dart';
import '../../models/savings_goal_model.dart';
import '../../providers/user_provider.dart';
import '../../services/wallet_service.dart';
import '../challenges/challenges_screen.dart';
import 'savings_goal_screen.dart';
import 'wallet_activation_screen.dart';
import 'withdrawal_request_screen.dart';
import 'withdrawal_history_screen.dart';

class WalletDashboardScreen extends StatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  double _walletBalance = 0.0;
  String _walletStatus = 'inactive';
  List<WalletTransactionModel> _transactions = [];
  List<SavingsGoalModel> _savingsGoals = [];

  late AnimationController _balanceAnimController;
  late AnimationController _orbitController;
  late Animation<double> _balanceAnim;

  // Number formatter
  final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');
  final _nairaShort = NumberFormat('#,##0', 'en_NG');

  @override
  void initState() {
    super.initState();
    _balanceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _balanceAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _balanceAnimController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalletData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWalletData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _balanceAnimController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _walletService.getWalletStatus(user.id),
      _walletService.getTransactionHistory(user.id, limit: 20),
      _walletService.getActiveSavingsGoals(user.id),
    ]);

    if (!mounted) return;

    final status = results[0] as Map<String, dynamic>;
    final transactions = results[1] as List<WalletTransactionModel>;
    final goals = results[2] as List<SavingsGoalModel>;
    final newBalance = (status['balance'] as num).toDouble();
    final resolvedStatus = WalletService.normalizeWalletStatus(
      status['status'],
      activatedAt: status['activated_at'] != null
          ? DateTime.tryParse(status['activated_at'].toString())
          : null,
      balance: newBalance,
    );

    setState(() {
      _walletStatus = resolvedStatus;
      _transactions = transactions;
      _savingsGoals = goals;
      _walletBalance = newBalance;
      _isLoading = false;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.updateUser(user.copyWith(
      walletBalance: newBalance,
      walletStatus: resolvedStatus,
      walletActivatedAt: status['activated_at'] != null
          ? DateTime.tryParse(status['activated_at'].toString())
          : user.walletActivatedAt,
    ));
    await userProvider.refreshUser();

    _balanceAnim = Tween<double>(begin: 0, end: newBalance).animate(
      CurvedAnimation(parent: _balanceAnimController, curve: Curves.easeOutCubic),
    );
    _balanceAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.walletBgDeep,
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        color: AppColors.walletGold,
        child: CustomScrollView(
          slivers: [
            _buildHeroHeader(),
            SliverToBoxAdapter(
              child: _isLoading
                  ? const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.walletGold,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Header with Glassmorphism ─────────────────────────────────

  Widget _buildHeroHeader() {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: AppColors.walletBgDeep,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _showFullHistory,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('History',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Animated nebula background
            _buildNebulaBackground(),
            // Card content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Glowing wallet icon
                    Center(child: _buildWalletIcon()),
                    const SizedBox(height: 20),

                    // "LeadWallet" label
                    Center(
                      child: Text(
                        'L E A D W A L L E T',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Animated balance - CENTERED
                    Center(child: _buildAnimatedBalance()),
                    const SizedBox(height: 16),

                    // Status pill
                    Center(child: _buildStatusPill()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNebulaBackground() {
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        final t = _orbitController.value;
        return Stack(
          children: [
            // Deep purple brand base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.walletBg,
                    AppColors.walletBgDeep,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            // Floating orbs
            Positioned(
              left: -60 + 40 * math.sin(t * 2 * math.pi),
              top: 20 + 30 * math.cos(t * 2 * math.pi),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.45),
                      AppColors.primary.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -40 + 30 * math.cos(t * 2 * math.pi + 1),
              bottom: 20 + 40 * math.sin(t * 2 * math.pi + 2),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.walletBgMid.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: MediaQuery.of(context).size.width * 0.4,
              top: 60 + 20 * math.sin(t * 2 * math.pi + 1.5),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.walletGold.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Subtle mesh overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.walletBgDeep.withOpacity(0.65),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalletIcon() {
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        final pulse = 0.92 + 0.08 * math.sin(_orbitController.value * 2 * math.pi * 2);
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.walletGold, AppColors.accent2],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.walletGold.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedBalance() {
    return AnimatedBuilder(
      animation: _balanceAnim,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), AppColors.secondaryBright],
          ).createShader(bounds),
          child: Text(
            '₦${_nairaFormat.format(_balanceAnim.value)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill() {
    final cfg = _statusConfig(_walletStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cfg['color'].withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cfg['color'].withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg['icon'] as IconData, color: cfg['color'] as Color, size: 13),
          const SizedBox(width: 6),
          Text(
            cfg['label'] as String,
            style: TextStyle(
              color: cfg['color'] as Color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'active':
        return {
          'color': AppColors.success,
          'label': 'Active',
          'icon': Icons.check_circle_rounded,
        };
      case 'pending_consent':
        return {
          'color': const Color(0xFFFFB800),
          'label': 'Awaiting Parent Approval',
          'icon': Icons.hourglass_top_rounded,
        };
      case 'frozen':
        return {
          'color': AppColors.info,
          'label': 'Frozen',
          'icon': Icons.ac_unit_rounded,
        };
      default:
        return {
          'color': Colors.white.withOpacity(0.6),
          'label': 'Not Activated',
          'icon': Icons.info_outline_rounded,
        };
    }
  }

  // ─── Body Content ────────────────────────────────────────────────────

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildQuickActions()
                .animate()
                .fadeIn(duration: 500.ms, delay: 100.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 28),

          // Activation CTA (inactive or awaiting parent consent)
          if (_walletStatus == 'inactive' || _walletStatus == 'pending_consent') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildActivationCard()
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ),
            const SizedBox(height: 28),
          ],

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatsRow()
                .animate()
                .fadeIn(duration: 500.ms, delay: 250.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 28),

          // Recent earnings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTransactionsSection()
                .animate()
                .fadeIn(duration: 500.ms, delay: 350.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 28),

          // Savings goals
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: _buildSavingsSection()
                .animate()
                .fadeIn(duration: 500.ms, delay: 450.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Quick Actions ───────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final walletActive = _walletStatus == 'active';

    void onWithdrawTap() {
      if (!walletActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activate LeadWallet with one-time parent approval before withdrawing.'),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletActivationScreen()),
        ).then((_) => _loadWalletData());
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WithdrawalRequestScreen()),
      ).then((_) => _loadWalletData());
    }

    final actions = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'label': 'Withdraw',
        'primary': walletActive,
        'onTap': onWithdrawTap,
      },
      {
        'icon': Icons.savings_rounded,
        'label': 'Save',
        'primary': false,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SavingsGoalScreen())),
      },
      {
        'icon': Icons.receipt_long_rounded,
        'label': 'Requests',
        'primary': false,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WithdrawalHistoryScreen())),
      },
      {
        'icon': Icons.emoji_events_rounded,
        'label': 'Earn',
        'primary': false,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChallengesScreen(),
              ),
            ),
      },
    ];

    return Row(
      children: actions.asMap().entries.map((entry) {
        final i = entry.key;
        final a = entry.value;
        final primary = a['primary'] as bool;
        final bg = primary ? AppColors.secondary : AppColors.primarySoft;
        final fg = primary ? AppColors.textOnGold : AppColors.primary;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: a['onTap'] as VoidCallback,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(a['icon'] as IconData, color: fg, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        a['label'] as String,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final totalEarned = _transactions
        .where((t) => t.isCredit)
        .fold(0.0, (sum, t) => sum + t.displayAmount);
    final totalWithdrawn = _transactions
        .where((t) => t.type == 'payout')
        .fold(0.0, (sum, t) => sum + t.displayAmount);
    final totalSaved = _savingsGoals
        .fold(0.0, (sum, g) => sum + g.currentAmount);

    return Row(
      children: [
        _buildStatCard(
          label: 'Total earned',
          value: '₦${_nairaShort.format(totalEarned)}',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.goldText,
          bgColor: AppColors.secondary.withOpacity(0.22),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Withdrawn',
          value: '₦${_nairaShort.format(totalWithdrawn)}',
          icon: Icons.account_balance_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primarySoft,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Saved',
          value: '₦${_nairaShort.format(totalSaved)}',
          icon: Icons.savings_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primarySoft,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Activation Card ─────────────────────────────────────────────────

  Widget _buildActivationCard() {
    final isPending = _walletStatus == 'pending_consent';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.walletBg, AppColors.walletBgMid],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated rocket
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
              ),
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 28)),
            ),
          )
              .animate(onPlay: (c) => c.repeat(period: 2.seconds))
              .moveY(begin: 0, end: -4, curve: Curves.easeInOut, duration: 1.seconds)
              .then()
              .moveY(begin: -4, end: 0, curve: Curves.easeInOut, duration: 1.seconds),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? 'Waiting for parent approval' : 'Activate LeadWallet!',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPending
                      ? 'Ask your parent to open Parent Portal and approve LeadWallet.'
                      : 'One-time parent approval is required before you can receive cash rewards.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WalletActivationScreen(),
                      ),
                    ).then((_) => _loadWalletData());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isPending ? 'Check status →' : 'Activate →',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        color: AppColors.textOnGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
  }

  // ─── Savings Goals ───────────────────────────────────────────────────

  Widget _buildSavingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Savings Goals',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SavingsGoalScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'New Goal',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _savingsGoals.isEmpty
            ? _buildEmptySavings()
            : SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 4),
                  itemCount: _savingsGoals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _buildGoalCard(_savingsGoals[i]),
                ),
              ),
      ],
    );
  }

  Widget _buildEmptySavings() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SavingsGoalScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            const Text('🏦', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              'Start your first savings goal!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to save toward something awesome',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoalModel goal) {
    final pct = goal.progress;
    final progressColor = pct >= 1 ? AppColors.success : AppColors.goldPressed;

    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: progressColor.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.icon, style: const TextStyle(fontSize: 26)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${goal.progressPercent}%',
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            goal.title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Custom arc progress
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: progressColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${_nairaShort.format(goal.currentAmount)} of ₦${_nairaShort.format(goal.targetAmount)}',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const Spacer(),
          Text(
            '₦${_nairaShort.format(goal.remainingAmount)} to go',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transactions ─────────────────────────────────────────────────────

  Widget _buildTransactionsSection() {
    final earnings = _transactions.where((t) => t.isCredit).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent earnings',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (_transactions.isNotEmpty)
              TextButton(
                onPressed: _showFullHistory,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'See history',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        earnings.isEmpty
            ? _buildEmptyTransactions()
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: earnings.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 70,
                    color: AppColors.border,
                  ),
                  itemBuilder: (_, i) => _buildTxTile(earnings[i]),
                ),
              ),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('💫', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            'No earnings yet',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete challenges to earn wallet rewards!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTxTile(WalletTransactionModel tx) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppColors.success : AppColors.textSecondary;
    final dateStr = DateFormat('MMM d, h:mm a').format(tx.createdAt);

    final iconData = switch (tx.type) {
      'reward' => Icons.emoji_events_rounded,
      'savings_deposit' => Icons.savings_rounded,
      'savings_withdrawal' => Icons.output_rounded,
      'payout' => Icons.account_balance_rounded,
      _ => isCredit ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}₦${_nairaFormat.format(tx.displayAmount)}',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tx.typeLabel.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Full History Bottom Sheet ────────────────────────────────────────

  void _showFullHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('All Transactions',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        )),
                    Text('${_transactions.length} records',
                        style:
                            TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _transactions.isEmpty
                    ? Center(
                        child: Text('No transactions yet',
                            style: TextStyle(color: Colors.grey.shade400)))
                    : Container(
                        color: Colors.white,
                        child: ListView.separated(
                          controller: ctrl,
                          itemCount: _transactions.length,
                          padding: const EdgeInsets.only(bottom: 32),
                          separatorBuilder: (_, __) => Divider(
                              height: 1, indent: 70, color: Colors.grey.shade100),
                          itemBuilder: (_, i) => _buildTxTile(_transactions[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
