import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/providers/user_provider.dart';
import 'package:my_leadership_quest/screens/lead_market/my_market_orders_screen.dart';
import 'package:my_leadership_quest/screens/lead_market/sponsor_shop_screen.dart';
import 'package:my_leadership_quest/services/lead_market_service.dart';
import 'package:my_leadership_quest/utils/lead_market_branding.dart';
import 'package:provider/provider.dart';

class LeadMarketSponsorsScreen extends StatefulWidget {
  const LeadMarketSponsorsScreen({super.key});

  @override
  State<LeadMarketSponsorsScreen> createState() =>
      _LeadMarketSponsorsScreenState();
}

class _LeadMarketSponsorsScreenState extends State<LeadMarketSponsorsScreen> {
  bool _loading = true;
  List<SponsorStorefront> _sponsors = [];
  String? _error;
  String _search = '';

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
      final sponsors = await LeadMarketService().listSponsors();
      if (!mounted) return;
      setState(() {
        _sponsors = sponsors;
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
    final user = context.watch<UserProvider>().user;
    SponsorStorefront? foundation;
    for (final s in _sponsors) {
      if (isMlqFoundationStore(s)) {
        foundation = s;
        break;
      }
    }
    final partnerStores = _sponsors
        .where((s) => !isMlqFoundationStore(s))
        .toList();
    final visiblePartners = partnerStores.where((s) {
      final needle = _search.trim().toLowerCase();
      if (needle.isEmpty) return true;
      return s.name.toLowerCase().contains(needle) ||
          (s.description ?? '').toLowerCase().contains(needle);
    }).toList();
    final foundationVisible = foundation != null &&
        (_search.trim().isEmpty ||
            foundation.name.toLowerCase().contains(_search.trim().toLowerCase()) ||
            (foundation.description ?? '')
                .toLowerCase()
                .contains(_search.trim().toLowerCase()));
    final onlyFoundation = isFoundationOnlyMarket(_sponsors);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EAF7),
      appBar: AppBar(
        title: Text(
          'Lead Market',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Purchase history',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyMarketOrdersScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEDE0F4),
              Color(0xFFF3EAF7),
              Color(0xFFFAF5FC),
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(error: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        _MarketHero(
                          coinBalance: user?.coins ?? 0,
                          sponsorCount: _sponsors.length,
                          productCount: _sponsors.fold<int>(
                            0,
                            (total, s) => total + s.activeProductCount,
                          ),
                          onlyFoundation: onlyFoundation,
                        ),
                        const SizedBox(height: 16),
                        if (!onlyFoundation)
                          _SearchField(
                            onChanged: (value) => setState(() => _search = value),
                          ),
                        if (!onlyFoundation) const SizedBox(height: 20),
                        if (foundation != null && foundationVisible) ...[
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Official MLQ store',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FeaturedFoundationCard(
                            sponsor: foundation,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SponsorShopScreen(sponsor: foundation!),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (onlyFoundation)
                          const _PartnersComingSoonBanner()
                        else if (partnerStores.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Partner storefronts',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  '${visiblePartners.length} open',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_sponsors.isEmpty)
                          _EmptyMarketState(onRefresh: _load)
                        else if (!foundationVisible && visiblePartners.isEmpty)
                          _EmptySearchState(search: _search)
                        else ...[
                          ...visiblePartners.asMap().entries.map(
                                (entry) => _SponsorStandCard(
                                  sponsor: entry.value,
                                  index: entry.key,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SponsorShopScreen(
                                          sponsor: entry.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }
}

class _MarketHero extends StatelessWidget {
  final double coinBalance;
  final int sponsorCount;
  final int productCount;
  final bool onlyFoundation;

  const _MarketHero({
    required this.coinBalance,
    required this.sponsorCount,
    required this.productCount,
    this.onlyFoundation = false,
  });

  @override
  Widget build(BuildContext context) {
    const brandPurple = AppColors.primary;
    const deepPurple = Color(0xFF4A003F);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            deepPurple,
            brandPurple,
            Color(0xFFB832A8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: brandPurple.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -28,
            top: -18,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Redeem your coins',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse sponsor stores and trade leadership coins for real gifts.',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMetric(
                            label: 'Coins',
                            value: coinBalance.toStringAsFixed(0),
                            icon: Icons.monetization_on_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Stores',
                            value: sponsorCount.toString(),
                            icon: Icons.storefront_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeroMetric(
                            label: 'Gifts',
                            value: productCount.toString(),
                            icon: Icons.card_giftcard_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.85),
                    width: 3,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.questorExcited,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.questorDefault,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: 0.04);
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search sponsor stores',
          hintStyle: GoogleFonts.nunito(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary.withValues(alpha: 0.75),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _FeaturedFoundationCard extends StatelessWidget {
  final SponsorStorefront sponsor;
  final VoidCallback onTap;

  const _FeaturedFoundationCard({
    required this.sponsor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LeadMarketBranding.primaryColor(sponsor);
    final secondary = LeadMarketBranding.secondaryColor(sponsor);
    final giftLabel = sponsor.activeProductCount == 0
        ? 'Gifts coming soon'
        : sponsor.activeProductCount == 1
            ? '1 gift ready to redeem'
            : '${sponsor.activeProductCount} gifts ready to redeem';

    return Material(
      color: const Color(0xFFFFFBFE),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: primary.withValues(alpha: 0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SponsorBrandedBanner(
                sponsor: sponsor,
                height: 128,
                overlay: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'OFFICIAL · FIRST STOREFRONT',
                          style: GoogleFonts.nunito(
                            color: const Color(0xFF4A003F),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          SponsorLogoAvatar(
                            logoUrl: sponsor.logoUrl,
                            name: sponsor.name,
                            primary: primary,
                            secondary: secondary,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sponsor.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  giftLabel,
                                  style: GoogleFonts.nunito(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sponsor.description ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, secondary.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Enter MLQ Foundation Store',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: 0.04);
  }
}

class _PartnersComingSoonBanner extends StatelessWidget {
  const _PartnersComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.handshake_rounded,
            color: AppColors.primary.withValues(alpha: 0.75),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partner stores coming soon',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'School sponsors and brand partners will open their own gift stands here as they join Lead Market.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 120.ms);
  }
}

class _SponsorStandCard extends StatelessWidget {
  final SponsorStorefront sponsor;
  final int index;
  final VoidCallback onTap;

  const _SponsorStandCard({
    required this.sponsor,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LeadMarketBranding.primaryColor(sponsor);
    final secondary = LeadMarketBranding.secondaryColor(sponsor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFFFFBFE),
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SponsorBrandedBanner(
                  sponsor: sponsor,
                  height: 112,
                  overlay: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SponsorLogoAvatar(
                              logoUrl: sponsor.logoUrl,
                              name: sponsor.name,
                              primary: primary,
                              secondary: secondary,
                              size: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sponsor.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sponsor.activeProductCount == 0
                                        ? 'Gifts coming soon'
                                        : sponsor.activeProductCount == 1
                                            ? '1 gift available'
                                            : '${sponsor.activeProductCount} gifts available',
                                    style: GoogleFonts.nunito(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sponsor.description?.isNotEmpty == true
                            ? sponsor.description!
                            : 'Step inside this branded sponsor storefront.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.door_front_door_rounded,
                                size: 17, color: primary),
                            const SizedBox(width: 8),
                            Text(
                              'Enter storefront',
                              style: GoogleFonts.nunito(
                                color: primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: primary.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms, delay: (index * 45).ms).slideY(begin: 0.04);
  }
}

class _EmptyMarketState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyMarketState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Image.asset(
          'assets/images/questor 9.png',
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront_outlined,
            size: 88,
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 8),
        _MessageCard(
          icon: Icons.storefront_rounded,
          title: 'No storefronts open yet',
          message:
              'Sponsor gift stores will appear here once partners are onboarded and have active rewards to redeem.',
          actionLabel: 'Refresh',
          onAction: onRefresh,
        ),
      ],
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final String search;
  const _EmptySearchState({required this.search});

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.search_off_rounded,
      title: 'No matches found',
      message: 'No sponsor stand matches "$search". Try another search.',
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
        const SizedBox(height: 80),
        _MessageCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load Lead Market',
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
        color: const Color(0xFFFFFBFE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E9FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onAction!(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.04);
  }
}

