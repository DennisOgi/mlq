import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/providers/user_provider.dart';
import 'package:my_leadership_quest/services/lead_market_service.dart';
import 'package:my_leadership_quest/utils/lead_market_branding.dart';
import 'package:provider/provider.dart';

class SponsorShopScreen extends StatefulWidget {
  final SponsorStorefront sponsor;

  const SponsorShopScreen({super.key, required this.sponsor});

  @override
  State<SponsorShopScreen> createState() => _SponsorShopScreenState();
}

class _SponsorShopScreenState extends State<SponsorShopScreen> {
  bool _loading = true;
  bool _purchasing = false;
  List<LeadMarketProduct> _products = [];
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
      final items =
          await LeadMarketService().listProductsForSponsor(widget.sponsor.id);
      if (!mounted) return;
      setState(() {
        _products = items;
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

  Future<void> _buy(LeadMarketProduct product) async {
    if (product.stockAvailable <= 0 || _purchasing) return;

    // Pre-check: show a clear message if user cannot afford the gift
    final coins =
        context.read<UserProvider>().user?.coins ?? 0;
    if (coins < product.priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need ${product.priceCoins} coins but only have ${coins.toStringAsFixed(0)}. '
            'Earn more coins by completing goals, challenges, and mini-courses.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _PurchaseSheet(product: product, currentCoins: coins),
    );

    if (confirm != true || !mounted) return;

    final userProvider = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _purchasing = true);
    final res = await LeadMarketService().purchaseProduct(productId: product.id);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (res['success'] == true) {
      await userProvider.refreshUser();
      if (!mounted) return;
      final orderId = res['order_id']?.toString();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            orderId != null
                ? '🎁 Redemption logged! Order ${orderId.substring(0, 8)}… — check My Purchases.'
                : '🎁 Purchase placed! Check My Purchases for fulfilment status.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      _load();
    } else {
      final rawError = res['error']?.toString() ?? '';
      final friendlyError = _friendlyPurchaseError(rawError);
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _friendlyPurchaseError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient') || lower.contains('not enough coins') || lower.contains('balance')) {
      return 'Not enough coins to redeem this gift. Keep earning!';
    }
    if (lower.contains('out of stock') || lower.contains('stock_available')) {
      return 'Sorry, this gift just went out of stock.';
    }
    if (lower.contains('already') || lower.contains('duplicate')) {
      return 'You have already placed this order.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (lower.contains('not authenticated') || lower.contains('jwt') || lower.contains('auth')) {
      return 'Session expired. Please log out and log in again.';
    }
    return 'Something went wrong with your purchase. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final primary = LeadMarketBranding.primaryColor(widget.sponsor);
    final secondary = LeadMarketBranding.secondaryColor(widget.sponsor);
    final coins = context.watch<UserProvider>().user?.coins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EAF7),
      appBar: AppBar(
        title: Text(widget.sponsor.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(error: _error!, onRetry: _load)
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: _StoreHeader(
                            sponsor: widget.sponsor,
                            primary: primary,
                            secondary: secondary,
                            coinBalance: coins,
                            productCount: _products.length,
                          ),
                        ),
                      ),
                      if (_products.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _EmptyProductsState(
                              sponsor: widget.sponsor,
                              onRefresh: _load,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: _products.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final product = _products[index];
                              return _ProductCard(
                                product: product,
                                primary: primary,
                                useFoundationLogo: isMlqFoundationStore(widget.sponsor),
                                onBuy: () => _buy(product),
                                disabled: _purchasing,
                              )
                                  .animate()
                                  .fade(duration: 280.ms, delay: (index * 45).ms)
                                  .slideY(begin: 0.04);
                            },
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final SponsorStorefront sponsor;
  final Color primary;
  final Color secondary;
  final double coinBalance;
  final int productCount;

  const _StoreHeader({
    required this.sponsor,
    required this.primary,
    required this.secondary,
    required this.coinBalance,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFFFFFBFE),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SponsorBrandedBanner(
            sponsor: sponsor,
            height: 132,
            borderRadius: BorderRadius.zero,
            overlay: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SponsorLogoAvatar(
                    logoUrl: sponsor.logoUrl,
                    name: sponsor.name,
                    primary: primary,
                    secondary: secondary,
                    size: 64,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sponsor.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sponsor.description?.isNotEmpty == true
                              ? sponsor.description!
                              : 'Browse rewards from this sponsor.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderMetric(
                    label: 'Your coins',
                    value: coinBalance.toStringAsFixed(0),
                    icon: Icons.monetization_on_rounded,
                    accent: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderMetric(
                    label: 'Available gifts',
                    value: productCount.toString(),
                    icon: Icons.card_giftcard_rounded,
                    accent: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 320.ms).slideY(begin: 0.04);
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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

class _ProductCard extends StatelessWidget {
  final LeadMarketProduct product;
  final Color primary;
  final bool useFoundationLogo;
  final VoidCallback onBuy;
  final bool disabled;

  const _ProductCard({
    required this.product,
    required this.primary,
    this.useFoundationLogo = false,
    required this.onBuy,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockAvailable <= 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(
              imageUrl: product.imageUrl,
              kind: product.productKind,
              useFoundationLogo: useFoundationLogo,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _KindBadge(kind: product.productKind),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description?.isNotEmpty == true
                        ? product.description!
                        : 'Reward donated by this sponsor.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CoinPrice(price: product.priceCoins),
                      const SizedBox(width: 8),
                      _StockBadge(stock: product.stockAvailable),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isOut || disabled ? null : onBuy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(isOut ? 'Out of stock' : 'Redeem gift'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  final String kind;
  final bool useFoundationLogo;

  const _ProductImage({
    required this.imageUrl,
    required this.kind,
    this.useFoundationLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 92,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: useFoundationLogo
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: MlqFoundationLogoImage(fit: BoxFit.contain),
            )
          : Icon(_kindIcon(kind), color: AppColors.primary, size: 34),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        imageUrl!,
        width: 92,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _CoinPrice extends StatelessWidget {
  final int price;
  const _CoinPrice({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Color(0xFF8A6400), size: 15),
          const SizedBox(width: 4),
          Text(
            '$price',
            style: GoogleFonts.nunito(
              color: const Color(0xFF8A6400),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final isOut = stock <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOut ? const Color(0xFFFFECEC) : const Color(0xFFEFFAF1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOut ? 'Sold out' : '$stock left',
        style: GoogleFonts.nunito(
          color: isOut ? Colors.red.shade700 : Colors.green.shade800,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  final String kind;
  const _KindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = kind == 'unknown'
        ? 'Gift'
        : kind[0].toUpperCase() + kind.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E9FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PurchaseSheet extends StatelessWidget {
  final LeadMarketProduct product;
  final double currentCoins;
  const _PurchaseSheet({required this.product, required this.currentCoins});

  @override
  Widget build(BuildContext context) {
    final remaining = currentCoins - product.priceCoins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm redemption',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Redeem "${product.name}" for ${product.priceCoins.toStringAsFixed(0)} coins?\n'
            'You have ${currentCoins.toStringAsFixed(0)} coins. '
            '${remaining >= 0 ? 'After redeeming: ${remaining.toStringAsFixed(0)} coins remaining.' : ''}',
            style: GoogleFonts.nunito(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Redeem'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final SponsorStorefront sponsor;
  final Future<void> Function() onRefresh;
  const _EmptyProductsState({required this.sponsor, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isFoundation = isMlqFoundationStore(sponsor);
    return _MessageCard(
      icon: Icons.inventory_2_outlined,
      title: isFoundation ? 'Browse MLQ Foundation gifts' : 'No gifts available yet',
      message: isFoundation
          ? 'Redeem your coins for school supplies, books, and rewards from the official MLQ Foundation store.'
          : 'This sponsor stand is open, but gifts have not been stocked yet. Check back soon.',
      actionLabel: 'Refresh',
      onAction: onRefresh,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 70),
        _MessageCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load gifts',
          message: error,
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              height: 1.35,
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
    );
  }
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'phone':
      return Icons.smartphone_rounded;
    case 'tablet':
      return Icons.tablet_mac_rounded;
    case 'laptop':
      return Icons.laptop_mac_rounded;
    case 'electronics':
      return Icons.headphones_rounded;
    case 'apparel':
    case 'cap':
      return Icons.checkroom_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'stationery':
      return Icons.edit_note_rounded;
    case 'toy':
      return Icons.toys_rounded;
    default:
      return Icons.card_giftcard_rounded;
  }
}
