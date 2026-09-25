import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum QuestButtonType { primary, secondary, outline, text, success }

class QuestButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final QuestButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;

  const QuestButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = QuestButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height = AppSizes.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Define button style based on type
    final ButtonStyle style;
    final Color textColor;

    final textStyle = height <= 44
        ? AppTextStyles.smallButton
        : AppTextStyles.button;

    switch (type) {
      case QuestButtonType.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
        textColor = AppColors.textOnPrimary;
        break;
      case QuestButtonType.secondary:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textOnGold,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
        textColor = AppColors.textOnGold;
        break;
      case QuestButtonType.outline:
        style = OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
        textColor = AppColors.primary;
        break;
      case QuestButtonType.success:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
        textColor = AppColors.textOnPrimary;
        break;
      case QuestButtonType.text:
        style = TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        );
        textColor = AppColors.primary;
        break;
    }

    // Create button content
    Widget buttonContent;
    if (isLoading) {
      buttonContent = SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else if (icon != null) {
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: textStyle.copyWith(color: textColor),
          ),
        ],
      );
    } else {
      buttonContent = Text(
        text,
        style: textStyle.copyWith(color: textColor),
      );
    }

    // Create button based on type
    switch (type) {
      case QuestButtonType.primary:
      case QuestButtonType.secondary:
      case QuestButtonType.success:
        return SizedBox(
          width: isFullWidth ? double.infinity : width,
          height: height,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: buttonContent,
          ),
        );
      case QuestButtonType.outline:
        return SizedBox(
          width: isFullWidth ? double.infinity : width,
          height: height,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: style,
            child: buttonContent,
          ),
        );
      case QuestButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: buttonContent,
        );
    }
  }
}
