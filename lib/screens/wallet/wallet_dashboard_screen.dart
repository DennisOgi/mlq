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
import '../../services/bank_integration_service.dart';
import 'savings_goal_screen.dart';
import 'bank_setup_screen.dart';
import 'withdrawal_request_screen.dart';
import 'withdrawal_history_screen.dart';

class WalletDashboardScreen extends StatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen>
    with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final BankIntegrationService _bankService = BankIntegrationService();

  bool _isLoading = true;
  double _walletBalance = 0.0;
  String _walletStatus = 'inactive';
  bool _isSandboxMode = true;
  bool _hasBankAccount = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWalletData());
  }

  @override
  void dispose() {
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

    setState(() {
      _walletStatus = status['status'] as String;
      _hasBankAccount = status['has_bank_account'] as bool? ?? false;
      _isSandboxMode = status['is_sandbox'] as bool? ?? true;
      _transactions = transactions;
      _savingsGoals = goals;
      _walletBalance = newBalance;
      _isLoading = false;
    });

    _balanceAnim = Tween<double>(begin: 0, end: newBalance).animate(
      CurvedAnimation(parent: _balanceAnimController, curve: Curves.easeOutCubic),
    );
    _balanceAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0820),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        color: const Color(0xFFFFD700),
        child: CustomScrollView(
          slivers: [
            _buildHeroHeader(),
            SliverToBoxAdapter(
              child: _isLoading
                  ? const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
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
      backgroundColor: const Color(0xFF0D0820),
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
            // Deep purple base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0533),
                    Color(0xFF0D0820),
                    Color(0xFF0A1628),
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
                      AppColors.primary.withOpacity(0.35),
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
                      const Color(0xFF00C4FF).withOpacity(0.25),
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
                      const Color(0xFFFFD700).withOpacity(0.15),
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
                    const Color(0xFF0D0820).withOpacity(0.6),
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
                colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
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
            colors: [Color(0xFFFFFFFF), Color(0xFFFFD700)],
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
        color: const Color(0xFFF5F7FA),
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

          // Sandbox mode banner (if applicable)
          if (_isSandboxMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE69C)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: Color(0xFF856404), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sandbox Mode',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasBankAccount
                              ? 'Using mock bank integration for testing'
                              : 'Complete bank setup to activate real money features',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildQuickActions()
                .animate()
                .fadeIn(duration: 500.ms, delay: 100.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 28),

          // Activation CTA (only if inactive)
          if (_walletStatus == 'inactive') ...[
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

          // Savings goals
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: _buildSavingsSection()
                .animate()
                .fadeIn(duration: 500.ms, delay: 350.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
          const SizedBox(height: 28),

          // Recent transactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTransactionsSection()
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
    final actions = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'label': 'Withdraw',
        'colors': [const Color(0xFFFFD700), const Color(0xFFE5A800)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WithdrawalRequestScreen())).then((_) => _loadWalletData()),
      },
      {
        'icon': Icons.savings_rounded,
        'label': 'Save',
        'colors': [const Color(0xFF00E096), const Color(0xFF00B075)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SavingsGoalScreen())),
      },
      {
        'icon': Icons.receipt_long_rounded,
        'label': 'Requests',
        'colors': [const Color(0xFF4F8EF7), const Color(0xFF3B6FD4)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WithdrawalHistoryScreen())),
      },
      {
        'icon': Icons.emoji_events_rounded,
        'label': 'Earn',
        'colors': [const Color(0xFFFF6B9D), const Color(0xFFE0508A)],
        'onTap': () => Navigator.pushNamed(context, '/challenges'),
      },
    ];

    return Row(
      children: actions.asMap().entries.map((entry) {
        final i = entry.key;
        final a = entry.value;
        final colors = a['colors'] as List<Color>;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: a['onTap'] as VoidCallback,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a['icon'] as IconData, color: Colors.white, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      a['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
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
    final totalSaved = _savingsGoals
        .fold(0.0, (sum, g) => sum + g.currentAmount);

    return Row(
      children: [
        _buildStatCard(
          label: 'Total Earned',
          value: '₦${_nairaShort.format(totalEarned)}',
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.success,
          bgColor: const Color(0xFFE8FAF0),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Total Saved',
          value: '₦${_nairaShort.format(totalSaved)}',
          icon: Icons.savings_rounded,
          iconColor: const Color(0xFF4F8EF7),
          bgColor: const Color(0xFFEBF3FF),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: 'Goals Active',
          value: '${_savingsGoals.length}',
          icon: Icons.flag_rounded,
          iconColor: const Color(0xFFFF6B9D),
          bgColor: const Color(0xFFFFF0F5),
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
                color: Color(0xFF1A1A2E),
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
    final user = Provider.of<UserProvider>(context, listen: false).user;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0533), Color(0xFF2D0854)],
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
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.3),
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
                const Text(
                  'Activate LeadWallet!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set up your bank account to start earning real rewards',
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
                        builder: (_) => const BankSetupScreen(),
                      ),
                    ).then((_) => _loadWalletData());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Start Setup →',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                color: Color(0xFF1A1A2E),
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
    final progressColor = pct > 0.7
        ? AppColors.success
        : pct > 0.3
            ? const Color(0xFFFFB800)
            : const Color(0xFF4F8EF7);

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
              color: Color(0xFF1A1A2E),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            if (_transactions.length > 5)
              GestureDetector(
                onTap: _showFullHistory,
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _transactions.isEmpty
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
                  itemCount: math.min(_transactions.length, 5),
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 70,
                    color: Colors.grey.shade100,
                  ),
                  itemBuilder: (_, i) => _buildTxTile(_transactions[i]),
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
            'No transactions yet',
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
    final color = isCredit ? AppColors.success : AppColors.error;
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
                    color: Color(0xFF1A1A2E),
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
                          color: Color(0xFF1A1A2E),
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
