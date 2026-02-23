import 'package:flutter/material.dart';

class AppColors {
  // Primary colors from memory
  static const Color primary = Color.fromARGB(255, 157, 3, 137); // Purple
  static const Color secondary = Color(0xFFFFD700); // Gold
  static const Color tertiary = Color(0xFFA1E44D); // Green
  
  // Accent colors from memory
  static const Color accent1 = Color(0xFFFF70A6); // Pink
  static const Color accent2 = Color(0xFFFF9505); // Orange
  
  // Neumorphic colors (updated to white theme)
  static const Color background = Color(0xFFFFFFFF); // Main app background
  static const Color surface = Color(0xFFFFFFFF); // Surface color
  static const Color neumorphicLight = Color(0xFFF0F0F0); // Light shadow
  static const Color neumorphicDark = Color(0xFFD0D0D0); // Dark shadow
  static const Color neumorphicHighlight = Color(0xFFFFFFFF); // Highlight
  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF5AC8FA);
  
  // Text colors (optimized for neumorphic background)
  static const Color textPrimary = Color(0xFF2C2C2C); // Darker for better contrast
  static const Color textSecondary = Color(0xFF555555); // Slightly darker
  static const Color textHint = Color(0xFF888888); // Better visibility
  
  // Category colors
  static const Color academic = Color(0xFF00C4FF); // Blue
  static const Color social = Color(0xFFFF70A6); // Pink
  static const Color health = Color(0xFFA1E44D); // Green
}

class AppTextStyles {
  // Use Google Fonts Nunito for friendly, modern typography
  // Note: Use GoogleFonts.nunito() directly for dynamic font loading
  
  static TextStyle get heading1 => _nunito(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  
  static TextStyle get heading2 => _nunito(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  
  static TextStyle get heading3 => _nunito(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get body => _nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get bodyBold => _nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static TextStyle get bodySmall => _nunito(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => _nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  static TextStyle get button => _nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static TextStyle get smallButton => _nunito(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  // Section header style - distinctive bold with slight letter spacing
  static TextStyle get sectionHeader => _nunito(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );
  
  // Helper method to create Nunito text styles
  static TextStyle _nunito({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Nunito',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class AppSizes {
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  
  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;
  static const double radiusXL = 32.0;
  
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
  
  static const double buttonHeight = 56.0;
  static const double smallButtonHeight = 40.0;
  
  static const double cardElevation = 4.0;
}

class AppStrings {
  // App name
  static const String appName = 'My Leadership Quest';
  
  // Onboarding
  static const String welcomeTitle = 'Embark on Your Leadership Quest!';
  static const String welcomeSubtitle = 'Set goals, earn rewards, and become a leader!';
  static const String getStarted = 'Get Started';
  
  static const String goalIntroTitle = 'Set Your Goals';
  static const String goalIntroSubtitle = 'Academic, Social, and Health goals will guide your journey.';
  
  static const String meetQuestorTitle = 'Meet Questor!';
  static const String meetQuestorSubtitle = 'Your AI coach will guide you on your quest.';
  
  // Navigation
  static const String home = 'Home';
  static const String goals = 'Goals';
  static const String challenges = 'Challenges';
  static const String victoryWall = 'Victory Wall';
  static const String profile = 'Profile';
  
  // Goal categories
  static const String academic = 'Academic';
  static const String social = 'Social';
  static const String health = 'Health';
  
  // Buttons
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String add = 'Add';
  static const String join = 'Join';
  static const String leave = 'Leave';
  static const String post = 'Post';
  static const String send = 'Send';
  
  // Placeholders
  static const String titlePlaceholder = 'Enter title...';
  static const String descriptionPlaceholder = 'Enter description...';
  static const String messagePlaceholder = 'Type a message...';
  static const String postPlaceholder = 'Share your victory...';
  
  // Error messages
  static const String errorTitle = 'Oops!';
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNoInternet = 'No internet connection.';
  static const String errorInvalidInput = 'Please check your input and try again.';
}

class AppAssets {
  // Questor images
  static const String questorDefault = 'assets/images/questor.png';
  static const String questorHappy = 'assets/images/questor 2.png';
  static const String questorThinking = 'assets/images/questor 3.png';
  static const String questorExcited = 'assets/images/questor 4.png';
  static const String questorSad = 'assets/images/questor 5.png';
  
  // Badge images are referenced directly in the BadgeModel class
  
  // Add more assets as needed
}

class NeumorphicStyles {
  // Standard neumorphic decoration
  static BoxDecoration get standard => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: AppColors.neumorphicDark,
        offset: const Offset(4, 4),
        blurRadius: 8,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicHighlight,
        offset: const Offset(-4, -4),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  // Pressed/inset neumorphic decoration
  static BoxDecoration get pressed => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: AppColors.neumorphicDark,
        offset: const Offset(-2, -2),
        blurRadius: 4,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicHighlight,
        offset: const Offset(2, 2),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ],
  );

  // Small neumorphic decoration for smaller elements
  static BoxDecoration get small => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppColors.neumorphicDark,
        offset: const Offset(2, 2),
        blurRadius: 4,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicHighlight,
        offset: const Offset(-2, -2),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ],
  );

  // Large neumorphic decoration for bigger cards
  static BoxDecoration get large => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.neumorphicDark,
        offset: const Offset(6, 6),
        blurRadius: 12,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicHighlight,
        offset: const Offset(-6, -6),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ],
  );
}
