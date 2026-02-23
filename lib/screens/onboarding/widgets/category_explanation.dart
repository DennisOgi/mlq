import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';

class CategoryExplanation extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const CategoryExplanation({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        Container(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyBold,
              ),
              Text(
                description,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }
}
