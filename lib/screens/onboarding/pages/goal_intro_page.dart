import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../models/main_goal_model.dart';
import '../../../widgets/quest_button.dart';
import '../widgets/category_icon.dart';
import '../widgets/category_explanation.dart';

class GoalIntroPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const GoalIntroPage({
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
                  // Title
                  Text(
                    'Set Your Goals',
                    style: AppTextStyles.heading1,
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'Your leadership journey has three paths:',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 32),

                  // Category icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CategoryIcon(category: GoalCategory.academic)
                          .animate()
                          .scale(duration: 500.ms, delay: 300.ms),
                      CategoryIcon(category: GoalCategory.social)
                          .animate()
                          .scale(duration: 500.ms, delay: 400.ms),
                      CategoryIcon(category: GoalCategory.health)
                          .animate()
                          .scale(duration: 500.ms, delay: 500.ms),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Category explanations
                  CategoryExplanation(
                    title: 'Academic',
                    description: 'School, learning, and knowledge goals',
                    icon: Icons.school,
                    color: AppColors.academic,
                  ),
                  const SizedBox(height: 16),
                  CategoryExplanation(
                    title: 'Social',
                    description: 'Friendship, teamwork, and community goals',
                    icon: Icons.people,
                    color: AppColors.social,
                  ),
                  const SizedBox(height: 16),
                  CategoryExplanation(
                    title: 'Health',
                    description: 'Fitness, wellness, and self-care goals',
                    icon: Icons.fitness_center,
                    color: AppColors.health,
                  ),
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
