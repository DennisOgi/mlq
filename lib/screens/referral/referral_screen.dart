import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/referral_service.dart';
import 'package:my_leadership_quest/widgets/quest_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Invite & Earn — personal referral code; payout when invitee buys Monthly/Quarterly.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _service = ReferralService();
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  String? _code;
  int _invited = 0;
  int _rewarded = 0;
  num _earned = 0;
  num _pending = 0;
  bool _hasApplied = false;
  String? _error;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _service.ensureMyCode();
    // If invite link left a pending code and user is already signed in, apply it.
    await _service.tryApplyPendingCode();
    final pending = await _service.getPendingCode();
    final stats = await _service.getStats();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (pending != null && _codeController.text.isEmpty) {
        _codeController.text = pending;
      }
      if (stats['success'] == true) {
        _code = stats['code']?.toString();
        _invited = (stats['invited_count'] as num?)?.toInt() ?? 0;
        _rewarded = (stats['rewarded_count'] as num?)?.toInt() ?? 0;
        _earned = stats['earned_naira'] as num? ?? 0;
        _pending = stats['pending_naira'] as num? ?? 0;
        _hasApplied = stats['has_applied_code'] == true;
      } else {
        _error = stats['error']?.toString() ?? 'Could not load referral info';
      }
    });
  }

  Future<void> _copyCode() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _shareCode() async {
    if (_code == null) return;
    final message = _service.shareMessage(_code!);
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite message copied')),
      );
    }
  }

  Future<void> _applyFriendCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _applying = true);
    final result = await _service.applyCode(code);
    if (!mounted) return;
    setState(() => _applying = false);

    final ok = result['success'] == true;
    final err = result['error']?.toString();
    String msg;
    if (ok) {
      msg = 'Invite code applied! Your friend earns when you subscribe.';
      _codeController.clear();
      await _load();
    } else {
      msg = switch (err) {
        'self_referral' => 'You cannot use your own code.',
        'already_attributed' => 'You already applied an invite code.',
        'invalid_or_inactive_code' => 'That code is invalid or inactive.',
        'invalid_code' => 'Please enter a valid invite code.',
        'profile_not_ready' => 'Account is still setting up. Try again in a moment.',
        'not_authenticated' => 'Please sign in first, then apply the code.',
        _ => err ?? 'Could not apply code',
      };
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0820),
        title: const Text(
          'Invite & Earn',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0820),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share your code',
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When a friend buys Monthly (₦500 reward) or Quarterly (₦1,000), cash lands in your LeadWallet.',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD700)),
                          ),
                          child: Text(
                            _code ?? '—',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: QuestButton(
                                text: 'Copy',
                                type: QuestButtonType.outline,
                                onPressed: _copyCode,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: QuestButton(
                                text: 'Share',
                                type: QuestButtonType.primary,
                                onPressed: _shareCode,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _statRow('Friends invited', '$_invited'),
                  _statRow('Rewards paid', '$_rewarded'),
                  _statRow('Earned', '₦${_formatMoney(_earned)}'),
                  if (_pending > 0)
                    _statRow(
                      'Pending (activate LeadWallet)',
                      '₦${_formatMoney(_pending)}',
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'This is separate from school class codes.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (!_hasApplied) ...[
                    const SizedBox(height: 28),
                    Text('Have a friend’s code?', style: AppTextStyles.heading3),
                    const SizedBox(height: 8),
                    Text(
                      'Enter it once. They earn only if you subscribe to Monthly or Quarterly.',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'MLQ-XXXXXX',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    QuestButton(
                      text: _applying ? 'Applying…' : 'Apply invite code',
                      type: QuestButtonType.primary,
                      onPressed: _applying ? null : _applyFriendCode,
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Text(
                      'You already applied a friend’s invite code.',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: AppColors.error)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _formatMoney(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }
}
