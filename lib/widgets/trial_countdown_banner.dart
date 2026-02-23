import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../screens/subscription/upgrade_subscription_screen.dart';

class TrialCountdownBanner extends StatelessWidget {
  final int daysRemaining;

  const TrialCountdownBanner({
    super.key,
    required this.daysRemaining,
  });

  Color _getGradientStartColor() {
    if (daysRemaining == 1) return const Color(0xFFE53935); // Red for urgency
    if (daysRemaining == 2) return const Color(0xFFFF6F00); // Deep orange
    return const Color(0xFFFB8C00); // Orange
  }

  Color _getGradientEndColor() {
    if (daysRemaining == 1) return const Color(0xFFFF5252); // Light red
    if (daysRemaining == 2) return const Color(0xFFFF8A50); // Light deep orange
    return const Color(0xFFFFB74D); // Light orange
  }

  IconData _getIcon() {
    if (daysRemaining == 1) return Icons.warning_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // Only show in last 3 days
    if (daysRemaining > 3 || daysRemaining <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_getGradientStartColor(), _getGradientEndColor()],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getGradientStartColor().withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UpgradeSubscriptionScreen(
                  planId: 'premium_monthly',
                  planName: 'Premium',
                  price: 5000,
                  duration: 'Monthly',
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon with animated pulse effect
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$daysRemaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            daysRemaining == 1 ? 'day left!' : 'days left',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        daysRemaining == 1
                            ? 'Your trial ends tomorrow'
                            : 'Subscribe to keep full access',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // CTA Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Upgrade',
                        style: TextStyle(
                          color: _getGradientStartColor(),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _getGradientStartColor(),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
