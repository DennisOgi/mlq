import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class DailyGoalExample extends StatelessWidget {
  final String title;
  final bool isCompleted;

  const DailyGoalExample({
    super.key,
    required this.title,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.tertiary : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted ? AppColors.tertiary : Colors.grey,
                width: 2,
              ),
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
          Container(width: 6),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.academic.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+10 XP',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.academic,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
