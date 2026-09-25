import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class FeatureLockCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool compact;
  final String footnote;

  const FeatureLockCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.lock_rounded,
    this.compact = false,
    this.footnote = 'Included with Monthly or Quarterly',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/subscription-management'),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.35),
            ),
            boxShadow: NeumorphicStyles.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: compact ? 56 : 72,
                child: Image.asset(
                  AppAssets.uiLockCrest,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                title,
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                footnote,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/subscription-management');
                },
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('View Plans'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
