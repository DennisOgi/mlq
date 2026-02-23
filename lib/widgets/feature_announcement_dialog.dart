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
  
  // In-memory cache to prevent showing during same session while prefs load
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
  });

  /// Check if this feature announcement has been shown before
  static Future<bool> shouldShow(String featureKey) async {
    // Check in-memory cache first (prevents race conditions)
    if (_shownThisSession.contains(featureKey)) return false;
    if (_currentlyShowing.contains(featureKey)) return false;
    
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('feature_seen_$featureKey') ?? false);
  }

  /// Mark this feature announcement as shown
  static Future<void> markAsShown(String featureKey) async {
    _shownThisSession.add(featureKey);
    _currentlyShowing.remove(featureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_seen_$featureKey', true);
  }

  /// Show the dialog if it hasn't been shown before
  static Future<void> showIfNeeded({
    required BuildContext context,
    required String featureKey,
    required String title,
    required String description,
    required List<String> highlights,
    IconData icon = Icons.new_releases,
    Color? accentColor,
    VoidCallback? onExplore,
  }) async {
    // Quick check for in-memory cache
    if (_shownThisSession.contains(featureKey)) return;
    if (_currentlyShowing.contains(featureKey)) return;
    
    if (await shouldShow(featureKey)) {
      _currentlyShowing.add(featureKey);
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => FeatureAnnouncementDialog(
            featureKey: featureKey,
            title: title,
            description: description,
            highlights: highlights,
            icon: icon,
            accentColor: accentColor,
            onExplore: onExplore,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button row
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () async {
                  await markAsShown(featureKey);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                ),
              ),
            ),
            // New badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'NEW FEATURE',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 48),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              title,
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Description
            Text(
              description,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Highlights
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: highlights.map((highlight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: color, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          highlight,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await markAsShown(featureKey);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      await markAsShown(featureKey);
                      if (context.mounted) Navigator.pop(context);
                      onExplore?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Explore Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Predefined feature announcements
class FeatureAnnouncements {
  static const String communitiesFeatureKey = 'communities_v1';
  
  /// Show the Communities feature announcement
  static Future<void> showCommunitiesAnnouncement(
    BuildContext context, {
    VoidCallback? onExplore,
  }) async {
    await FeatureAnnouncementDialog.showIfNeeded(
      context: context,
      featureKey: communitiesFeatureKey,
      title: 'Communities',
      description: 'Connect with like-minded leaders! Create or join communities for your school, club, team, or interest group.',
      highlights: [
        'Create your own community (Premium)',
        'Join communities and chat with members',
        'AI-powered mini-course generation',
        'Build your leadership network',
      ],
      icon: Icons.people_alt_rounded,
      accentColor: AppColors.primary,
      onExplore: onExplore,
    );
  }
}
