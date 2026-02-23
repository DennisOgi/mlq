import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';

class GoalCompletionDialog extends StatefulWidget {
  final MainGoalModel goal;
  final VoidCallback onArchive;
  final VoidCallback onKeepActive;

  const GoalCompletionDialog({
    super.key,
    required this.goal,
    required this.onArchive,
    required this.onKeepActive,
  });

  @override
  State<GoalCompletionDialog> createState() => _GoalCompletionDialogState();
}

class _GoalCompletionDialogState extends State<GoalCompletionDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  '🎉 Goal Completed!',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Congratulations on completing:',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '"${widget.goal.title}"',
                  style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('Achievement Stats', style: AppTextStyles.bodyBold),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('XP Earned', '${widget.goal.currentXp}', Icons.star),
                          _buildStat('Timeline', widget.goal.timelineText, Icons.calendar_today),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Would you like to archive this goal and set a new one?',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: widget.onKeepActive,
                child: const Text('Keep Active'),
              ),
              ElevatedButton(
                onPressed: widget.onArchive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Archive & Set New Goal'),
              ),
            ],
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.05,
            shouldLoop: false,
            colors: const [
              Colors.amber,
              AppColors.primary,
              AppColors.secondary,
              AppColors.tertiary,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyBold),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
