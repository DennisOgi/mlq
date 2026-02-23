import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/organization_settings_provider.dart';

class DynamicLogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? fallbackAsset;

  const DynamicLogoWidget({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackAsset = 'assets/images/questor.png',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizationSettingsProvider>(
      builder: (context, provider, child) {
        final logoUrl = provider.logoUrl;
        
        // If no logo URL or it's an asset path, use asset image
        if (logoUrl.isEmpty || logoUrl.startsWith('assets/')) {
          return Image.asset(
            logoUrl.isEmpty ? (fallbackAsset ?? 'assets/images/questor.png') : logoUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to default asset if error
              return Image.asset(
                fallbackAsset ?? 'assets/images/questor.png',
                width: width,
                height: height,
                fit: fit,
              );
            },
          );
        }
        
        // Use network image for uploaded logos
        return Image.network(
          logoUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Fallback to asset image if network image fails
            return Image.asset(
              fallbackAsset ?? 'assets/images/questor.png',
              width: width,
              height: height,
              fit: fit,
            );
          },
        );
      },
    );
  }
}

// Convenience widget for organization logo specifically
class OrganizationLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const OrganizationLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicLogoWidget(
      width: width,
      height: height,
      fit: fit,
      fallbackAsset: 'assets/images/questor.png',
    );
  }
}
