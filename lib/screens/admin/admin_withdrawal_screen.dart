import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/wallet_service.dart';
import '../../services/flutterwave_wallet_service.dart';

/// Admin screen to review and process student withdrawal requests.
class AdminWithdrawalScreen extends StatefulWidget {
  /// When true, renders only the list (for embedding in [RewardDisbursementScreen]).
  final bool embedded;

  const AdminWithdrawalScreen({super.key, this.embedded = false});

  @override
  State<AdminWithdrawalScreen> createState() => _AdminWithdrawalScreenState();
}

class _AdminWithdrawalScreenState extends State<AdminWithdrawalScreen> {
  final WalletService _walletService = WalletService();
  final FlutterwaveWalletService _flutterwaveService = FlutterwaveWalletService();
  final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');
  final _dateFormat = DateFormat('MMM d, yyyy • h:mm a');

  bool _isLoading = true;
  String? _processingId;
  List<Map<String, dynamic>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rows = await _walletService.getPendingWithdrawalsAdmin();
    if (!mounted) return;
    setState(() {
      _withdrawals = rows;
      _isLoading = false;
    });
  }

  Future<void> _approveAndPayout(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final amount = (row['amount_naira'] as num?)?.toDouble() ??
        ((row['amount_kobo'] as num?)?.toDouble() ?? 0) / 100;
    final student = row['student_name']?.toString() ?? 'Student';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & send payout?'),
        content: Text(
          'Send ₦${_nairaFormat.format(amount)} to $student via Flutterwave?\n\n'
          'Account: ${row['account_name']}\n'
          '${row['account_number']} (${row['bank_code']})',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve & Pay'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingId = id);

    final approveResult = await _walletService.adminApproveWithdrawal(id);
    if (approveResult['success'] != true) {
      if (!mounted) return;
      setState(() => _processingId = null);
      _showSnack(approveResult['error']?.toString() ?? 'Approval failed', isError: true);
      return;
    }

    final payoutResult = await _flutterwaveService.processWithdrawal(withdrawalId: id);
    if (!mounted) return;
    setState(() => _processingId = null);

    if (payoutResult['success'] == true) {
      final simulated = payoutResult['simulated'] == true;
      _showSnack(
        simulated
            ? 'Sandbox payout simulated for $student (no real transfer)'
            : 'Payout initiated for $student',
      );
      await _loadData();
    } else {
      final error = payoutResult['error']?.toString() ?? 'Unknown error';
      if (error.toLowerCase().contains('ip whitelisting')) {
        _showPayoutSetupDialog(error);
      } else {
        _showSnack('Approved but payout failed: $error', isError: true);
      }
      await _loadData();
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final reasonController = TextEditingController(text: 'Rejected by admin');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject withdrawal?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingId = id);
    final result = await _walletService.adminRejectWithdrawal(
      id,
      reason: reasonController.text.trim(),
    );
    reasonController.dispose();
    if (!mounted) return;
    setState(() => _processingId = null);

    if (result['success'] == true) {
      _showSnack('Withdrawal rejected');
      await _loadData();
    } else {
      _showSnack(result['error']?.toString() ?? 'Rejection failed', isError: true);
    }
  }

  Future<void> _retryPayout(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    setState(() => _processingId = id);
    final payoutResult = await _flutterwaveService.processWithdrawal(withdrawalId: id);
    if (!mounted) return;
    setState(() => _processingId = null);

    if (payoutResult['success'] == true) {
      _showSnack('Payout initiated');
      await _loadData();
    } else {
      _showSnack(
        'Payout failed: ${payoutResult['error'] ?? 'Unknown error'}',
        isError: true,
      );
    }
  }

  Future<void> _syncProcessing(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    setState(() => _processingId = id);
    final result = await _flutterwaveService.syncWithdrawalStatus(withdrawalId: id);
    if (!mounted) return;
    setState(() => _processingId = null);

    if (result['success'] != true) {
      _showSnack(result['error']?.toString() ?? 'Sync failed', isError: true);
      return;
    }

    final status = result['status']?.toString() ?? 'processing';
    if (status == 'paid') {
      _showSnack(
        result['simulated'] == true
            ? 'Sandbox payout confirmed and wallet debited'
            : 'Payout confirmed and wallet debited',
      );
    } else if (status == 'failed') {
      _showSnack('Flutterwave reports failed — funds released', isError: true);
    } else {
      final flw = result['flutterwave_status']?.toString() ?? status;
      _showSnack(
        result['message']?.toString() ??
            'Still processing at Flutterwave ($flw). Use Mark Failed if this is a stale sandbox transfer.',
      );
    }
    await _loadData();
  }

  Future<void> _markFailed(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final amount = (row['amount_naira'] as num?)?.toDouble() ??
        ((row['amount_kobo'] as num?)?.toDouble() ?? 0) / 100;
    final reasonController = TextEditingController(
      text: 'Stale sandbox transfer — webhook never completed',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark withdrawal failed?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This releases ₦${_nairaFormat.format(amount)} back to available '
              'balance. It does not debit the wallet. Only use this when the '
              'Flutterwave transfer did not complete (or is a stale sandbox test).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Failed', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingId = id);
    final result = await _walletService.adminFailWithdrawal(
      id,
      reason: reasonController.text.trim(),
    );
    reasonController.dispose();
    if (!mounted) return;
    setState(() => _processingId = null);

    if (result['success'] == true) {
      _showSnack('Withdrawal marked failed — available balance released');
      await _loadData();
    } else {
      _showSnack(result['error']?.toString() ?? 'Failed to update', isError: true);
    }
  }

  void _showPayoutSetupDialog(String details) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flutterwave IP whitelisting required'),
        content: SingleChildScrollView(
          child: Text(
            '$details\n\n'
            'After updating Flutterwave, tap Retry Flutterwave payout on the approved request.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminId = Provider.of<UserProvider>(context, listen: false).user?.id;
    final body = _buildBody(adminId);

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text(
          'Withdrawal Requests',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(String? adminId) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _withdrawals.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: widget.embedded
                            ? 320
                            : MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('✅', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 12),
                              Text(
                                'No pending withdrawals',
                                style: AppTextStyles.heading3,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Student bank withdrawal requests appear here for admin review.',
                                style: AppTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _withdrawals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final row = _withdrawals[index];
                      return _buildCard(row, adminId, index);
                    },
                  ),
          );
  }

  Widget _buildCard(Map<String, dynamic> row, String? adminId, int index) {
    final id = row['id'] as String;
    final isProcessing = _processingId == id;
    final status = row['status']?.toString() ?? 'pending_admin_approval';
    final amount = (row['amount_naira'] as num?)?.toDouble() ??
        ((row['amount_kobo'] as num?)?.toDouble() ?? 0) / 100;
    final createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'].toString())
        : null;

    final statusColor = status == 'approved'
        ? AppColors.success
        : status == 'pending_admin_approval'
            ? const Color(0xFFFFB800)
            : status == 'processing'
                ? const Color(0xFFE65100)
                : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['student_name']?.toString() ?? 'Student',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                    ),
                    if ((row['school_name']?.toString() ?? '').isNotEmpty)
                      Text(
                        row['school_name'].toString(),
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₦${_nairaFormat.format(amount)}',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          _detailRow(Icons.account_balance_rounded, row['account_name']?.toString() ?? '—'),
          _detailRow(Icons.numbers_rounded, row['account_number']?.toString() ?? '—'),
          _detailRow(Icons.business_rounded, 'Bank code: ${row['bank_code'] ?? '—'}'),
          if ((row['flutterwave_transfer_id']?.toString() ?? '').isNotEmpty)
            _detailRow(
              Icons.sync_alt_rounded,
              'Transfer: ${row['flutterwave_transfer_id']}',
            ),
          if (createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _dateFormat.format(createdAt.toLocal()),
                style: AppTextStyles.caption,
              ),
            ),
          const SizedBox(height: 14),
          if (status == 'pending_admin_approval') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => _reject(row),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isProcessing || adminId == null
                        ? null
                        : () => _approveAndPayout(row),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Approve & Pay Out'),
                  ),
                ),
              ],
            ),
          ] else if (status == 'approved') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : () => _retryPayout(row),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: isProcessing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Retry Flutterwave payout'),
              ),
            ),
          ] else if (status == 'processing') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => _markFailed(row),
                    child: const Text('Mark Failed'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : () => _syncProcessing(row),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sync Flutterwave Status'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms);
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}
