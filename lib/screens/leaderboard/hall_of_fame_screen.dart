import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../services/hall_of_fame_service.dart';
import '../../widgets/enhanced_app_bar.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../profile/user_profile_screen.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  bool _loading = true;
  List<HallOfFameEntry> _entries = [];
  String? _selectedMonthKey;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 900));
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries =
        await HallOfFameService.instance.fetchMonthlyWinners(rank: 1);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _selectedMonthKey = _selectedMonthKey ??
          (entries.isNotEmpty ? entries.first.monthKey : null);
      _loading = false;
    });

    if (entries.isNotEmpty) {
      try {
        _confetti.play();
      } catch (_) {}
    }
  }

  HallOfFameEntry? get _selectedEntry {
    if (_selectedMonthKey == null) return null;
    try {
      return _entries.firstWhere((e) => e.monthKey == _selectedMonthKey);
    } catch (_) {
      return _entries.isNotEmpty ? _entries.first : null;
    }
  }

  String _prettyMonth(String monthKey) {
    // monthKey: YYYY-MM
    try {
      final parts = monthKey.split('-');
      if (parts.length != 2) return monthKey;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final label = months[(month - 1).clamp(0, 11)];
      return '$label $year';
    } catch (_) {
      return monthKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEntry;

    return Scaffold(
      appBar: const EnhancedAppBar(
        title: 'Hall of Fame',
        showBackButton: true,
        showNotificationBadge: false,
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 14),
            if (_loading) ...[
              _buildLoadingState(),
            ] else if (_entries.isEmpty) ...[
              _buildEmptyState(),
            ] else ...[
              _buildMonthCarousel(),
              const SizedBox(height: 12),
              if (selected != null) ...[
                _buildChampionSpotlight(selected),
                const SizedBox(height: 12),
              ],
              ..._entries.map(_buildMonthWinnerCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCarousel() {
    final keys = _entries.map((e) => e.monthKey).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Pick a month',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${keys.length} months',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final key = keys[index];
                final selected = key == _selectedMonthKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() => _selectedMonthKey = key);
                    try {
                      _confetti.play();
                    } catch (_) {}
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.95),
                                AppColors.secondary.withOpacity(0.95),
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                AppColors.neumorphicHighlight.withOpacity(0.95),
                                AppColors.surface.withOpacity(0.95),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withOpacity(0.18)
                            : AppColors.primary.withOpacity(0.10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selected
                              ? AppColors.primary.withOpacity(0.18)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _prettyMonth(key),
                        style: AppTextStyles.caption.copyWith(
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildChampionSpotlight(HallOfFameEntry e) {
    final crownColor = const Color(0xFFFFD700);
    final monthLabel = _prettyMonth(e.monthKey);

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0B1220),
                AppColors.primary.withOpacity(0.95),
                AppColors.secondary.withOpacity(0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _showChampionPreview(e),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            crownColor.withOpacity(0.95),
                            crownColor.withOpacity(0.60),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: crownColor.withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Champion Spotlight',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            monthLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Tap',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildAvatar(e.avatarUrl, e.name),
                          Positioned(
                            bottom: -8,
                            right: -10,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: crownColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: crownColor.withOpacity(0.35),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.stars_rounded,
                                  size: 16, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (e.name == null || e.name!.trim().isEmpty)
                                  ? 'Champion'
                                  : e.name!.trim(),
                              style: AppTextStyles.heading2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (e.schoolName == null ||
                                      e.schoolName!.trim().isEmpty)
                                  ? 'Global Winner'
                                  : e.schoolName!.trim(),
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white.withOpacity(0.90),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              crownColor.withOpacity(0.95),
                              crownColor.withOpacity(0.70),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'XP',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.monthlyXp ?? 0}',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 320.ms)
            .slideY(begin: 0.04, end: 0)
            .shimmer(
              duration: 1600.ms,
              delay: 300.ms,
              color: Colors.white.withOpacity(0.18),
            ),
        Positioned(
          top: 6,
          right: 0,
          left: 0,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 16,
            minBlastForce: 6,
            maxBlastForce: 12,
            gravity: 0.25,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFD700),
              Color(0xFF00C4FF),
              Color(0xFFA1E44D),
              Color(0xFFFF70A6),
              Color(0xFFFF9505),
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }

  void _showChampionPreview(HallOfFameEntry e) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final cached = userProvider.getUserById(e.userId);
    final user = cached ??
        UserModel(
          id: e.userId,
          name: (e.name == null || e.name!.trim().isEmpty)
              ? 'Champion'
              : e.name!.trim(),
          age: 0,
          avatarUrl: e.avatarUrl,
          monthlyXp: e.monthlyXp ?? 0,
          xp: 0,
          coins: 0.0,
          badges: const [],
          interests: const [],
          schoolName: e.schoolName,
        );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildAvatar(user.avatarUrl, user.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_prettyMonth(e.monthKey)} Champion',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${e.monthlyXp ?? 0} XP',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: user),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_rounded),
                      label: const Text('View Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            AppColors.primary.withOpacity(0.95),
            const Color(0xFFFFD700).withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFFFA500),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hall of Fame',
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Legends who conquered the month',
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFFFFD700).withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    size: 16, color: Color(0xFFFFD700)),
                const SizedBox(width: 6),
                Text(
                  'Only the #1 champion each month',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.06, end: 0).shimmer(
          duration: 2000.ms,
          delay: 500.ms,
          color: const Color(0xFFFFD700).withOpacity(0.3),
        );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(5, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 160,
                      color: Colors.grey.withOpacity(0.18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (60 * i).ms, duration: 240.ms);
      }),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withOpacity(0.2),
                  AppColors.secondary.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 56,
              color: const Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No champions yet',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'The first monthly champion will be crowned at the start of next month!',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 20,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How to become a champion',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipRow('Complete daily goals consistently'),
                _buildTipRow('Finish mini-courses'),
                _buildTipRow('Participate in challenges'),
                _buildTipRow('Earn the most XP in a month'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('View Leaderboard'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthWinnerCard(HallOfFameEntry e) {
    final crownColor = const Color(0xFFFFD700);
    final monthLabel = _prettyMonth(e.monthKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.background.withOpacity(0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildAvatar(e.avatarUrl, e.name),
              Positioned(
                top: -8,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: crownColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: crownColor.withOpacity(0.45),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (e.name == null || e.name!.trim().isEmpty)
                      ? 'Champion'
                      : e.name!.trim(),
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.school_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (e.schoolName == null || e.schoolName!.trim().isEmpty)
                            ? 'Global Winner'
                            : e.schoolName!.trim(),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                Text(
                  'XP',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.monthlyXp ?? 0}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideX(begin: 0.03, end: 0);
  }

  Widget _buildAvatar(String? url, String? name) {
    final bg = AppColors.background;
    final initial = (name != null && name.trim().isNotEmpty)
        ? name.trim().characters.first.toUpperCase()
        : '⭐';

    if (url == null || url.trim().isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: bg,
        child: Text(
          initial,
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: bg,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }
}
