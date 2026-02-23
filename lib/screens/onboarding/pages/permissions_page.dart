import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/quest_button.dart';

class PermissionsPage extends StatelessWidget {
  final VoidCallback onAllowNotifications;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const PermissionsPage({
    super.key,
    required this.onAllowNotifications,
    required this.onSkip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Notification icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 50,
                color: AppColors.secondary,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 32),

            // Title
            Text(
              'Stay Updated!',
              style: AppTextStyles.heading2,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
            const SizedBox(height: 16),

            // Description
            Text(
              'Allow notifications to get reminders about your goals, challenges, and messages from Questor!',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
            const SizedBox(height: 32),

            // Permission button
            QuestButton(
              text: 'Allow Notifications',
              type: QuestButtonType.secondary,
              icon: Icons.notifications,
              isFullWidth: true,
              onPressed: onAllowNotifications,
            ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            const SizedBox(height: 16),

            // Skip button
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip for now',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 800.ms),
            const SizedBox(height: 220),

            // Back button
            QuestButton(
              text: 'Back',
              type: QuestButtonType.outline,
              isFullWidth: true,
              onPressed: onBack,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
