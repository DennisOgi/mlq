import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'notification_badge.dart';

class EnhancedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool showNotificationBadge;
  final double height;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? textColor;

  const EnhancedAppBar({
    Key? key,
    required this.title,
    this.showBackButton = false,
    this.actions,
    this.showNotificationBadge = true,
    this.height = 60.0,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> appBarActions = [];
    
    // Add notification badge if requested
    if (showNotificationBadge) {
      appBarActions.add(const NotificationBadge());
    }
    
    // Add any additional actions
    if (actions != null) {
      appBarActions.addAll(actions!);
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColor != null
              ? [backgroundColor!, backgroundColor!]
              : [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: AppTheme.isDesktop(context)
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: AppBar(
          toolbarHeight: height,
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: centerTitle,
          iconTheme: const IconThemeData(color: AppColors.secondary),
          actionsIconTheme: const IconThemeData(color: AppColors.secondary),
          automaticallyImplyLeading: showBackButton,
          leading: showBackButton
              ? leading ?? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: textColor ?? AppColors.secondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : leading,
          title: Text(
            title,
            style: AppTextStyles.heading.copyWith(
              color: textColor ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          actions: appBarActions,
          shape: AppTheme.appBarShape(context),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
