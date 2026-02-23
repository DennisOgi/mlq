import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Widget to show progress toward earning a badge
/// Example: "3/5 goals for Sharpshooter badge"
class BadgeProgressIndicator extends StatelessWidget {
  final String badgeName;
  final String badgeDescription;
  final int currentProgress;
  final int requiredProgress;
  final IconData icon;
  final Color? color;

  const BadgeProgressIndicator({
    super.key,
    required this.badgeName,
    required this.badgeDescription,
    required this.currentProgress,
    required this.requiredProgress,
    this.icon = Icons.emoji_events,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentProgress / requiredProgress;
    final progressPercent = (progress * 100).clamp(0, 100).toInt();
    final isComplete = currentProgress >= requiredProgress;
    final badgeColor = color ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete 
            ? badgeColor.withOpacity(0.1) 
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete 
              ? badgeColor 
              : Colors.grey.withOpacity(0.3),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge name and icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isComplete 
                      ? badgeColor.withOpacity(0.2) 
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isComplete ? badgeColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badgeName,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: isComplete ? badgeColor : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeDescription,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isComplete 
                      ? badgeColor 
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isComplete 
                      ? 'Earned!' 
                      : '$currentProgress/$requiredProgress',
                  style: TextStyle(
                    color: isComplete ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? badgeColor : badgeColor.withOpacity(0.6),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Progress text
          Text(
            isComplete 
                ? '🎉 Badge earned! Check your profile.' 
                : '$progressPercent% complete - ${requiredProgress - currentProgress} more to go!',
            style: AppTextStyles.caption.copyWith(
              color: isComplete ? badgeColor : Colors.grey[600],
              fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to show a list of badge progress indicators
class BadgeProgressList extends StatelessWidget {
  final List<BadgeProgressData> badges;
  final String title;

  const BadgeProgressList({
    super.key,
    required this.badges,
    this.title = 'Badge Progress',
  });

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.heading2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: badges.map((badge) {
              return BadgeProgressIndicator(
                badgeName: badge.name,
                badgeDescription: badge.description,
                currentProgress: badge.currentProgress,
                requiredProgress: badge.requiredProgress,
                icon: badge.icon,
                color: badge.color,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Data class for badge progress
class BadgeProgressData {
  final String name;
  final String description;
  final int currentProgress;
  final int requiredProgress;
  final IconData icon;
  final Color? color;

  const BadgeProgressData({
    required this.name,
    required this.description,
    required this.currentProgress,
    required this.requiredProgress,
    this.icon = Icons.emoji_events,
    this.color,
  });
}
