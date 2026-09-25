import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class TrialCountdownBanner extends StatelessWidget {
  final int daysRemaining;

  const TrialCountdownBanner({
    super.key,
    required this.daysRemaining,
  });

  bool get _urgent => daysRemaining <= 3;

  Color get _start => _urgent
      ? const Color(0xFFE53935)
      : AppColors.primary;

  Color get _end => _urgent
      ? const Color(0xFFFF8A50)
      : const Color(0xFFC218A8);

  @override
  Widget build(BuildContext context) {
    if (daysRemaining <= 0) return const SizedBox.shrink();

    final dayLabel = daysRemaining == 1 ? 'day' : 'days';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_start, _end],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _start.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/subscription-management');
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _urgent ? Icons.warning_rounded : Icons.timer_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mini-courses · $daysRemaining $dayLabel left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _urgent
                            ? 'Subscribe to keep mini-courses, plus the library, challenges, LeadWallet, and Victory Wall posts.'
                            : 'Goals, Gratitude Jar, and the leaderboard stay free. Subscribe anytime for the full app.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Plans',
                    style: TextStyle(
                      color: _start,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
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
