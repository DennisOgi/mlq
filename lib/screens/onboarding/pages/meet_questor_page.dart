import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/quest_button.dart';
import '../widgets/sparkles_overlay.dart';

class MeetQuestorPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const MeetQuestorPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Title with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                    ).createShader(bounds),
                    child: Text(
                      'Meet Questor!',
                      style: AppTextStyles.heading1.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 12),

                  // Subtitle with badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.2),
                          AppColors.primary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your AI coach and companion',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 32),

                  // Questor image with enhanced sparkles
                  SparklesOverlay(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.secondary.withOpacity(0.3),
                                AppColors.secondary.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/questor.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut),
                  ),
                  const SizedBox(height: 32),

                  // Questor features with enhanced styling
                  _buildQuestorFeature(
                    icon: Icons.psychology,
                    title: 'Smart Guidance',
                    description:
                        'I learn about you and give personalized advice',
                    color: AppColors.primary,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 400.ms)
                      .slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 12),
                  _buildQuestorFeature(
                    icon: Icons.emoji_emotions,
                    title: 'Always Supportive',
                    description:
                        'I celebrate your wins and help when things are tough',
                    color: AppColors.secondary,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 500.ms)
                      .slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 12),
                  _buildQuestorFeature(
                    icon: Icons.chat_bubble,
                    title: 'Chat Anytime',
                    description:
                        'Ask me anything about your goals or challenges',
                    color: AppColors.academic,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 600.ms)
                      .slideX(begin: -0.2, end: 0),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Navigation buttons at bottom
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: QuestButton(
                    text: 'Back',
                    type: QuestButtonType.outline,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: QuestButton(
                    text: 'Next',
                    type: QuestButtonType.primary,
                    icon: Icons.arrow_forward,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestorFeature({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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
