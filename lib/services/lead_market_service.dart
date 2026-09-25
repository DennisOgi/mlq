import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:my_leadership_quest/utils/lead_market_branding.dart';

class SponsorStorefront {
  final String id;
  final String name;
  final String? logoUrl;
  final String? bannerUrl;
  final String? description;
  final String? themePrimaryColor;
  final String? themeSecondaryColor;
  final int activeProductCount;
  final bool showWhenEmpty;

  SponsorStorefront({
    required this.id,
    required this.name,
    this.logoUrl,
    this.bannerUrl,
    this.description,
    this.themePrimaryColor,
    this.themeSecondaryColor,
    this.activeProductCount = 0,
    this.showWhenEmpty = false,
  });

  factory SponsorStorefront.fromJson(
    Map<String, dynamic> json, {
    int activeProductCount = 0,
  }) {
    return SponsorStorefront(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      description: json['description']?.toString(),
      themePrimaryColor: json['theme_primary_color']?.toString(),
      themeSecondaryColor: json['theme_secondary_color']?.toString(),
      activeProductCount: activeProductCount,
      showWhenEmpty: json['show_when_empty'] == true,
    );
  }
}

class LeadMarketProduct {
  final String id;
  final String sponsorId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String productKind;
  final double valueWeight;
  final String status;
  final int stockAvailable;
  final int priceCoins;

  LeadMarketProduct({
    required this.id,
    required this.sponsorId,
    required this.name,
    this.description,
    this.imageUrl,
    this.productKind = 'unknown',
    this.valueWeight = 1.0,
    required this.status,
    required this.stockAvailable,
    required this.priceCoins,
  });

  factory LeadMarketProduct.fromJson(Map<String, dynamic> json) {
    return LeadMarketProduct(
      id: (json['id'] ?? '').toString(),
      sponsorId: (json['sponsor_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      productKind: (json['product_kind'] ?? 'unknown').toString(),
      valueWeight: (json['value_weight'] as num?)?.toDouble() ?? 1.0,
      status: (json['status'] ?? 'active').toString(),
      stockAvailable: (json['stock_available'] as num?)?.toInt() ?? 0,
      priceCoins: (json['price_coins'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeadMarketService {
  static final LeadMarketService _instance = LeadMarketService._internal();
  factory LeadMarketService() => _instance;
  LeadMarketService._internal();

  final SupabaseClient _client = SupabaseService.instance.client;

  Future<List<SponsorStorefront>> listSponsors() async {
    final res = await _client
        .from('sponsors')
        .select(
          'id, name, logo_url, banner_url, description, theme_primary_color, theme_secondary_color, show_when_empty',
        )
        .order('name', ascending: true);

    final productRows = await _client
        .from('market_products')
        .select('sponsor_id')
        .eq('status', 'active');
    final productCounts = <String, int>{};
    for (final row in productRows as List) {
      final sponsorId = (row as Map)['sponsor_id']?.toString();
      if (sponsorId == null || sponsorId.isEmpty) continue;
      productCounts[sponsorId] = (productCounts[sponsorId] ?? 0) + 1;
    }

    final sponsors = (res as List)
        .map((r) {
          final data = Map<String, dynamic>.from(r);
          final id = (data['id'] ?? '').toString();
          return SponsorStorefront.fromJson(
            data,
            activeProductCount: productCounts[id] ?? 0,
          );
        })
        .where(
          (sponsor) => sponsor.activeProductCount > 0 || sponsor.showWhenEmpty,
        )
        .toList();

    sponsors.sort((a, b) {
      if (a.id == kMlqFoundationSponsorId) return -1;
      if (b.id == kMlqFoundationSponsorId) return 1;
      return a.name.compareTo(b.name);
    });
    return sponsors;
  }

  Future<Map<String, dynamic>> updateStorefrontBranding({
    required String sponsorId,
    String? logoUrl,
    String? bannerUrl,
    String? themePrimaryColor,
    String? themeSecondaryColor,
    String? description,
  }) async {
    try {
      final result = await _client.rpc(
        'sponsor_update_storefront',
        params: {
          'p_sponsor_id': sponsorId,
          if (logoUrl != null) 'p_logo_url': logoUrl,
          if (bannerUrl != null) 'p_banner_url': bannerUrl,
          if (themePrimaryColor != null) 'p_theme_primary_color': themePrimaryColor,
          if (themeSecondaryColor != null) 'p_theme_secondary_color': themeSecondaryColor,
          if (description != null) 'p_description': description,
        },
      );
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'ok': false, 'error': 'unexpected_response'};
    } catch (e) {
      debugPrint('LeadMarket branding update error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<List<LeadMarketProduct>> listProductsForSponsor(String sponsorId) async {
    final res = await _client
        .from('market_products')
        .select('id, sponsor_id, name, description, image_url, product_kind, value_weight, status, stock_available, price_coins')
        .eq('sponsor_id', sponsorId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (res as List)
        .map((r) => LeadMarketProduct.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Map<String, dynamic>> purchaseProduct({
    required String productId,
    int quantity = 1,
  }) async {
    try {
      final result = await _client.rpc(
        'market_purchase_product',
        params: {
          'p_product_id': productId,
          'p_quantity': quantity,
        },
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('LeadMarket purchase error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> listMyOrders({int limit = 30}) async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) return [];

    final res = await _client
        .from('market_orders')
        .select('id, sponsor_id, status, verification_status, total_price_coins, coin_balance_before, coin_balance_after, created_at, market_order_items(quantity, unit_price_coins, total_price_coins, product_name, market_products(name, image_url))')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (res as List).map((r) => Map<String, dynamic>.from(r)).toList();
  }
}

