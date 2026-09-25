import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/flutterwave_wallet_service.dart';
import '../../services/supabase_service.dart';

/// Bank Account Setup Screen for Withdrawals
/// 
/// Allows students to add their Nigerian bank account for withdrawals.
/// Uses Flutterwave API to validate account details before saving.
class WithdrawalBankSetupScreen extends StatefulWidget {
  const WithdrawalBankSetupScreen({super.key});

  @override
  State<WithdrawalBankSetupScreen> createState() => _WithdrawalBankSetupScreenState();
}

class _WithdrawalBankSetupScreenState extends State<WithdrawalBankSetupScreen> {
  final FlutterwaveWalletService _walletService = FlutterwaveWalletService();
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();

  bool _isLoadingBanks = true;
  bool _isValidating = false;
  bool _isAccountValidated = false;
  bool _isFlutterwaveSandbox = false;
  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  String? _accountName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _isLoadingBanks = true);
    final banks = await _walletService.getNigerianBanks();
    // Normalize + sort so the picker is stable (code is the identity key).
    final normalized = banks
        .map((b) => {
              'code': (b['code'] ?? '').toString(),
              'name': (b['name'] ?? '').toString(),
              if (b['id'] != null) 'id': b['id'],
            })
        .where((b) => (b['code'] as String).isNotEmpty && (b['name'] as String).isNotEmpty)
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    setState(() {
      _banks = normalized;
      _isFlutterwaveSandbox = _walletService.isFlutterwaveSandbox;
      _isLoadingBanks = false;
      // Keep selection if still in list (by code), else clear.
      if (_selectedBank != null) {
        final code = _selectedBank!['code']?.toString();
        Map<String, dynamic>? match;
        for (final b in normalized) {
          if (b['code']?.toString() == code) {
            match = b;
            break;
          }
        }
        _selectedBank = match;
      }
    });
  }

  Future<void> _openBankPicker() async {
    if (_banks.isEmpty) {
      setState(() => _errorMessage = 'No banks available. Pull to refresh or try again.');
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BankPickerSheet(
        banks: _banks,
        selectedCode: _selectedBank?['code']?.toString(),
        sandboxMode: _isFlutterwaveSandbox,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedBank = selected;
        _isAccountValidated = false;
        _accountName = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _validateAccount() async {
    if (_selectedBank == null || _accountNumberController.text.length != 10) {
      setState(() => _errorMessage = 'Please select a bank and enter a valid 10-digit account number');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _isAccountValidated = false;
      _accountName = null;
    });

    final result = await _walletService.validateBankAccount(
      accountNumber: _accountNumberController.text,
      accountBank: _selectedBank!['code'],
    );

    setState(() {
      _isValidating = false;
      if (result['success'] == true) {
        _isAccountValidated = true;
        _accountName = result['account_name'];
      } else {
        _errorMessage = result['error'] ?? 'Failed to validate account';
      }
    });
  }

  Future<void> _saveAccount() async {
    if (!_isAccountValidated || _accountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please validate your account first')),
      );
      return;
    }

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please login again.')),
      );
      return;
    }

    try {
      // Save via secure RPC. Direct writes to withdrawal_* columns are
      // blocked by the profiles guard trigger; only this SECURITY DEFINER
      // function may persist verified bank details for the caller.
      final rpcResult = await SupabaseService().client.rpc(
        'save_withdrawal_bank',
        params: {
          'p_bank_code': _selectedBank!['code'],
          'p_bank_name': _selectedBank!['name'],
          'p_account_number': _accountNumberController.text,
          'p_account_name': _accountName,
        },
      );

      final resultMap = Map<String, dynamic>.from(rpcResult as Map);
      if (resultMap['success'] != true) {
        throw Exception(resultMap['error'] ?? 'Failed to save bank account');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bank account saved: $_accountName'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, {
          'bank_code': _selectedBank!['code'],
          'bank_name': _selectedBank!['name'],
          'account_number': _accountNumberController.text,
          'account_name': _accountName,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bank account: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
          'Add Bank Account',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoadingBanks
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
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 16),
                    if (_isFlutterwaveSandbox) _buildSandboxBanner(),
                    const SizedBox(height: 16),

                    // Bank selection
                    _buildBankDropdown(),
                    const SizedBox(height: 20),

                    // Account number
                    _buildAccountNumberField(),
                    const SizedBox(height: 20),

                    // Validate button
                    _buildValidateButton(),
                    const SizedBox(height: 20),

                    // Validation result
                    if (_isAccountValidated && _accountName != null)
                      _buildValidationSuccess(),
                    if (_errorMessage != null)
                      _buildValidationError(),
                    const SizedBox(height: 32),

                    // Save button
                    if (_isAccountValidated)
                      _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF2D0854)],
        ),
        borderRadius: BorderRadius.circular(20),
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
              Icons.account_balance_rounded,
              color: Color(0xFFFFD700),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Withdrawal Account',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add your Nigerian bank account to receive your rewards',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSandboxBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: Color(0xFFE5A800), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Flutterwave is still in TEST mode — only Access Bank appears here. '
              'To add your real bank, switch Supabase secrets to live Flutterwave V3 keys, '
              'then reopen this screen.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Color(0xFF5D4E00),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDropdown() {
    final selectedName = _selectedBank?['name']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Bank',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _openBankPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedName?.isNotEmpty == true
                          ? selectedName!
                          : 'Choose your bank',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: selectedName != null
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selectedName != null
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
        ),
        if (_banks.isEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadBanks,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry loading banks'),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildAccountNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Number',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _accountNumberController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Enter 10-digit account number',
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
            counterText: '',
          ),
          onChanged: (_) {
            setState(() {
              _isAccountValidated = false;
              _accountName = null;
              _errorMessage = null;
            });
          },
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildValidateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isValidating ? null : _validateAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F8EF7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isValidating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Validate Account',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildValidationSuccess() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Verified',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _accountName!,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildValidationError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).shake();
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: const Text(
          'Save Bank Account',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.2, end: 0);
  }
}

/// Searchable bank list — avoids DropdownButton<Map> identity bugs on web.
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({
    required this.banks,
    required this.selectedCode,
    required this.sandboxMode,
  });

  final List<Map<String, dynamic>> banks;
  final String? selectedCode;
  final bool sandboxMode;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.banks;
    return widget.banks.where((b) {
      final name = (b['name'] ?? '').toString().toLowerCase();
      final code = (b['code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final height = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Bank',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (widget.sandboxMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Test mode: only Access Bank is available until live Flutterwave keys are configured.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: !widget.sandboxMode,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search bank name…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No banks match “$_query”',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final bank = filtered[index];
                      final code = bank['code']?.toString() ?? '';
                      final name = bank['name']?.toString() ?? '';
                      final isSelected = code == widget.selectedCode;
                      return ListTile(
                        title: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        subtitle: Text(
                          'Code $code',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFFE5A800))
                            : null,
                        onTap: () => Navigator.pop(context, bank),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
