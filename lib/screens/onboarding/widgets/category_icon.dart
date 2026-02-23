import 'package:flutter/material.dart';
import '../../../models/main_goal_model.dart';
import '../../../constants/app_constants.dart';

class CategoryIcon extends StatelessWidget {
  final GoalCategory category;
  final double size;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    late IconData iconData;
    late Color color;

    switch (category) {
      case GoalCategory.academic:
        iconData = Icons.school;
        color = AppColors.academic;
        break;
      case GoalCategory.social:
        iconData = Icons.people;
        color = AppColors.social;
        break;
      case GoalCategory.health:
        iconData = Icons.fitness_center;
        color = AppColors.health;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        iconData,
        color: color,
        size: size * 0.57,
      ),
    );
  }
}
