import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../services/vas_session.dart';
import '../subscription/subscription_management_screen.dart';

enum VasLockReason { upgrade, schoolCommunityOnly }

class VasFeatureGate {
  VasFeatureGate._();

  static Future<void> showLocked(
    BuildContext context, {
    required String featureName,
    VasLockReason reason = VasLockReason.upgrade,
  }) async {
    if (reason == VasLockReason.schoolCommunityOnly) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Victory Wall'),
          content: const Text(
            'Accessible by schools and registered communities only.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                featureName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                VasSession.isDemo
                    ? 'Demo: this feature is part of full MLQ. Upgrade unlocks mini-courses, challenges, AI coach, and more.'
                    : 'Upgrade to full MLQ for mini-courses, challenges, AI coach & more. Your daily airtime plan keeps Goals, Gratitude, and the leaderboard.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionManagementScreen(),
                    ),
                  );
                },
                child: const Text('Upgrade to full MLQ'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now'),
              ),
            ],
          ),
        );
      },
    );
  }
}
