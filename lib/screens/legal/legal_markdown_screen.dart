import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalMarkdownScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalMarkdownScreen({super.key, required this.title, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Unable to load content.'));
            }
            return Markdown(
              data: snapshot.data!,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                p: const TextStyle(fontSize: 14, height: 1.4),
              ),
              onTapLink: (text, href, title) {
                if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              },
              padding: const EdgeInsets.all(16),
            );
          },
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalMarkdownScreen(
        title: 'Terms & Conditions',
        assetPath: 'assets/legal/terms.md',
      );
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalMarkdownScreen(
        title: 'Privacy Policy',
        assetPath: 'assets/legal/privacy.md',
      );
}

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const LegalMarkdownScreen(
        title: 'Refund Policy',
        assetPath: 'assets/legal/refund.md',
      );
}
