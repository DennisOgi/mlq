import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/lead_market_admin_service.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';

class LeadMarketFulfillmentScreen extends StatefulWidget {
  const LeadMarketFulfillmentScreen({super.key});

  @override
  State<LeadMarketFulfillmentScreen> createState() =>
      _LeadMarketFulfillmentScreenState();
}

class _LeadMarketFulfillmentScreenState extends State<LeadMarketFulfillmentScreen> {
  final _client = SupabaseService.instance.client;
  final _dateFmt = DateFormat('MMM d, y • HH:mm');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schools = [];
  String? _selectedSchoolId;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadSchoolsAndOrders();
  }

  Future<void> _loadSchoolsAndOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schools = await _client
          .from('schools')
          .select('id, name')
          .order('name', ascending: true);

      _schools = (schools as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      await _loadOrders();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadOrders() async {
    var q = _client.from('market_orders').select(
      'id, school_id, sponsor_id, status, verification_status, total_price_coins, '
      'coin_balance_before, coin_balance_after, pricing_context, created_at, '
      'profiles!market_orders_user_id_fkey(name, school_name), '
      'profiles!market_orders_verified_by_fkey(name), '
      'sponsors(name), '
      'market_order_items(quantity, unit_price_coins, total_price_coins, product_name, algorithm_version, market_products(name))',
    );

    if (_selectedSchoolId != null && _selectedSchoolId!.isNotEmpty) {
      q = q.eq('school_id', _selectedSchoolId!);
    }

    final res = await q.order('created_at', ascending: false).limit(100);
    _orders = (res as List).map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> _setVerification({
    required String orderId,
    required String status,
    required String verificationStatus,
  }) async {
    try {
      final ok = await LeadMarketAdminService.instance.updateOrderStatus(
        orderId: orderId,
        status: status,
        verificationStatus: verificationStatus,
      );
      if (!ok) throw Exception('Update rejected');

      await _loadOrders();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order updated and logged in audit trail'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lead Market Fulfillment'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: GoogleFonts.nunito(color: Colors.red),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedSchoolId,
                              decoration: const InputDecoration(
                                labelText: 'Filter by school',
                                filled: true,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('All schools'),
                                ),
                                ..._schools.map((s) => DropdownMenuItem(
                                      value: s['id']?.toString() ?? '',
                                      child: Text((s['name'] ?? '').toString()),
                                    )),
                              ],
                              onChanged: (val) async {
                                final v = (val ?? '').trim();
                                _selectedSchoolId = v.isEmpty ? null : v;
                                setState(() => _loading = true);
                                try {
                                  await _loadOrders();
                                  if (!mounted) return;
                                  setState(() => _loading = false);
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() {
                                    _loading = false;
                                    _error = e.toString();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _loadSchoolsAndOrders,
                            icon: const Icon(Icons.refresh),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) => _OrderCard(
                          order: _orders[idx],
                          dateFmt: _dateFmt,
                          onVerify: () => _setVerification(
                            orderId: _orders[idx]['id'].toString(),
                            status: 'verified',
                            verificationStatus: 'verified',
                          ),
                          onFulfill: () => _setVerification(
                            orderId: _orders[idx]['id'].toString(),
                            status: 'fulfilled',
                            verificationStatus: 'verified',
                          ),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final DateFormat dateFmt;
  final VoidCallback onVerify;
  final VoidCallback onFulfill;

  const _OrderCard({
    required this.order,
    required this.dateFmt,
    required this.onVerify,
    required this.onFulfill,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = order['created_at']?.toString();
    final createdText = createdAt != null
        ? dateFmt.format(DateTime.parse(createdAt).toLocal())
        : '';

    final profile = (order['profiles'] as Map?) ?? {};
    final verifiedBy = (order['profiles!market_orders_verified_by_fkey'] as Map?) ?? {};
    final studentName = (profile['name'] ?? 'Student').toString();
    final schoolName = (profile['school_name'] ?? '').toString();

    final sponsor = (order['sponsors'] as Map?) ?? {};
    final sponsorName = (sponsor['name'] ?? 'Sponsor').toString();

    final totalCoins = (order['total_price_coins'] as num?)?.toInt() ?? 0;
    final status = (order['status'] ?? 'placed').toString();
    final verification = (order['verification_status'] ?? 'unverified').toString();
    final orderId = (order['id'] ?? '').toString();
    final coinBefore = (order['coin_balance_before'] as num?)?.toDouble();
    final coinAfter = (order['coin_balance_after'] as num?)?.toDouble();

    final items = (order['market_order_items'] as List?) ?? const [];
    final verifierName = (verifiedBy['name'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  studentName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$totalCoins coins',
                style: GoogleFonts.nunito(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$schoolName • $sponsorName',
            style: GoogleFonts.nunito(color: Colors.white54, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            createdText,
            style: GoogleFonts.nunito(color: Colors.white38, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          if (orderId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Order ID: $orderId',
              style: GoogleFonts.nunito(
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
          if (coinBefore != null && coinAfter != null) ...[
            const SizedBox(height: 4),
            Text(
              'Coin audit: ${coinBefore.toStringAsFixed(0)} → ${coinAfter.toStringAsFixed(0)} (−$totalCoins)',
              style: GoogleFonts.nunito(
                color: Colors.amber.shade200,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Status: $status'),
              _pill('Verify: $verification'),
              _pill('Items: ${items.length}'),
              if (verifierName.isNotEmpty) _pill('By: $verifierName'),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...items.take(4).map((it) {
              final m = Map<String, dynamic>.from(it as Map);
              final p = (m['market_products'] as Map?) ?? {};
              final name =
                  (m['product_name'] ?? p['name'] ?? 'Item').toString();
              final qty = (m['quantity'] as num?)?.toInt() ?? 1;
              final unit = (m['unit_price_coins'] as num?)?.toInt();
              return Text(
                unit != null
                    ? '• $name × $qty @ $unit coins'
                    : '• $name × $qty',
                style: GoogleFonts.nunito(color: Colors.white70, fontWeight: FontWeight.w700),
              );
            }),
            if (items.length > 4)
              Text(
                '… +${items.length - 4} more',
                style: GoogleFonts.nunito(color: Colors.white54, fontWeight: FontWeight.w700),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: verification == 'verified' ? null : onVerify,
                  child: const Text('Verify'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: status == 'fulfilled' ? null : onFulfill,
                  child: const Text('Fulfilled'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  static Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

