import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/flutterwave_wallet_service.dart';

/// Withdrawal History Screen
/// 
/// Shows all withdrawal requests and their statuses.
/// Allows students to track their withdrawal requests.
class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() => _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  final FlutterwaveWalletService _walletService = FlutterwaveWalletService();
  final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');
  final _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  bool _isLoading = true;
  List<Map<String, dynamic>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLoading = true);

    final withdrawals = await _walletService.getWithdrawalRequests(user.id);

    setState(() {
      _withdrawals = withdrawals;
      _isLoading = false;
    });
  }

  Future<void> _cancelWithdrawal(String withdrawalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Withdrawal?'),
        content: const Text('Are you sure you want to cancel this withdrawal request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _walletService.cancelWithdrawalRequest(withdrawalId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Withdrawal request cancelled'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadWithdrawals();
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
          'Withdrawal History',
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
          : RefreshIndicator(
              onRefresh: _loadWithdrawals,
              color: const Color(0xFFFFD700),
              child: _withdrawals.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _withdrawals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildWithdrawalCard(_withdrawals[i], i),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Withdrawals Yet',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your withdrawal requests will appear here',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> withdrawal, int index) {
    final status = withdrawal['status'] as String;
    final amountKobo = withdrawal['amount_kobo'] as int;
    final amountNaira = _walletService.koboToNaira(amountKobo);
    final createdAt = DateTime.parse(withdrawal['created_at'] as String);
    final statusConfig = _getStatusConfig(status);
    final canCancel = status == 'pending_parent_approval' || status == 'pending_admin_approval';

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Amount
              Text(
                '₦${_nairaFormat.format(amountNaira)}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusConfig['color'].withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusConfig['color'].withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusConfig['icon'] as IconData,
                      size: 14,
                      color: statusConfig['color'] as Color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusConfig['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusConfig['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bank details
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${withdrawal['account_number']} • ${withdrawal['account_name']}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                _dateFormat.format(createdAt),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          // Reference
          if (withdrawal['flutterwave_reference'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.tag_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  withdrawal['flutterwave_reference'] as String,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],

          // Cancel button
          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelWithdrawal(withdrawal['id']),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel Request',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ],

          // Failure reason
          if (status == 'failed' && withdrawal['failure_reason'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      withdrawal['failure_reason'] as String,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending_parent_approval':
        return {
          'label': 'Awaiting Parent',
          'color': const Color(0xFFFFB800),
          'icon': Icons.hourglass_top_rounded,
        };
      case 'pending_admin_approval':
        return {
          'label': 'Awaiting Admin',
          'color': const Color(0xFFFFB800),
          'icon': Icons.admin_panel_settings_rounded,
        };
      case 'approved':
        return {
          'label': 'Approved',
          'color': const Color(0xFF4F8EF7),
          'icon': Icons.check_circle_outline_rounded,
        };
      case 'processing':
        return {
          'label': 'Processing',
          'color': const Color(0xFF4F8EF7),
          'icon': Icons.sync_rounded,
        };
      case 'paid':
        return {
          'label': 'Completed',
          'color': AppColors.success,
          'icon': Icons.check_circle_rounded,
        };
      case 'failed':
        return {
          'label': 'Failed',
          'color': AppColors.error,
          'icon': Icons.error_rounded,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.grey,
          'icon': Icons.cancel_rounded,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline_rounded,
        };
    }
  }
}
