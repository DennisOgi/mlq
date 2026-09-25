import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Canonical MLQ brand colors (UI revamp palette).
/// Plum and violet dominate; gold marks rewards, XP and primary actions.
class AppColors {
  // Brand — vivid magenta, not dusty violet
  static const Color plum = Color(0xFF7A0270);
  static const Color primary = Color(0xFFC218A8);
  static const Color primaryDark = Color(0xFF9D0389);
  static const Color violetLight = Color(0xFFE85BCF);
  static const Color primarySoft = Color(0xFFFDE8F8);
  static const Color secondary = Color(0xFFF2C94C); // Quest Gold (fills)
  static const Color secondaryBright = Color(0xFFFFD95E);
  static const Color goldPressed = Color(0xFFC99A1E);
  static const Color goldText = Color(0xFF7A5600); // gold for text on light
  static const Color tertiary = Color(0xFF7BC62D); // Growth green

  // Accents
  static const Color accent1 = violetLight;
  static const Color accent2 = Color(0xFFFF9505); // Orange / energy
  static const Color accent = secondary; // alias for theme/* imports

  // Surfaces
  static const Color background = Color(0xFFFFF9F0); // Cream White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = primarySoft;
  static const Color border = Color(0xFFF0DCEC);
  static const Color goldBorder = secondary;
  static const Color lightGrey = surfaceMuted;

  // Legacy neumorphic aliases (kept for compatibility)
  static const Color neumorphicLight = Color(0xFFF7EEF6);
  static const Color neumorphicDark = Color(0xFFD9D0DB);
  static const Color neumorphicHighlight = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF2F9ED8);

  static const Color textPrimary = Color(0xFF26102A);
  static const Color textSecondary = Color(0xFF6E5870);
  static const Color textHint = Color(0xFF9A8BA0);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnGold = plum;

  // Category wayfinding — stays inside the purple/gold family
  static const Color academic = primary;
  static const Color social = Color(0xFFC03AAE);
  static const Color health = goldPressed;

  // LeadWallet — deep plum surfaces
  static const Color walletBg = Color(0xFF3A0034);
  static const Color walletBgDeep = Color(0xFF240020);
  static const Color walletBgMid = plum;
  static const Color walletGold = secondaryBright;
}

class AppTextStyles {
  static TextStyle get display => _nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: kIsWeb ? 0 : -0.4,
      );

  static TextStyle get heading1 => _nunito(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: kIsWeb ? 0 : -0.4,
      );

  static TextStyle get heading2 => _nunito(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: kIsWeb ? 0 : -0.2,
      );

  static TextStyle get heading3 => _nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// Alias used by some theme/* screens
  static TextStyle get heading => heading2;

  static TextStyle get subtitle => _nunito(
        fontSize: 16,
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
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get smallButton => _nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get sectionHeader => _nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: kIsWeb ? 0 : 0.1,
      );

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

  static const double radiusS = 10.0;
  static const double radiusM = 16.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 28.0;

  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;

  static const double buttonHeight = 52.0;
  static const double smallButtonHeight = 40.0;

  static const double cardElevation = 0.0;
}

class AppStrings {
  static const String appName = 'My Leadership Quest';

  static const String welcomeTitle = 'Embark on Your Leadership Quest!';
  static const String welcomeSubtitle =
      'Set goals, earn rewards, and become a leader!';
  static const String getStarted = 'Get Started';

  static const String goalIntroTitle = 'Set Your Goals';
  static const String goalIntroSubtitle =
      'Academic, Social, and Health goals will guide your journey.';

  static const String meetQuestorTitle = 'Meet Questor!';
  static const String meetQuestorSubtitle =
      'Your AI coach will guide you on your quest.';

  static const String home = 'Home';
  static const String goals = 'Goals';
  static const String challenges = 'Challenges';
  static const String victoryWall = 'Victory Wall';
  static const String profile = 'Profile';

  static const String academic = 'Academic';
  static const String social = 'Social';
  static const String health = 'Health';

  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String add = 'Add';
  static const String join = 'Join';
  static const String leave = 'Leave';
  static const String post = 'Post';
  static const String send = 'Send';

  static const String titlePlaceholder = 'Enter title...';
  static const String descriptionPlaceholder = 'Enter description...';
  static const String messagePlaceholder = 'Type a message...';
  static const String postPlaceholder = 'Share your victory...';

  static const String errorTitle = 'Oops!';
  static const String errorGeneric =
      'Something went wrong. Please try again.';
  static const String errorNoInternet = 'No internet connection.';
  static const String errorInvalidInput =
      'Please check your input and try again.';
}

class AppAssets {
  static const String mlqFoundationLogo = 'assets/images/MLQ_LOGO.png';

  static const String questorDefault = 'assets/images/questor.png';
  static const String questorHappy = 'assets/images/questor 2.png';
  static const String questorThinking = 'assets/images/questor 3.png';
  static const String questorExcited = 'assets/images/questor 4.png';
  static const String questorSad = 'assets/images/questor 5.png';

  static const String uiBgMesh = 'assets/images/ui_bg_mesh.png';
  static const String uiSparkles = 'assets/images/ui_sparkles.png';
  static const String uiTrialGift = 'assets/images/ui_trial_gift.png';
  static const String uiLockCrest = 'assets/images/ui_lock_crest.png';
}

/// Flat surface styles — purple-branded, soft shadow (replaces heavy neumorphic).
class NeumorphicStyles {
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: const Color(0xFF1F1A22).withValues(alpha: 0.04),
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  static BoxDecoration get standard => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      );

  static BoxDecoration get pressed => BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border),
      );

  static BoxDecoration get small => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      );

  static BoxDecoration get large => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: softShadow,
      );
}
