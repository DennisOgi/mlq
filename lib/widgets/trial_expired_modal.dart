import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class TrialExpiredModal extends StatelessWidget {
  const TrialExpiredModal({super.key});

  static bool _shownThisSession = false;

  static Future<void> showOnce(BuildContext context) async {
    if (_shownThisSession) return;
    _shownThisSession = true;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TrialExpiredModal(),
    );
  }

  static const _features = [
    'Mini-courses after 7 days',
    'Digital Library',
    'Challenges',
    'LeadWallet',
    'Victory Wall posts',
    'AI Coach',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Mini-courses ended', style: AppTextStyles.heading3),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 7-day mini-course preview has ended. Goals, Gratitude Jar, and the leaderboard stay free. Subscribe to unlock:',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            ..._features.map(_buildFeatureItem),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Monthly ₦2,500 · Quarterly ₦7,000',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Maybe Later',
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/subscription-management');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
