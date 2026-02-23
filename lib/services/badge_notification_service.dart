import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/badge_model.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_colors.dart';
import './badge_seen_store.dart';

class BadgeNotificationService {
  static final BadgeNotificationService _instance = BadgeNotificationService._internal();
  
  factory BadgeNotificationService() => _instance;
  
  BadgeNotificationService._internal();
  
  OverlayEntry? _overlayEntry;
  bool _isShowingNotification = false;
  final Set<String> _recentlyShownBadges = {}; // Track recently shown badges
  DateTime? _lastNotificationTime;
  
  void showBadgeEarnedNotification(BuildContext context, BadgeModel badge) async {
    if (_isShowingNotification) return;
    
    final userId = badge.userId;
    final seenKey = (badge.id.isNotEmpty ? badge.id : badge.name);
    
    // Check if already seen in database
    if (await BadgeSeenStore.hasSeen(userId, seenKey)) {
      return;
    }
    
    // Additional debouncing: prevent showing same badge within 10 seconds
    final badgeKey = '$userId:$seenKey';
    if (_recentlyShownBadges.contains(badgeKey)) {
      return;
    }
    
    // Rate limiting: don't show more than 1 notification per 2 seconds
    final now = DateTime.now();
    if (_lastNotificationTime != null && 
        now.difference(_lastNotificationTime!).inSeconds < 2) {
      return;
    }

    _isShowingNotification = true;
    _recentlyShownBadges.add(badgeKey);
    _lastNotificationTime = now;
    
    // Clear from recent list after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      _recentlyShownBadges.remove(badgeKey);
    });

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildBadgeNotification(badge),
    );

    Overlay.of(context).insert(_overlayEntry!);
    await BadgeSeenStore.markSeen(userId, seenKey);

    Future.delayed(const Duration(seconds: 5), () {
      _removeOverlay();
    });
  }
  
  Widget _buildBadgeNotification(BadgeModel badge) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Badge Earned!',
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Image.asset(
                    badge.imageAsset,
                    height: 100,
                    width: 100,
                  )
                  .animate()
                  .scale(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .fadeIn(duration: const Duration(milliseconds: 1000)),
                  const SizedBox(height: 16),
                  Text(
                    badge.name,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.description ?? badge.defaultDescription,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _removeOverlay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Awesome!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(
      begin: -1,
      end: 0,
      duration: 500.ms,
      curve: Curves.easeOutBack,
    );
  }
  
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowingNotification = false;
    }
  }
}
