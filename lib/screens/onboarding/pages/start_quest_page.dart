import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/quest_button.dart';

class StartQuestPage extends StatelessWidget {
  final bool isStartingQuest;
  final VoidCallback onStartQuest;
  final VoidCallback onBack;

  const StartQuestPage({
    super.key,
    required this.isStartingQuest,
    required this.onStartQuest,
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
            const SizedBox(height: 40),
            // Success icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.tertiary,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 40),

            // Title
            Text(
              "You're Ready!",
              style: AppTextStyles.heading1,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
            const SizedBox(height: 16),

            // Subtitle
            Center(
              child: Text(
                "Your leadership quest awaits. Let's begin your journey to becoming a great leader!",
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
            ),
            const SizedBox(height: 40),

            // Start button - enhanced and more prominent
            Container(
              width: double.infinity,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    isStartingQuest
                        ? AppColors.primary.withOpacity(0.7)
                        : AppColors.primary,
                    const Color(0xFFFFE03A), // Lighter yellow
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isStartingQuest ? null : onStartQuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: isStartingQuest
                      ? Row(
                          key: const ValueKey('loading'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.black),
                                backgroundColor: Colors.black.withOpacity(0.1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Starting... ',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          key: const ValueKey('normal'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow,
                                color: Colors.black, size: 28),
                            const SizedBox(width: 16),
                            Text(
                              'START YOUR QUEST',
                              style: AppTextStyles.button.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 600.ms)
                .then(delay: 300.ms)
                .shimmer(
                    duration: 1200.ms, color: Colors.white.withOpacity(0.8)),
            const SizedBox(height: 250),

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
