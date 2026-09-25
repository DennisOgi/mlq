import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';

class MarketEconomyStats {
  final int userCount;
  final double coinsMedian;
  final double coinsP75;
  final double coinsAvg;
  final double wealthAnchor;
  final int activeProducts;
  final int orders30d;
  final int redemptions30d;
  final double purchasingPowerIndex;
  final String algorithmVersion;

  const MarketEconomyStats({
    required this.userCount,
    required this.coinsMedian,
    required this.coinsP75,
    required this.coinsAvg,
    required this.wealthAnchor,
    required this.activeProducts,
    required this.orders30d,
    required this.redemptions30d,
    required this.purchasingPowerIndex,
    required this.algorithmVersion,
  });

  factory MarketEconomyStats.fromJson(Map<String, dynamic> json) {
    return MarketEconomyStats(
      userCount: (json['user_count'] as num?)?.toInt() ?? 0,
      coinsMedian: (json['coins_median'] as num?)?.toDouble() ?? 0,
      coinsP75: (json['coins_p75'] as num?)?.toDouble() ?? 0,
      coinsAvg: (json['coins_avg'] as num?)?.toDouble() ?? 0,
      wealthAnchor: (json['wealth_anchor'] as num?)?.toDouble() ?? 0,
      activeProducts: (json['active_products'] as num?)?.toInt() ?? 0,
      orders30d: (json['orders_30d'] as num?)?.toInt() ?? 0,
      redemptions30d: (json['redemptions_30d'] as num?)?.toInt() ?? 0,
      purchasingPowerIndex:
          (json['purchasing_power_index'] as num?)?.toDouble() ?? 0,
      algorithmVersion:
          (json['algorithm_version'] ?? 'v2-aspirational').toString(),
    );
  }
}

class MarketPricingExplainer {
  final String algorithmVersion;
  final double wealthAnchor;
  final double coinsMedian;
  final double coinsP75;
  final double coinsAvg;
  final String anchorFormula;
  final String priceFormula;
  final double multiplier;
  final Map<String, int> kindFloors;
  final String repriceSchedule;

  MarketPricingExplainer({
    required this.algorithmVersion,
    required this.wealthAnchor,
    required this.coinsMedian,
    required this.coinsP75,
    required this.coinsAvg,
    required this.anchorFormula,
    required this.priceFormula,
    required this.multiplier,
    required this.kindFloors,
    required this.repriceSchedule,
  });

  factory MarketPricingExplainer.fromJson(Map<String, dynamic> json) {
    final floorsRaw = json['kind_floors'];
    final floors = <String, int>{};
    if (floorsRaw is Map) {
      floorsRaw.forEach((k, v) {
        floors[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return MarketPricingExplainer(
      algorithmVersion: (json['algorithm_version'] ?? '').toString(),
      wealthAnchor: (json['wealth_anchor'] as num?)?.toDouble() ?? 0,
      coinsMedian: (json['coins_median'] as num?)?.toDouble() ?? 0,
      coinsP75: (json['coins_p75'] as num?)?.toDouble() ?? 0,
      coinsAvg: (json['coins_avg'] as num?)?.toDouble() ?? 0,
      anchorFormula: (json['anchor_formula'] ?? '').toString(),
      priceFormula: (json['price_formula'] ?? '').toString(),
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 0.4,
      kindFloors: floors,
      repriceSchedule: (json['reprice_schedule'] ?? '').toString(),
    );
  }
}

class MarketMedianSnapshot {
  final DateTime day;
  final double coinsMedian;
  final double coinsAvg;
  final String? algorithmVersion;

  MarketMedianSnapshot({
    required this.day,
    required this.coinsMedian,
    required this.coinsAvg,
    this.algorithmVersion,
  });
}

class MarketProductPriceRow {
  final String productName;
  final String sponsorName;
  final int priceCoins;
  final double valueWeight;
  final String productKind;
  final DateTime? lastPricedAt;

  MarketProductPriceRow({
    required this.productName,
    required this.sponsorName,
    required this.priceCoins,
    required this.valueWeight,
    required this.productKind,
    this.lastPricedAt,
  });
}

class MarketRedemptionAuditRow {
  final String auditId;
  final String? orderId;
  final String eventType;
  final String? studentName;
  final String? schoolName;
  final String? sponsorName;
  final String? productName;
  final int? quantity;
  final int? unitPriceCoins;
  final int? totalPriceCoins;
  final double? coinBalanceBefore;
  final double? coinBalanceAfter;
  final String? algorithmVersion;
  final DateTime? createdAt;

  MarketRedemptionAuditRow({
    required this.auditId,
    this.orderId,
    required this.eventType,
    this.studentName,
    this.schoolName,
    this.sponsorName,
    this.productName,
    this.quantity,
    this.unitPriceCoins,
    this.totalPriceCoins,
    this.coinBalanceBefore,
    this.coinBalanceAfter,
    this.algorithmVersion,
    this.createdAt,
  });

  factory MarketRedemptionAuditRow.fromJson(Map<String, dynamic> json) {
    return MarketRedemptionAuditRow(
      auditId: (json['audit_id'] ?? '').toString(),
      orderId: json['order_id']?.toString(),
      eventType: (json['event_type'] ?? '').toString(),
      studentName: json['student_name']?.toString(),
      schoolName: json['school_name']?.toString(),
      sponsorName: json['sponsor_name']?.toString(),
      productName: json['product_name']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
      unitPriceCoins: (json['unit_price_coins'] as num?)?.toInt(),
      totalPriceCoins: (json['total_price_coins'] as num?)?.toInt(),
      coinBalanceBefore: (json['coin_balance_before'] as num?)?.toDouble(),
      coinBalanceAfter: (json['coin_balance_after'] as num?)?.toDouble(),
      algorithmVersion: json['algorithm_version']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class LeadMarketAdminService {
  LeadMarketAdminService._();
  static final LeadMarketAdminService instance = LeadMarketAdminService._();

  final SupabaseClient _client = SupabaseService.instance.client;

  Future<MarketEconomyStats> fetchEconomyStats() async {
    final result = await _client.rpc('admin_market_get_economy_stats');
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return MarketEconomyStats.fromJson(map);
  }

  Future<MarketPricingExplainer> fetchPricingExplainer() async {
    final result = await _client.rpc('admin_market_get_pricing_explainer');
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return MarketPricingExplainer.fromJson(map);
  }

  Future<List<MarketRedemptionAuditRow>> fetchRecentRedemptions(
      {int limit = 40}) async {
    final result =
        await _client.rpc('admin_market_list_redemptions', params: {
      'p_limit': limit,
    });
    if (result is! List) return [];
    return result
        .map((r) => MarketRedemptionAuditRow.fromJson(
            Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<int> repriceAllProducts() async {
    final result = await _client.rpc('admin_market_reprice_now');
    return (result as num?)?.toInt() ?? 0;
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    required String verificationStatus,
    String? notes,
  }) async {
    final result = await _client.rpc('admin_market_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_verification_status': verificationStatus,
      if (notes != null) 'p_notes': notes,
    });
    if (result is Map) {
      return result['success'] == true;
    }
    return false;
  }

  Future<List<MarketMedianSnapshot>> fetchMedianHistory({int days = 30}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await _client
        .from('market_price_snapshots')
        .select('created_at, coins_median, coins_avg, algorithm_version')
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: true);

    final byDay = <String, MarketMedianSnapshot>{};
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row);
      final created = DateTime.parse(map['created_at'].toString()).toUtc();
      final key =
          '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      byDay[key] = MarketMedianSnapshot(
        day: DateTime(created.year, created.month, created.day),
        coinsMedian: (map['coins_median'] as num?)?.toDouble() ?? 0,
        coinsAvg: (map['coins_avg'] as num?)?.toDouble() ?? 0,
        algorithmVersion: map['algorithm_version']?.toString(),
      );
    }
    return byDay.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  Future<List<MarketProductPriceRow>> fetchActiveProductPrices() async {
    final rows = await _client
        .from('market_products')
        .select(
          'name, price_coins, value_weight, product_kind, updated_at, sponsors(name)',
        )
        .eq('status', 'active')
        .order('price_coins', ascending: false);

    return (rows as List).map((r) {
      final map = Map<String, dynamic>.from(r);
      final sponsor = map['sponsors'] as Map?;
      return MarketProductPriceRow(
        productName: (map['name'] ?? '').toString(),
        sponsorName: (sponsor?['name'] ?? 'Unknown').toString(),
        priceCoins: (map['price_coins'] as num?)?.toInt() ?? 0,
        valueWeight: (map['value_weight'] as num?)?.toDouble() ?? 1,
        productKind: (map['product_kind'] ?? 'unknown').toString(),
        lastPricedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'].toString())
            : null,
      );
    }).toList();
  }
}
