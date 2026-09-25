import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/lead_market_admin_service.dart';
import '../../theme/app_colors.dart';

class LeadMarketEconomyScreen extends StatefulWidget {
  const LeadMarketEconomyScreen({super.key});

  @override
  State<LeadMarketEconomyScreen> createState() =>
      _LeadMarketEconomyScreenState();
}

class _LeadMarketEconomyScreenState extends State<LeadMarketEconomyScreen> {
  bool _loading = true;
  bool _repricing = false;
  MarketEconomyStats? _stats;
  MarketPricingExplainer? _explainer;
  List<MarketMedianSnapshot> _history = [];
  List<MarketProductPriceRow> _products = [];
  List<MarketRedemptionAuditRow> _redemptions = [];
  String? _error;

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
      final results = await Future.wait([
        LeadMarketAdminService.instance.fetchEconomyStats(),
        LeadMarketAdminService.instance.fetchPricingExplainer(),
        LeadMarketAdminService.instance.fetchMedianHistory(),
        LeadMarketAdminService.instance.fetchActiveProductPrices(),
        LeadMarketAdminService.instance.fetchRecentRedemptions(limit: 30),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as MarketEconomyStats;
        _explainer = results[1] as MarketPricingExplainer;
        _history = results[2] as List<MarketMedianSnapshot>;
        _products = results[3] as List<MarketProductPriceRow>;
        _redemptions = results[4] as List<MarketRedemptionAuditRow>;
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

  Future<void> _reprice() async {
    setState(() => _repricing = true);
    try {
      final count = await LeadMarketAdminService.instance.repriceAllProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Repriced $count product price snapshot(s)'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reprice failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _repricing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Coin Economy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildExplainCard(_explainer),
                      const SizedBox(height: 16),
                      _buildKpiGrid(_stats!),
                      const SizedBox(height: 16),
                      _buildRepriceCard(),
                      const SizedBox(height: 20),
                      _buildMedianChart(_history),
                      const SizedBox(height: 20),
                      _buildProductPrices(_products),
                      const SizedBox(height: 20),
                      _buildRedemptionLog(_redemptions),
                    ],
                  ),
                ),
    );
  }

  Widget _buildExplainCard(MarketPricingExplainer? explainer) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing system (${explainer?.algorithmVersion ?? 'v2-aspirational'})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              explainer != null
                  ? 'Wealth anchor: ${explainer.wealthAnchor.toStringAsFixed(0)} coins\n'
                    '${explainer.anchorFormula}\n'
                    'Price: ${explainer.priceFormula}\n'
                    'Repricing: ${explainer.repriceSchedule}'
                  : 'Lead Market prices float with the coin economy using an aspirational wealth anchor (not raw median alone).',
              style: const TextStyle(height: 1.45, color: Colors.black87),
            ),
            if (explainer != null && explainer.kindFloors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Category minimum floors',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: explainer.kindFloors.entries.map((e) {
                  return Chip(
                    label: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(MarketEconomyStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _KpiTile(
          label: 'Wealth anchor',
          value: stats.wealthAnchor.toStringAsFixed(0),
          subtitle: stats.algorithmVersion,
          icon: Icons.anchor_rounded,
          color: Colors.deepOrange,
        ),
        _KpiTile(
          label: 'Median coins',
          value: stats.coinsMedian.toStringAsFixed(0),
          icon: Icons.trending_flat_rounded,
          color: AppColors.primary,
        ),
        _KpiTile(
          label: 'Average coins',
          value: stats.coinsAvg.toStringAsFixed(0),
          icon: Icons.analytics_outlined,
          color: Colors.teal,
        ),
        _KpiTile(
          label: 'P75 balance',
          value: stats.coinsP75.toStringAsFixed(0),
          icon: Icons.stacked_line_chart_rounded,
          color: Colors.indigo,
        ),
        _KpiTile(
          label: 'Purchasing power',
          value: stats.purchasingPowerIndex.toStringAsFixed(2),
          subtitle: 'median ÷ 1000',
          icon: Icons.speed_rounded,
          color: Colors.orange,
        ),
        _KpiTile(
          label: 'Students tracked',
          value: '${stats.userCount}',
          icon: Icons.people_outline,
          color: Colors.blueGrey,
        ),
        _KpiTile(
          label: 'Redemptions (30d)',
          value: '${stats.redemptions30d}',
          icon: Icons.redeem_rounded,
          color: Colors.green.shade700,
        ),
        _KpiTile(
          label: 'Orders (30d)',
          value: '${stats.orders30d}',
          icon: Icons.receipt_long_outlined,
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildRepriceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reprice all active products',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_stats?.activeProducts ?? 0} active products use dynamic pricing',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _repricing ? null : _reprice,
              icon: _repricing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew_rounded),
              label: Text(_repricing ? 'Updating…' : 'Reprice now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedianChart(List<MarketMedianSnapshot> history) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coin economy & price snapshots',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              history.isEmpty
                  ? 'No snapshots yet — run Reprice now after products exist.'
                  : '${history.length} day(s) of snapshot data',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        'Chart appears after the first global reprice',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : LineChart(_medianChartData(history)),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _medianChartData(List<MarketMedianSnapshot> history) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.coinsMedian))
        .toList();
    final maxY = history
        .map((h) => h.coinsMedian)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: history.length > 6 ? (history.length / 4).ceilToDouble() : 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= history.length) return const SizedBox.shrink();
              return Text(
                DateFormat.Md().format(history[i].day),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY <= 0 ? 100 : maxY * 1.15,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildRedemptionLog(List<MarketRedemptionAuditRow> rows) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Redemption audit log',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Immutable server-side record of every purchase and admin action.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('No redemptions logged yet.')
            else
              ...rows.take(20).map((r) {
                final when = r.createdAt != null
                    ? DateFormat('MMM d HH:mm').format(r.createdAt!.toLocal())
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${r.studentName ?? 'Student'} · ${r.productName ?? r.eventType}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              r.eventType,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (when.isNotEmpty) when,
                          if (r.totalPriceCoins != null)
                            '${r.totalPriceCoins} coins',
                          if (r.coinBalanceBefore != null &&
                              r.coinBalanceAfter != null)
                            'balance ${r.coinBalanceBefore!.toStringAsFixed(0)} → ${r.coinBalanceAfter!.toStringAsFixed(0)}',
                          if (r.orderId != null)
                            'order ${r.orderId!.substring(0, 8)}…',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPrices(List<MarketProductPriceRow> products) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current product prices',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const Text('No active products in the market yet.')
            else
              ...products.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${p.sponsorName} · ${p.productKind} · weight ${p.valueWeight.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${p.priceCoins} coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _KpiTile({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }
}
