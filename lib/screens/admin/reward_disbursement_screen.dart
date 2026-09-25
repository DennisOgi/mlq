import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/wallet_service.dart';
import 'admin_withdrawal_screen.dart';

class RewardDisbursementScreen extends StatefulWidget {
  /// 0 = rewards, 1 = withdrawals, 2 = history
  final int initialTabIndex;

  const RewardDisbursementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<RewardDisbursementScreen> createState() =>
      _RewardDisbursementScreenState();
}

class _RewardDisbursementScreenState extends State<RewardDisbursementScreen>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');

  bool _isLoading = true;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _history = [];
  int _pendingWithdrawalCount = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialTab = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _walletService.getPendingDisbursements(),
      _walletService.getDisbursementHistory(),
      _walletService.getPendingWithdrawalsAdmin(),
    ]);
    if (!mounted) return;
    final withdrawals = results[2] as List<Map<String, dynamic>>;
    final actionableWithdrawals = withdrawals
        .where((row) =>
            row['status']?.toString() == 'pending_admin_approval' ||
            row['status']?.toString() == 'approved')
        .length;
    setState(() {
      _pending = results[0];
      _history = results[1];
      _pendingWithdrawalCount = actionableWithdrawals;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'LeadWallet Payouts',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A2E)),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showCreateDisbursementSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E096), Color(0xFF00B273)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Issue Reward',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Rewards '),
                  if (_pending.isNotEmpty)
                    _tabBadge('${_pending.length}'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Withdrawals '),
                  if (_pendingWithdrawalCount > 0)
                    _tabBadge('$_pendingWithdrawalCount'),
                ],
              ),
            ),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(),
                const AdminWithdrawalScreen(embedded: true),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _tabBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  // ─── Pending Tab ──────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'All caught up!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            Text(
              'No pending reward approvals',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Colors.grey.shade500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showCreateDisbursementSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Issue a Reward',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        itemBuilder: (_, i) => _buildPendingCard(_pending[i], i),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item, int index) {
    final name = item['profiles']?['name'] ?? 'Unknown Student';
    final school = item['profiles']?['school_name'] ?? '';
    final amount = (item['amount'] as num).toDouble();
    final reason = item['reason'] as String;
    final id = item['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar placeholder
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.8),
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      if (school.isNotEmpty)
                        Text(
                          school,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FBF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF00B273)],
                      ).createShader(bounds),
                      child: Text(
                        '₦${_nairaFormat.format(amount)}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                // Reject
                Expanded(
                  child: GestureDetector(
                    onTap: () => _rejectDisbursement(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded, color: Colors.red, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Reject',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Approve
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isProcessing
                        ? null
                        : () => _approveDisbursement(
                              id,
                              name,
                              amount,
                              item['student_id']?.toString(),
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E096), Color(0xFF00B273)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _isProcessing
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Approve & Credit',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 80).ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  // ─── History Tab ───────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'No disbursement history yet',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Completed rewards will appear here',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final name = item['student_name']?.toString() ?? 'Unknown Student';
    final school = item['school_name']?.toString() ?? '';
    final amount = (item['amount'] as num).toDouble();
    final reason = item['reason']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final createdAt = item['disbursed_at'] ?? item['created_at'];
    final dateLabel = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(createdAt.toString()).toLocal())
        : '';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
      case 'failed':
        statusColor = AppColors.error;
      case 'rejected':
        statusColor = Colors.orange;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (school.isNotEmpty)
                      Text(
                        school,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '₦${_nairaFormat.format(amount)}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF00B273),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reason,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (dateLabel.isNotEmpty)
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────

  Future<void> _approveDisbursement(
    String id,
    String name,
    double amount,
    String? studentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Reward?',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: Text(
          'Credit ₦${_nairaFormat.format(amount)} to $name\'s LeadWallet?',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final admin = Provider.of<UserProvider>(context, listen: false).user;

    final success = await _walletService.approveAndProcessDisbursement(
      disbursementId: id,
      adminId: admin?.id ?? '',
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ ₦${_nairaFormat.format(amount)} credited to $name!'
              : '❌ Failed to process. Please try again.',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (success) {
      await _loadData();
      final currentUserId =
          Provider.of<UserProvider>(context, listen: false).user?.id;
      if (currentUserId != null &&
          studentId != null &&
          currentUserId == studentId) {
        await Provider.of<UserProvider>(context, listen: false).refreshUser();
      }
    }
  }

  Future<void> _rejectDisbursement(String id) async {
    // For Phase 1, simply mark as rejected in the DB
    await _walletService.rejectDisbursement(id);
    _loadData();
  }

  // ─── Create Disbursement Sheet ────────────────────────────────────────

  void _showCreateDisbursementSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IssueRewardSheet(
        walletService: _walletService,
        nairaFormat: _nairaFormat,
        adminId:
            Provider.of<UserProvider>(context, listen: false).user?.id ?? '',
        onCreated: () {
          if (mounted) _loadData();
        },
        onWalletCredited: (studentId) async {
          final currentUserId =
              Provider.of<UserProvider>(context, listen: false).user?.id;
          if (currentUserId != null && currentUserId == studentId) {
            await Provider.of<UserProvider>(context, listen: false).refreshUser();
          }
        },
      ),
    );
  }
}

class _IssueRewardSheet extends StatefulWidget {
  const _IssueRewardSheet({
    required this.walletService,
    required this.nairaFormat,
    required this.adminId,
    required this.onCreated,
    required this.onWalletCredited,
  });

  final WalletService walletService;
  final NumberFormat nairaFormat;
  final String adminId;
  final VoidCallback onCreated;
  final Future<void> Function(String studentId) onWalletCredited;

  @override
  State<_IssueRewardSheet> createState() => _IssueRewardSheetState();
}

class _IssueRewardSheetState extends State<_IssueRewardSheet> {
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedStudent;
  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _searchHint;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_scheduleSearch);
    _schoolController.addListener(_scheduleSearch);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _schoolController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final name = _nameController.text.trim();
    final school = _schoolController.text.trim();

    if (name.length < 2 && school.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searchHint = 'Type at least 2 characters of a name or school to search';
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchHint = null;
    });

    final results = await widget.walletService.searchStudentsForReward(
      nameQuery: name,
      schoolQuery: school,
    );

    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
      _searchHint = results.isEmpty
          ? 'No students found. Try a different name or school.'
          : null;
    });
  }

  Future<void> _submit() async {
    final studentId = _selectedStudent?['id']?.toString();
    final amount = double.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();

    if (studentId == null || studentId.isEmpty) {
      _showMessage('Please select a student from the search results');
      return;
    }
    if (amount == null || amount <= 0 || reason.isEmpty) {
      _showMessage('Please enter a valid amount and reason');
      return;
    }

    setState(() => _isSubmitting = true);
    final studentName = _selectedStudent?['name']?.toString() ?? 'student';
    final result = await widget.walletService.issueRewardDirectly(
      studentId: studentId,
      amount: amount,
      reason: reason,
      adminId: widget.adminId,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pop(context);
    final success = result['success'] == true;
    _showMessage(
      success
          ? '₦${widget.nairaFormat.format(amount)} credited to $studentName\'s LeadWallet'
          : (result['error']?.toString() ?? 'Failed to issue reward'),
      isError: !success,
    );
    if (success) {
      await widget.onWalletCredited(studentId);
      widget.onCreated();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issue a Reward',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Search for a student and credit their LeadWallet immediately.',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSearchField(
                      controller: _nameController,
                      label: 'Student name',
                      hint: 'e.g. Tobi',
                      icon: Icons.person_search_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildSearchField(
                      controller: _schoolController,
                      label: 'School (optional filter)',
                      hint: 'e.g. Pearls Garden',
                      icon: Icons.school_rounded,
                    ),
                    const SizedBox(height: 12),
                    if (_selectedStudent != null) ...[
                      _buildSelectedStudentCard(),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildSearchResults(),
                      const SizedBox(height: 16),
                    ],
                    _buildFormField(
                      controller: _amountController,
                      label: 'Reward amount (₦)',
                      hint: 'e.g. 500',
                      icon: Icons.payments_rounded,
                      isNumber: true,
                      prefix: '₦  ',
                    ),
                    const SizedBox(height: 14),
                    _buildFormField(
                      controller: _reasonController,
                      label: 'Reason',
                      hint: 'e.g. Won the Leadership Challenge',
                      icon: Icons.description_rounded,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Issuing…' : 'Issue Reward',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchHint != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          _searchHint!,
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      );
    }

    return Column(
      children: _results
          .map((student) => _buildStudentResultTile(student))
          .toList(),
    );
  }

  Widget _buildStudentResultTile(Map<String, dynamic> student) {
    final name = student['name']?.toString() ?? 'Unknown';
    final school = student['school_name']?.toString() ?? 'No school listed';
    final walletStatus = student['wallet_status']?.toString() ?? 'inactive';
    final balance =
        (student['wallet_balance'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedStudent = student;
            _results = [];
          });
        },
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              school,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(
                  walletStatus == 'active' ? 'Wallet active' : 'Wallet inactive',
                  walletStatus == 'active' ? AppColors.success : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  '₦${widget.nairaFormat.format(balance)}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.add_circle_outline_rounded,
            color: AppColors.primary),
      ),
    );
  }

  Widget _buildSelectedStudentCard() {
    final student = _selectedStudent!;
    final name = student['name']?.toString() ?? 'Unknown';
    final school = student['school_name']?.toString() ?? 'No school listed';
    final walletStatus = student['wallet_status']?.toString() ?? 'inactive';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected student',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  school,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusChip(
                  walletStatus == 'active'
                      ? 'LeadWallet active'
                      : 'LeadWallet inactive',
                  walletStatus == 'active' ? AppColors.success : Colors.orange,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedStudent = null),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Change student',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        labelStyle: TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixStyle:
            TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        labelStyle: TextStyle(color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600),
    );
  }
}
