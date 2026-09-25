import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/lead_market_service.dart';

/// Stable sponsor id from `lead_market_foundation_and_admin_economy.sql`.
const kMlqFoundationSponsorId = 'c8f3e2a1-9b4d-4e6f-8a1c-2d3e4f5a6b7c';

bool isMlqFoundationStore(SponsorStorefront sponsor) =>
    sponsor.id == kMlqFoundationSponsorId ||
    isMlqFoundationLabel(sponsor.name);

bool isMlqFoundationLabel(String name) =>
    name.trim().toLowerCase() == 'mlq foundation';

/// True when the Lead Market has only the official MLQ Foundation storefront.
bool isFoundationOnlyMarket(List<SponsorStorefront> sponsors) {
  if (sponsors.isEmpty) return false;
  return sponsors.every(isMlqFoundationStore);
}

class LeadMarketBranding {
  LeadMarketBranding._();

  static Color? parseHexColor(String? hex) {
    final raw = (hex ?? '').trim();
    if (raw.isEmpty) return null;
    var h = raw.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  static Color primaryColor(SponsorStorefront sponsor) =>
      parseHexColor(sponsor.themePrimaryColor) ?? AppColors.primary;

  static Color secondaryColor(SponsorStorefront sponsor) =>
      parseHexColor(sponsor.themeSecondaryColor) ?? AppColors.secondary;
}

/// MLQ Foundation logo from bundled assets (assets/images/MLQ_LOGO.png).
class MlqFoundationLogoImage extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const MlqFoundationLogoImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      AppAssets.mlqFoundationLogo,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.asset(
        AppAssets.questorDefault,
        width: width,
        height: height,
        fit: fit,
      ),
    );

    if (backgroundColor != null || borderRadius != null) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: image,
        ),
      );
    }

    return image;
  }
}

class SponsorBrandedBanner extends StatelessWidget {
  final SponsorStorefront sponsor;
  final double height;
  final BorderRadius borderRadius;
  final Widget? overlay;

  const SponsorBrandedBanner({
    super.key,
    required this.sponsor,
    this.height = 108,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LeadMarketBranding.primaryColor(sponsor);
    final secondary = LeadMarketBranding.secondaryColor(sponsor);
    final bannerUrl = sponsor.bannerUrl;
    final useFoundationBanner = isMlqFoundationStore(sponsor);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (useFoundationBanner)
              _gradient(primary, secondary)
            else if (bannerUrl != null && bannerUrl.isNotEmpty)
              Image.network(
                bannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradient(primary, secondary),
              )
            else
              _gradient(primary, secondary),
            if (useFoundationBanner)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: MlqFoundationLogoImage(
                    height: height * 0.55,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }

  Widget _gradient(Color primary, Color secondary) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class SponsorLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final String name;
  final Color primary;
  final Color secondary;
  final double size;
  final double borderWidth;

  const SponsorLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.name,
    required this.primary,
    required this.secondary,
    this.size = 58,
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (isMlqFoundationStore(SponsorStorefront(id: '', name: name))) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: MlqFoundationLogoImage(
            width: size,
            height: size,
            fit: BoxFit.contain,
            backgroundColor: Colors.white,
          ),
        ),
      );
    }

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
      ),
      child: _letterFallback(),
    );

    if (logoUrl == null || logoUrl!.isEmpty) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          logoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  Widget _letterFallback() {
    return Text(
      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: size * 0.32,
      ),
    );
  }
}
