import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/flutterwave_wallet_service.dart';
import '../../services/wallet_service.dart';
import 'withdrawal_bank_setup_screen.dart';

/// Withdrawal Request Screen
/// 
/// Allows students to request withdrawals from their LeadWallet balance.
/// Requires bank account setup and parent consent.
class WithdrawalRequestScreen extends StatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  State<WithdrawalRequestScreen> createState() => _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends State<WithdrawalRequestScreen> {
  final FlutterwaveWalletService _flutterwaveService = FlutterwaveWalletService();
  final WalletService _walletService = WalletService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');

  bool _isLoading = true;
  bool _isSubmitting = false;
  double _walletBalance = 0.0;
  Map<String, dynamic>? _bankAccount;

  // Withdrawal limits
  static const int minWithdrawalKobo = 50000; // ₦500
  static const int maxWithdrawalKobo = 1000000; // ₦10,000
  static const int dailyLimitKobo = 1000000; // ₦10,000

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Load wallet balance
      final balance = await _walletService.getWalletBalance(user.id);

      // Load saved bank account from database
      final profileResponse = await _flutterwaveService.client
          .from('profiles')
          .select('withdrawal_bank_code, withdrawal_bank_name, withdrawal_account_number, withdrawal_account_name')
          .eq('id', user.id)
          .single();

      Map<String, dynamic>? bankAccount;
      if (profileResponse['withdrawal_account_number'] != null) {
        bankAccount = {
          'bank_code': profileResponse['withdrawal_bank_code'],
          'bank_name': profileResponse['withdrawal_bank_name'],
          'account_number': profileResponse['withdrawal_account_number'],
          'account_name': profileResponse['withdrawal_account_name'],
        };
      }

      setState(() {
        _walletBalance = balance;
        _bankAccount = bankAccount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _walletBalance = 0.0;
        _bankAccount = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bankAccount == null) {
      _showError('Please add a bank account first');
      return;
    }

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    final amountNaira = double.tryParse(_amountController.text) ?? 0;
    final amountKobo = _flutterwaveService.nairaToKobo(amountNaira);

    // Validate amount
    if (amountKobo < minWithdrawalKobo) {
      _showError('Minimum withdrawal is ₦${_flutterwaveService.koboToNaira(minWithdrawalKobo)}');
      return;
    }
    if (amountKobo > maxWithdrawalKobo) {
      _showError('Maximum withdrawal is ₦${_flutterwaveService.koboToNaira(maxWithdrawalKobo)}');
      return;
    }
    if (amountNaira > _walletBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _flutterwaveService.createWithdrawalRequest(
      userId: user.id,
      amountKobo: amountKobo,
      accountBank: _bankAccount!['bank_code'],
      accountNumber: _bankAccount!['account_number'],
      accountName: _bankAccount!['account_name'],
    );

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      if (mounted) {
        _showSuccess('Withdrawal request submitted successfully!');
        Navigator.pop(context, true);
      }
    } else {
      _showError(result['error'] ?? 'Failed to submit withdrawal request');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0820),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Withdrawal',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance card
                    _buildBalanceCard(),
                    const SizedBox(height: 24),

                    // Bank account card
                    _buildBankAccountCard(),
                    const SizedBox(height: 24),

                    // Amount input
                    _buildAmountInput(),
                    const SizedBox(height: 16),

                    // Limits info
                    _buildLimitsInfo(),
                    const SizedBox(height: 32),

                    // Submit button
                    _buildSubmitButton(),
                    const SizedBox(height: 16),

                    // Info card
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF2D0854)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A0533).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${_nairaFormat.format(_walletBalance)}',
            style: const TextStyle(
              fontFamily: 'Nunito',
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildBankAccountCard() {
    if (_bankAccount == null) {
      return GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WithdrawalBankSetupScreen(),
            ),
          );
          if (result != null) {
            setState(() => _bankAccount = result);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Bank Account',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Setup your bank account to receive withdrawals',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.2, end: 0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Withdrawal Account',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WithdrawalBankSetupScreen(),
                    ),
                  );
                  if (result != null) {
                    setState(() => _bankAccount = result);
                  }
                },
                child: const Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F8EF7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F8EF7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF4F8EF7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bankAccount!['bank_name'],
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_bankAccount!['account_number']} • ${_bankAccount!['account_name']}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Amount',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₦ ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildLimitsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Withdrawal Limits',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Minimum: ₦${_flutterwaveService.koboToNaira(minWithdrawalKobo).toStringAsFixed(0)}\n'
            '• Maximum per withdrawal: ₦${_flutterwaveService.koboToNaira(maxWithdrawalKobo).toStringAsFixed(0)}\n'
            '• Daily limit: ₦${_flutterwaveService.koboToNaira(dailyLimitKobo).toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting || _bankAccount == null ? null : _submitWithdrawal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Submit Withdrawal Request',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Processing Time',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Parent approval required\n'
            '2. Admin review (1-2 business days)\n'
            '3. Transfer to your bank (instant)',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.2, end: 0);
  }
}
