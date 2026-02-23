import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/quest_button.dart';

class InterestsPage extends StatelessWidget {
  final List<String> availableInterests;
  final List<String> selectedInterests;
  final ValueChanged<String> onToggleInterest;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const InterestsPage({
    super.key,
    required this.availableInterests,
    required this.selectedInterests,
    required this.onToggleInterest,
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

                  // Title
                  Text(
                    'Your Interests',
                    style: AppTextStyles.heading1.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 24),

                  // Questor image
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.secondary.withOpacity(0.2),
                            AppColors.secondary.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/questor 8.png',
                        fit: BoxFit.contain,
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut),
                  ),

                  const SizedBox(height: 24),

                  // Description with icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.secondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pick some interests so Questor can personalize your journey.',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                  const SizedBox(height: 24),

                  // Interest chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: availableInterests.map((interest) {
                      final isSelected = selectedInterests.contains(interest);
                      return GestureDetector(
                        onTap: () => onToggleInterest(interest),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.secondary.withOpacity(0.8),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : AppColors.secondary.withOpacity(0.3),
                              width: isSelected ? 2 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color:
                                          AppColors.secondary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              Text(
                                interest,
                                style: AppTextStyles.body.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.secondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

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
}
