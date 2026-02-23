import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';

class QuestProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color? color;
  final double height;
  final bool showPercentage;
  final bool animate;
  final String? label;

  const QuestProgressIndicator({
    super.key,
    required this.progress,
    this.color,
    this.height = 12.0,
    this.showPercentage = false,
    this.animate = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppColors.secondary;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentage = (clampedProgress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: AppTextStyles.caption,
                  ),
                if (showPercentage)
                  Text(
                    '$percentage%',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            return Container(
              height: height,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neumorphicDark,
                    offset: const Offset(-1, -1),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: AppColors.neumorphicHighlight,
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (animate)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: maxWidth * clampedProgress,
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    )
                  else
                    Container(
                      width: maxWidth * clampedProgress,
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ).animate(target: animate ? 1 : 0).slideX(
                          begin: -1,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuart,
                        ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
