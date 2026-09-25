import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/lead_market_service.dart';

class MyMarketOrdersScreen extends StatefulWidget {
  const MyMarketOrdersScreen({super.key});

  @override
  State<MyMarketOrdersScreen> createState() => _MyMarketOrdersScreenState();
}

class _MyMarketOrdersScreenState extends State<MyMarketOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _error;

  final _dateFmt = DateFormat('MMM d, y • HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await LeadMarketService().listMyOrders(limit: 40);
      if (!mounted) return;
      setState(() {
        _orders = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAF7),
      appBar: AppBar(
        title: const Text('My Purchases'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _MessageList(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load purchases',
                    message: _error!,
                    actionLabel: 'Try again',
                    onAction: _load,
                  )
                : _orders.isEmpty
                    ? const _MessageList(
                        icon: Icons.receipt_long_outlined,
                        title: 'No purchases yet',
                        message:
                            'Redeemed gifts will appear here with fulfilment and verification updates.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _orders.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) {
                          if (idx == 0) {
                            return _HistoryHeader(orderCount: _orders.length);
                          }
                          final order = _orders[idx - 1];
                          return _OrderCard(
                            order: order,
                            dateFmt: _dateFmt,
                            index: idx - 1,
                          );
                        },
                      ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int orderCount;
  const _HistoryHeader({required this.orderCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A0050), Color(0xFF9D0389)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase History',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  orderCount == 1
                      ? '1 redemption being tracked'
                      : '$orderCount redemptions being tracked',
                  style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final DateFormat dateFmt;
  final int index;

  const _OrderCard({
    required this.order,
    required this.dateFmt,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final total = (order['total_price_coins'] as num?)?.toInt() ?? 0;
    final orderId = (order['id'] ?? '').toString();
    final status = (order['status'] ?? 'placed').toString();
    final verification =
        (order['verification_status'] ?? 'unverified').toString();
    final createdAt = order['created_at']?.toString();
    final dateText = createdAt != null
        ? dateFmt.format(DateTime.parse(createdAt).toLocal())
        : '';

    final items = (order['market_order_items'] as List?) ?? const [];
    final firstItem = items.isNotEmpty ? (items.first as Map) : const {};
    final product = (firstItem['market_products'] as Map?) ?? {};
    final productName =
        (firstItem['product_name'] ?? product['name'] ?? 'Lead Market gift')
            .toString();
    final imageUrl = product['image_url']?.toString();
    final quantity = (firstItem['quantity'] as num?)?.toInt() ?? 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderImage(imageUrl: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  dateText,
                  style: GoogleFonts.nunito(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (orderId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Ref: ${orderId.substring(0, 8)}…',
                    style: GoogleFonts.nunito(
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.monetization_on_rounded,
                      text: '$total coins',
                      color: const Color(0xFF8A6400),
                      background: const Color(0xFFFFF7DB),
                    ),
                    _InfoPill(
                      icon: Icons.inventory_2_outlined,
                      text: 'Qty $quantity',
                      color: AppColors.textSecondary,
                      background: const Color(0xFFF7F7FA),
                    ),
                    _InfoPill(
                      icon: Icons.verified_user_outlined,
                      text: verification,
                      color: _verificationColor(verification),
                      background: _verificationColor(verification).withOpacity(0.10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 280.ms, delay: (index * 45).ms).slideY(begin: 0.04);
  }
}

class _OrderImage extends StatelessWidget {
  final String? imageUrl;
  const _OrderImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 62,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl!,
        width: 62,
        height: 74,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: GoogleFonts.nunito(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.nunito(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MessageList({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 44),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => onAction!(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        )
      ],
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'fulfilled':
      return Colors.green.shade700;
    case 'verified':
      return Colors.blue.shade700;
    case 'cancelled':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}

Color _verificationColor(String status) {
  switch (status) {
    case 'verified':
      return Colors.green.shade700;
    case 'rejected':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}
