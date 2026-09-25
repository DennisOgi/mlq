import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  /// Desktop breakpoint used by the main shell (side nav).
  static const double desktopBreakpoint = 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Rounded bottom on mobile; square on desktop so AppBar meets the side rail cleanly.
  static ShapeBorder? appBarShape(BuildContext context) {
    if (isDesktop(context)) {
      return const RoundedRectangleBorder(borderRadius: BorderRadius.zero);
    }
    return const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
    );
  }

  // Get the app's theme data
  static ThemeData getThemeData() {
    // Use Google Fonts Nunito for a friendly, modern look
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    
    final textTheme = baseTextTheme.copyWith(
      // Display styles
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      // Headline styles
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      // Title styles
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      // Body styles
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.textPrimary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
      // Label styles
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: AppColors.textOnGold,
        onTertiary: Colors.black,
        onError: Colors.white,
        background: AppColors.background,
        surface: AppColors.surface,
      ),
      // Nunito text theme throughout the app
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
        titleTextStyle: AppTextStyles.heading2.copyWith(
          color: AppColors.textOnPrimary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(22),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        labelStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textHint,
        ),
        errorStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.error,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle:
            AppTextStyles.body.copyWith(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Soft brand surface (preferred over old neumorphic dual-shadow).
  static BoxDecoration getNeumorphicDecoration({
    double borderRadius = 16,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.border),
      boxShadow: NeumorphicStyles.softShadow,
    );
  }

  // Get a gradient decoration
  static BoxDecoration getGradientDecoration({
    List<Color> colors = const [AppColors.primary, AppColors.primaryDark],
    double borderRadius = 16,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: begin,
        end: end,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // Get a category color based on the category
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return AppColors.academic;
      case 'social':
        return AppColors.social;
      case 'health':
        return AppColors.health;
      default:
        return AppColors.primary;
    }
  }

  static BoxDecoration getPressedNeumorphicDecoration({
    double borderRadius = 16,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.border),
    );
  }
}
