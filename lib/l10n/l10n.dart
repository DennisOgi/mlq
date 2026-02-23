import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// Extension for easy access to AppLocalizations
extension LocalizationExtension on BuildContext {
  /// Get the AppLocalizations instance
  /// Usage: context.l10n.welcomeBack
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Shorthand alias for l10n
  AppLocalizations get tr => AppLocalizations.of(this)!;
}

/// Supported locales for the app
class L10n {
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('fr'), // French
  ];

  /// Get locale display name
  static String getLocaleName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      default:
        return languageCode;
    }
  }

  /// Get locale flag emoji
  static String getFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇬🇧';
      case 'fr':
        return '🇫🇷';
      default:
        return '🌐';
    }
  }
}
