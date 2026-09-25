import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// A dialog that announces new features to users.
/// Shows only once per feature (tracked via SharedPreferences).
class FeatureAnnouncementDialog extends StatelessWidget {
  final String featureKey;
  final String title;
  final String description;
  final List<String> highlights;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onExplore;
  final String exploreLabel;
  final String dismissLabel;

  static final Set<String> _shownThisSession = {};
  static final Set<String> _currentlyShowing = {};

  const FeatureAnnouncementDialog({
    super.key,
    required this.featureKey,
    required this.title,
    required this.description,
    required this.highlights,
    this.icon = Icons.new_releases,
    this.accentColor,
    this.onExplore,
    this.exploreLabel = 'Explore Now',
    this.dismissLabel = 'Got it',
  });

  static Future<bool> shouldShow(String featureKey) async {
    if (_shownThisSession.contains(featureKey)) return false;
    if (_currentlyShowing.contains(featureKey)) return false;

    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('feature_seen_$featureKey') ?? false);
  }

  static Future<void> markAsShown(String featureKey) async {
    _shownThisSession.add(featureKey);
    _currentlyShowing.remove(featureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_seen_$featureKey', true);
  }

  static Future<void> showIfNeeded({
    required BuildContext context,
    required String featureKey,
    required String title,
    required String description,
    required List<String> highlights,
    IconData icon = Icons.new_releases,
    Color? accentColor,
    VoidCallback? onExplore,
    String exploreLabel = 'Explore Now',
    String dismissLabel = 'Got it',
  }) async {
    if (_shownThisSession.contains(featureKey)) return;
    if (_currentlyShowing.contains(featureKey)) return;

    if (await shouldShow(featureKey)) {
      _currentlyShowing.add(featureKey);
      try {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black.withValues(alpha: 0.55),
            builder: (ctx) => FeatureAnnouncementDialog(
              featureKey: featureKey,
              title: title,
              description: description,
              highlights: highlights,
              icon: icon,
              accentColor: accentColor,
              onExplore: onExplore,
              exploreLabel: exploreLabel,
              dismissLabel: dismissLabel,
            ),
          );
        }
      } finally {
        _currentlyShowing.remove(featureKey);
        await markAsShown(featureKey);
      }
    }
  }

  Future<void> _dismiss(BuildContext context, {bool explore = false}) async {
    if (context.mounted) Navigator.pop(context);
    await markAsShown(featureKey);
    if (explore) onExplore?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final maxWidth = isWide ? 520.0 : (size.width - 40).clamp(280.0, 400.0);
    final maxHeight = size.height * (isWide ? 0.78 : 0.86);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 20,
        vertical: isWide ? 40 : 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isWide ? 28 : 20,
                  16,
                  12,
                  isWide ? 24 : 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, AppColors.primaryDark, 0.35)!,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _dismiss(context),
                          tooltip: 'Close',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    SizedBox(height: isWide ? 12 : 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: isWide ? 64 : 56,
                          height: isWide ? 64 : 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: isWide ? 26 : 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable body — bounded max height, no Flexible/Intrinsic
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (maxHeight - 220).clamp(120.0, maxHeight),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 28 : 20,
                    isWide ? 24 : 18,
                    isWide ? 28 : 20,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                          fontSize: isWide ? 15.5 : 14.5,
                        ),
                      ),
                      SizedBox(height: isWide ? 20 : 16),
                      if (isWide)
                        _HighlightsGrid(highlights: highlights, color: color)
                      else
                        _HighlightsList(highlights: highlights, color: color),
                    ],
                  ),
                ),
              ),

              // Sticky actions
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isWide ? 28 : 20,
                  12,
                  isWide ? 28 : 20,
                  isWide ? 22 : 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                  ),
                ),
                child: isWide
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: () => _dismiss(context),
                            child: Text(
                              dismissLabel,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 200,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _dismiss(context, explore: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                exploreLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _dismiss(context, explore: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                exploreLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _dismiss(context),
                            child: Text(
                              dismissLabel,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightsList extends StatelessWidget {
  final List<String> highlights;
  final Color color;

  const _HighlightsList({required this.highlights, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final item in highlights) ...[
            _HighlightRow(text: item, color: color),
            if (item != highlights.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HighlightsGrid extends StatelessWidget {
  final List<String> highlights;
  final Color color;

  const _HighlightsGrid({required this.highlights, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 420;
        final itemWidth = twoCol
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in highlights)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _HighlightRow(text: item, color: color),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final String text;
  final Color color;

  const _HighlightRow({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Predefined feature announcements
class FeatureAnnouncements {
  static const String communitiesFeatureKey = 'communities_v1';
  // v2 = redesigned responsive sheet (re-shows once for users who saw v1)
  static const String leadWalletFeatureKey = 'lead_wallet_v2';

  static Future<void> showCommunitiesAnnouncement(
    BuildContext context, {
    VoidCallback? onExplore,
  }) async {
    await FeatureAnnouncementDialog.showIfNeeded(
      context: context,
      featureKey: communitiesFeatureKey,
      title: 'Communities',
      description:
          'Connect with like-minded leaders. Create or join communities for your school, club, team, or interest group.',
      highlights: [
        'Create your own community (Premium)',
        'Join communities and chat with members',
        'AI-powered mini-course generation',
        'Build your leadership network',
      ],
      icon: Icons.people_alt_rounded,
      accentColor: AppColors.primary,
      onExplore: onExplore,
      exploreLabel: 'Open Communities',
    );
  }

  static Future<void> showLeadWalletOnboarding(
    BuildContext context, {
    VoidCallback? onExplore,
  }) async {
    await FeatureAnnouncementDialog.showIfNeeded(
      context: context,
      featureKey: leadWalletFeatureKey,
      title: 'Meet LeadWallet',
      description:
          'Your in-app cash wallet for real naira rewards from challenges and prizes.',
      highlights: [
        'Earn real cash from rewards',
        'One-time parent activation',
        'Withdraw to a Nigerian bank',
        'Track balance and savings',
      ],
      icon: Icons.account_balance_wallet_rounded,
      accentColor: AppColors.primary,
      onExplore: onExplore,
      exploreLabel: 'Set up LeadWallet',
      dismissLabel: 'Maybe later',
    );
  }
}
