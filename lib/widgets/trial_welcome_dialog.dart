import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class TrialWelcomeDialog extends StatelessWidget {
  const TrialWelcomeDialog({super.key, this.days = 7});

  final int days;

  static const prefsKey = 'mlq_trial_welcome_shown';

  static Future<void> show(
    BuildContext context, {
    int days = 7,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(prefsKey) ?? false)) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TrialWelcomeDialog(days: days),
    );
    await prefs.setBool(prefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.uiTrialGift,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              'Your free account is ready',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Goals, Gratitude Jar, and the leaderboard are yours from day one. Mini-courses stay open for $days days — subscribe to keep them and unlock the rest.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            _featureRow(Icons.flag_rounded, 'Daily Goals — always included'),
            _featureRow(Icons.volunteer_activism_rounded, 'Gratitude Jar — always included'),
            _featureRow(Icons.leaderboard_rounded, 'View the leaderboard'),
            _featureRow(Icons.school_rounded, 'Mini-courses for $days days'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Start exploring'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
