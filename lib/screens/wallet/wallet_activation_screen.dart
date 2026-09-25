import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/wallet_service.dart';

/// Wallet activation via one-time Parent Portal approval.
class WalletActivationScreen extends StatefulWidget {
  const WalletActivationScreen({super.key});

  @override
  State<WalletActivationScreen> createState() => _WalletActivationScreenState();
}

class _WalletActivationScreenState extends State<WalletActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final WalletService _walletService = WalletService();

  bool _isSending = false;
  bool _isChecking = false;
  String _consentStatus = 'none';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    _emailController.text = user.parentEmail ?? '';
    await _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;
    setState(() => _isChecking = true);

    final results = await Future.wait([
      _walletService.checkConsentStatus(user.id),
      _walletService.getWalletStatus(user.id),
    ]);
    final consentStatus = results[0] as String;
    final walletStatus = results[1] as Map<String, dynamic>;
    final profileStatus = walletStatus['status'] as String? ?? 'inactive';

    if (!mounted) return;
    setState(() {
      _consentStatus = consentStatus;
      _isChecking = false;
    });

    if (profileStatus == 'active' ||
        consentStatus == 'approved' ||
        user.isWalletActive) {
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
    }
  }

  Future<void> _requestInAppApproval() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isSending = true);
    final result = await _walletService.requestActivationInApp(
      parentEmail: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] == true) {
      await Provider.of<UserProvider>(context, listen: false).reinitializeUser();
      await _refreshStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent. Ask your parent to open MLQ → Profile → Parent Portal and tap Approve.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to send request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final isActive = user?.isWalletActive ?? false;
    final isPending = user?.isWalletPendingConsent ?? _consentStatus == 'pending';
    final parentEmail = _emailController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0820),
        foregroundColor: Colors.white,
        title: const Text('Activate LeadWallet'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                const SizedBox(height: 24),
                if (isActive) ...[
                  _buildStatusCard(
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    title: 'LeadWallet is active',
                    subtitle: 'You can receive rewards and request withdrawals.',
                    actionLabel: 'Open Wallet',
                    onAction: () => Navigator.pushReplacementNamed(context, '/wallet'),
                  ),
                ] else if (isPending) ...[
                  _buildStatusCard(
                    icon: Icons.family_restroom_rounded,
                    color: const Color(0xFFFFB800),
                    title: 'Waiting for parent approval',
                    subtitle:
                        'Your parent (${parentEmail.isNotEmpty ? parentEmail : 'linked account'}) needs to open MLQ, go to Profile → Parent Portal, and approve LeadWallet.',
                    actionLabel: _isChecking ? 'Checking…' : 'Refresh status',
                    onAction: _isChecking ? null : _refreshStatus,
                  ),
                ] else ...[
                  Text(
                    'Parent / guardian email',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Must match your parent\'s MLQ account email so they can approve in Parent Portal.',
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'parent@example.com',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter parent email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      final studentEmail = user?.email?.trim().toLowerCase();
                      if (studentEmail != null &&
                          studentEmail.isNotEmpty &&
                          v.trim().toLowerCase() == studentEmail) {
                        return 'Use your parent\'s email, not your own';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _requestInAppApproval,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Request parent approval'),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _buildInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF2D0854)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFFD700), size: 48),
          const SizedBox(height: 12),
          Text(
            'LeadWallet Rewards',
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Earn approved cash rewards for leadership achievements. A parent approves LeadWallet once; withdrawals still go through admin review.',
            style: AppTextStyles.caption.copyWith(color: Colors.white70, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: AppTextStyles.bodyBold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.caption.copyWith(height: 1.4)),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works', style: AppTextStyles.heading3.copyWith(color: AppColors.primary)),
        const SizedBox(height: 12),
        _step('1', 'Parent approves LeadWallet in Parent Portal'),
        _step('2', 'You earn cash rewards from school/admin-approved achievements'),
        _step('3', 'Add a bank account and request a withdrawal (admin reviewed)'),
        _step('4', 'Funds are sent to your verified account'),
      ],
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
