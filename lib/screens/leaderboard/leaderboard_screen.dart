import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_constants.dart';
import '../../widgets/mlq_ui_primitives.dart';
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
        // Pin the student's own row when it's likely below the fold.
        final ownIndex = restOfUsers.indexWhere((u) => u.id == currentUser?.id);
        final myIndex = ownIndex >= 5 ? ownIndex : -1;

        return Column(
          children: [
            const SizedBox(height: 4),
            // Top 3 Podium
            _buildTopThreePodium(topThree, showSchool: !isSchoolView),

            // Monthly reset notice - only show in first 3 days of month
            if (_shouldShowResetNotice)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.primary,
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

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.format_list_numbered_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Rankings',
                    style: AppTextStyles.sectionHeader
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),

            // Rest of the leaderboard
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: restOfUsers.length,
                itemBuilder: (context, index) {
                  final user = restOfUsers[index];
                  final rank = _rankFor(userProvider, user, index);

                  return _buildLeaderboardItem(
                    user,
                    rank,
                    currentUser?.id == user.id,
                    showSchool: !isSchoolView,
                  );
                },
              ),
            ),
            if (myIndex >= 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _buildLeaderboardItem(
                  restOfUsers[myIndex],
                  _rankFor(userProvider, restOfUsers[myIndex], myIndex),
                  true,
                  showSchool: !isSchoolView,
                  animate: false,
                ),
              ),
          ],
        );
      },
    );

    final page = Column(
      children: [
        Consumer<UserProvider>(
          builder: (context, userProvider, _) {
            final hasSchool = userProvider.user?.schoolId != null;
            final isSchoolView =
                userProvider.leaderboardView == LeaderboardView.school;
            final now = DateTime.now();
            final daysLeft =
                DateTime(now.year, now.month + 1).difference(now).inDays + 1;
            final reset = daysLeft <= 1 ? 'Resets tomorrow' : 'Resets in $daysLeft days';
            final scope = isSchoolView
                ? (_cachedSchoolName ?? 'My school')
                : 'All schools';

            return MlqHeroHeader(
              title: 'Monthly',
              highlight: 'Ranks',
              subtitle: '$scope · $reset',
              artAsset: null,
              showBack:
                  !widget.isInHomeScreen && Navigator.of(context).canPop(),
              action: Material(
                color: Colors.white.withOpacity(0.12),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Hall of Fame',
                  icon: const Icon(Icons.emoji_events_rounded,
                      color: AppColors.secondary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HallOfFameScreen(),
                    ),
                  ),
                ),
              ),
              bottom: hasSchool
                  ? MlqSegmentTabs(
                      labels: const ['All schools', 'My School'],
                      selected: isSchoolView ? 1 : 0,
                      onDark: true,
                      onChanged: (i) => userProvider.setLeaderboardView(
                          i == 1
                              ? LeaderboardView.school
                              : LeaderboardView.global),
                    )
                  : null,
            );
          },
        ),
        Expanded(child: content),
      ],
    );

    if (widget.isInHomeScreen) return page;
    return Scaffold(body: page);
  }

  int _rankFor(UserProvider userProvider, UserModel user, int index) {
    return userProvider.leaderboardView == LeaderboardView.school
        ? (user.rank ?? (index + 4))
        : (index + 4); // +4 because the podium shows the top 3
  }
  Widget _buildTopThreePodium(List<UserModel> topThree,
      {bool showSchool = false}) {
    final displayUsers = List<UserModel?>.from(topThree);
    while (displayUsers.length < 3) displayUsers.add(null);

    final first = displayUsers[0];
    final second = displayUsers[1];
    final third = displayUsers[2];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SizedBox(
        height: showSchool ? 292 : 270,
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
                      showSchool: showSchool,
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
                      showSchool: showSchool,
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
                      showSchool: showSchool,
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
    bool showSchool = false,
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
        if (showSchool) ...[
          const SizedBox(height: 2),
          SizedBox(
            width: isFirst ? 120 : 80,
            child: Text(
              (user.schoolName != null && user.schoolName!.trim().isNotEmpty)
                  ? user.schoolName!.trim()
                  : 'No school',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
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

  Widget _buildLeaderboardItem(
    UserModel user,
    int rank,
    bool isCurrentUser, {
    bool showSchool = false,
    bool animate = true,
  }) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.secondary.withOpacity(0.22)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? AppColors.secondary : AppColors.border,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withOpacity(isCurrentUser ? 0.10 : 0.04),
            blurRadius: isCurrentUser ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isCurrentUser ? AppColors.goldText : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            backgroundImage: user.avatarUrl != null
                ? (user.avatarUrl!.startsWith('assets/')
                    ? AssetImage(user.avatarUrl!) as ImageProvider
                    : NetworkImage(user.avatarUrl!))
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                UsernameWithCheckmark(
                  name: isCurrentUser ? '${user.name} (You)' : user.name,
                  isPremium: user.hasPremiumCheckmark,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  iconSize: 16,
                ),
                if (showSchool)
                  Text(
                    (user.schoolName != null &&
                            user.schoolName!.trim().isNotEmpty)
                        ? user.schoolName!.trim()
                        : 'No school',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 2),
              Text(
                '${user.monthlyXp} XP',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!animate) return row;
    return row
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (100 + (rank.clamp(0, 12) * 40)).ms,
        )
        .slideY(
          begin: 0.2,
          duration: 400.ms,
          delay: (100 + (rank.clamp(0, 12) * 40)).ms,
          curve: Curves.easeOutQuad,
        );
  }
}
