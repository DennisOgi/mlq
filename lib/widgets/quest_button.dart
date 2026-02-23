import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

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
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
        textColor = const Color.fromARGB(255, 248, 246, 246);
        break;
      case QuestButtonType.secondary:
        style = ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
        textColor = Colors.white;
        break;
      case QuestButtonType.outline:
        style = OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.secondary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
        textColor = AppColors.secondary;
        break;
      case QuestButtonType.success:
        style = ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: height <= 44
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              : null,
          minimumSize: Size(0, height),
          tapTargetSize:
              height <= 44 ? MaterialTapTargetSize.shrinkWrap : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
        textColor = Colors.white;
        break;
      case QuestButtonType.text:
        style = TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
        );
        textColor = AppColors.secondary;
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
        return Container(
          width: isFullWidth ? double.infinity : width,
          height: height,
          decoration: onPressed != null && !isLoading 
            ? AppTheme.getNeumorphicDecoration(borderRadius: 16)
            : null,
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
