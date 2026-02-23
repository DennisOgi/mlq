import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/l10n.dart';

/// A widget for selecting the app language
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return ListTile(
          leading: const Icon(Icons.language),
          title: Text(context.l10n.language),
          subtitle: Text(
            '${LocaleProvider.getLocaleFlag(localeProvider.locale)} ${LocaleProvider.getLocaleName(localeProvider.locale)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, localeProvider),
        );
      },
    );
  }

  void _showLanguageDialog(
      BuildContext context, LocaleProvider localeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LocaleProvider.supportedLocales.map((locale) {
            final isSelected = localeProvider.locale == locale;
            return ListTile(
              leading: Text(
                LocaleProvider.getLocaleFlag(locale),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(LocaleProvider.getLocaleName(locale)),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              selected: isSelected,
              onTap: () {
                localeProvider.setLocale(locale);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }
}

/// A compact language toggle button
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return IconButton(
          icon: Text(
            LocaleProvider.getLocaleFlag(localeProvider.locale),
            style: const TextStyle(fontSize: 20),
          ),
          tooltip: context.l10n.language,
          onPressed: () => localeProvider.toggleLocale(),
        );
      },
    );
  }
}

/// A dropdown for language selection
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return DropdownButton<Locale>(
          value: localeProvider.locale,
          underline: const SizedBox(),
          items: LocaleProvider.supportedLocales.map((locale) {
            return DropdownMenuItem(
              value: locale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(LocaleProvider.getLocaleFlag(locale)),
                  const SizedBox(width: 8),
                  Text(LocaleProvider.getLocaleName(locale)),
                ],
              ),
            );
          }).toList(),
          onChanged: (locale) {
            if (locale != null) {
              localeProvider.setLocale(locale);
            }
          },
        );
      },
    );
  }
}
