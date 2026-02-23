import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/enhanced_app_bar.dart';
import '../../widgets/username_with_checkmark.dart';
import '../../providers/providers.dart';
import 'package:my_leadership_quest/screens/profile/profile_screen.dart';
import '../../services/hall_of_fame_service.dart';
import 'hall_of_fame_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final bool isInHomeScreen;

  const LeaderboardScreen({super.key, this.isInHomeScreen = false});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String? _cachedSchoolName;
  String? _currentMonthChampionId;

  /// Check if we should show the monthly reset notice
  /// Shows only during the first 3 days of each month
  bool get _shouldShowResetNotice {
    final now = DateTime.now();
    return now.day <= 3;
  }

  @override
  void initState() {
    super.initState();
    // Refresh leaderboard data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Default to Global leaderboard on navigation; user can switch to My School via the existing toggle
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setLeaderboardView(LeaderboardView.global);
      _refreshLeaderboardData();
      _loadCurrentMonthChampion();
    });
  }

  Future<void> _loadCurrentMonthChampion() async {
    try {
      final now = DateTime.now();
      final monthKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final winner = await HallOfFameService.instance
          .fetchWinnerForMonth(monthKey: monthKey, rank: 1);
      if (!mounted) return;
      setState(() {
        _currentMonthChampionId = winner?.userId;
      });
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _refreshLeaderboardData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.refreshLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    // Create the main content widget using Consumer
    final content = Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final currentUser = userProvider.user;
        final leaderboardUsers = userProvider.getLeaderboardUsers();
        final hasSchool = currentUser?.schoolId != null;
        final isSchoolView =
            userProvider.leaderboardView == LeaderboardView.school;
        // Cache non-empty school name to avoid flicker reverting to a generic label
        final schoolName = currentUser?.schoolName?.trim();
        if (schoolName != null && schoolName.isNotEmpty) {
          _cachedSchoolName = schoolName;
        }

        // Handle no school selected in School view
        if (isSchoolView && !hasSchool) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_outlined,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No school selected',
                    style: AppTextStyles.heading2
                        .copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your school in Profile to view your school leaderboard.',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          userProvider
                              .setLeaderboardView(LeaderboardView.global);
                        },
                        child: const Text('View Global Leaderboard'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _refreshLeaderboardData();
                        },
                        child: const Text('Retry'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // When there is simply no data, show an empty state with retry instead of infinite spinner
        if (leaderboardUsers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.leaderboard_outlined,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No leaderboard data yet',
                    style: AppTextStyles.heading2
                        .copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We couldn\'t load the ${isSchoolView ? 'school' : 'global'} leaderboard. Please try again.',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshLeaderboardData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Split into top 3 and the rest
        final topThree = leaderboardUsers.take(3).toList();
        final restOfUsers = leaderboardUsers.skip(3).toList();

        return Column(
          children: [
            // Add a little breathing space under the app bar
            const SizedBox(height: 12),
            if (userProvider.leaderboardView == LeaderboardView.school)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: hasSchool &&
                        (_cachedSchoolName != null &&
                            _cachedSchoolName!.isNotEmpty)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.95),
                              AppColors.secondary.withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                              color: Colors.white.withOpacity(0.18), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _cachedSchoolName!,
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  Leaderboard',
                                      style: AppTextStyles.body.copyWith(
                                        color: Colors.white.withOpacity(0.95),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: -0.1, end: 0, curve: Curves.easeOut)
                    : const SizedBox.shrink(),
              ),
            const SizedBox(height: 4),
            // Top 3 Podium
            _buildTopThreePodium(topThree),

            // Monthly reset notice - only show in first 3 days of month
            if (_shouldShowResetNotice)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.tertiary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.tertiary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎉 New month, fresh rankings! Everyone starts at 0 XP.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

            // Divider with "Rankings" text
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(thickness: 2),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Rankings',
                      style: AppTextStyles.heading1.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(thickness: 2),
                  ),
                ],
              ),
            ),

            // Rest of the leaderboard
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: restOfUsers.length,
                itemBuilder: (context, index) {
                  final user = restOfUsers[index];
                  final rank = userProvider.leaderboardView ==
                          LeaderboardView.school
                      ? (user.rank ?? (index + 4))
                      : (index + 4); // +4 because we already displayed top 3

                  return _buildLeaderboardItem(
                      user, rank, currentUser?.id == user.id);
                },
              ),
            ),
          ],
        );
      },
    );

    // If this screen is displayed within the HomeScreen, return just the content with a header
    if (widget.isInHomeScreen) {
      return Column(
        children: [
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Monthly Leaderboard',
                style:
                    AppTextStyles.heading1.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    // Return the full Scaffold when shown as a standalone screen
    return Scaffold(
      appBar: EnhancedAppBar(
        title: 'Monthly Leaderboard',
        showNotificationBadge: false,
        backgroundColor: AppColors.primary,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              final isSchoolView =
                  userProvider.leaderboardView == LeaderboardView.school;
              final hasSchool = userProvider.user?.schoolId != null;

              return Row(
                children: [
                  IconButton(
                    tooltip: 'Global leaderboard',
                    icon: Icon(
                      Icons.public,
                      color: !isSchoolView ? Colors.white : Colors.white70,
                    ),
                    onPressed: () =>
                        userProvider.setLeaderboardView(LeaderboardView.global),
                  ),
                  if (hasSchool)
                    IconButton(
                      tooltip: 'My school leaderboard',
                      icon: Icon(
                        Icons.school,
                        color: isSchoolView ? Colors.white : Colors.white70,
                      ),
                      onPressed: () => userProvider
                          .setLeaderboardView(LeaderboardView.school),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: content,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'hall_of_fame_fab',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HallOfFameScreen(),
              ),
            );
          },
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.black,
          elevation: 0,
          child: const Icon(Icons.emoji_events_rounded),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(List<UserModel> topThree) {
    final displayUsers = List<UserModel?>.from(topThree);
    while (displayUsers.length < 3) displayUsers.add(null);

    final first = displayUsers[0];
    final second = displayUsers[1];
    final third = displayUsers[2];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SizedBox(
        height: 270,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2nd Place
            if (second != null)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 12),
                    _buildPodiumItem(
                      user: second,
                      rank: 2,
                      color: const Color(0xFFC0C0C0), // Silver
                      height: 70,
                    ),
                  ],
                ),
              )
            else
              const Expanded(child: SizedBox()),

            // 1st Place
            Expanded(
              flex: 2,
              child: first != null
                  ? _buildPodiumItem(
                      user: first,
                      rank: 1,
                      color: const Color(0xFFFFD700), // Gold
                      height: 90,
                      isFirst: true,
                      isHallOfFameChampion: _currentMonthChampionId != null &&
                          _currentMonthChampionId == first.id,
                    )
                  : const SizedBox(),
            ),

            // 3rd Place
            if (third != null)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 12),
                    _buildPodiumItem(
                      user: third,
                      rank: 3,
                      color: const Color(0xFFCD7F32), // Bronze
                      height: 55,
                    ),
                  ],
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 100.ms);
  }

  Widget _buildPodiumItem({
    required UserModel user,
    required int rank,
    required Color color,
    required double height,
    bool isFirst = false,
    bool isHallOfFameChampion = false,
  }) {
    final avatarSize = isFirst ? 80.0 : 60.0;
    final fontSize = isFirst ? 16.0 : 14.0;
    final podiumLabel = rank == 1
        ? 'Champion'
        : rank == 2
            ? '2nd Place'
            : '3rd Place';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Subtle glow ring behind avatar
            if (isFirst)
              Positioned(
                top: -4,
                left: -4,
                right: -4,
                bottom: -4,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).custom(
                      duration: 2000.ms,
                      builder: (context, value, child) => Opacity(
                        opacity: 0.4 + (value * 0.3),
                        child: child,
                      ),
                    ),
              ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 4 : 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user.avatarUrl != null
                    ? (user.avatarUrl!.startsWith('assets/')
                        ? AssetImage(user.avatarUrl!) as ImageProvider
                        : NetworkImage(user.avatarUrl!))
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: avatarSize * 0.4,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
            // Trophy icon for champion with enhanced animation
            if (isFirst)
              Positioned(
                top: -28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sparkle effects
                    ...List.generate(
                      3,
                      (i) => Positioned(
                        left: (i - 1) * 12.0,
                        top: (i % 2) * 8.0 - 4,
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.amber.withOpacity(0.7),
                          size: 10,
                        )
                            .animate(
                              onPlay: (c) => c.repeat(reverse: true),
                              delay: (i * 300).ms,
                            )
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.2, 1.2),
                              duration: 800.ms,
                            )
                            .fadeIn(duration: 400.ms),
                      ),
                    ),
                    Icon(
                      Icons.emoji_events,
                      color: const Color(0xFFFFD700),
                      size: 36,
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.08, 1.08),
                          duration: 1200.ms,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),

            if (isFirst && isHallOfFameChampion)
              Positioned(
                top: -58,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFF9505),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.06, 1.06),
                      duration: 1400.ms,
                      curve: Curves.easeInOut,
                    )
                    .shimmer(
                      duration: 1800.ms,
                      color: Colors.white.withOpacity(0.35),
                    ),
              ),
            // Rank badge
            Positioned(
              bottom: -10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
                  .animate(delay: (rank * 100 + 400).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.5, end: 0, duration: 300.ms),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Constrain name width to prevent overflow
        SizedBox(
          width: isFirst ? 120 : 80,
          child: Text(
            user.name,
            style: AppTextStyles.bodyBold.copyWith(
              fontSize: fontSize,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        // XP badge with subtle floating animation - constrained to prevent overflow
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isFirst ? 100 : 80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${user.monthlyXp} XP',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: (rank * 100 + 600).ms,
            )
            .moveY(
              begin: 0,
              end: -2,
              duration: 1500.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 12),
        // Podium stand with shimmer effect
        Stack(
          children: [
            Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(isFirst ? 0.95 : 0.9),
                    color.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  podiumLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Shimmer overlay on podium
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().scale(
          duration: 500.ms,
          curve: Curves.easeOutBack,
          delay: (rank * 100 + 200).ms,
          alignment: Alignment.bottomCenter,
        );
  }

  Widget _buildLeaderboardItem(UserModel user, int rank, bool isCurrentUser) {
    // Accent color cycles for variety (non-podium ranks)
    final accentPalette = <Color>[
      Colors.teal,
      Colors.deepOrange,
      Colors.indigo,
      Colors.green,
      Colors.pink,
      Colors.blue,
    ];
    final accentColor = isCurrentUser
        ? AppColors.primary
        : accentPalette[rank % accentPalette.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isCurrentUser
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.neumorphicHighlight.withOpacity(0.85)),
            (isCurrentUser
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surface.withOpacity(0.9)),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withOpacity(0.4)
              : accentColor.withOpacity(0.18),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? AppColors.primary.withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            blurRadius: isCurrentUser ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accent bar
            Container(
              width: 5,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            // Rank number
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? AppColors.primary
                    : accentColor.withOpacity(0.15),
                border: Border.all(
                    color: accentColor.withOpacity(isCurrentUser ? 0.0 : 0.6),
                    width: 1),
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser ? Colors.white : accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User avatar (only if provided) — no initials placeholder
            if (user.avatarUrl != null)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: user.avatarUrl!.startsWith('assets/')
                    ? AssetImage(user.avatarUrl!) as ImageProvider
                    : NetworkImage(user.avatarUrl!),
              ),
          ],
        ),
        title: UsernameWithCheckmark(
          name: user.name,
          isPremium: user.hasPremiumCheckmark,
          style: AppTextStyles.bodyBold.copyWith(
            color: AppColors.primary,
          ),
          iconSize: 16,
        ),
        // Remove badges/no badges text from leaderboard
        subtitle: null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accentColor.withOpacity(0.85),
                AppColors.secondary.withOpacity(0.85)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                '${user.monthlyXp} XP',
                style: AppTextStyles.bodyBold.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (100 + (rank * 50)).ms,
        )
        .slideY(
          begin: 0.2,
          duration: 400.ms,
          delay: (100 + (rank * 50)).ms,
          curve: Curves.easeOutQuad,
        );
  }
}
