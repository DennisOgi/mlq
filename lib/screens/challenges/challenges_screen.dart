import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../utils/entitlements.dart';
import '../../widgets/feature_lock_card.dart';
import '../lead_market/lead_market_sponsors_screen.dart';

class ChallengesScreen extends StatefulWidget {
  final bool isInHomeScreen;

  /// 0 = Open, 1 = Joined, 2 = Completed
  final int initialTabIndex;

  const ChallengesScreen({
    super.key,
    this.isInHomeScreen = false,
    this.initialTabIndex = 0,
  });

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['Open', 'Joined', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChallengeProvider>(context, listen: false)
          .refreshChallenges();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openChallengeDetail(BuildContext context, ChallengeModel challenge) {
    final challengeProvider =
        Provider.of<ChallengeProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isJoined = challengeProvider.isParticipatingIn(challenge.id);
    final isPremiumUser = userProvider.hasPaidAccess;

    if (challenge.isPremium && !isJoined && !isPremiumUser) {
      _showUpgradeDialog(context, challenge);
    } else {
      Navigator.pushNamed(context, '/challenge-detail',
          arguments: challenge.id);
    }
  }

  void _showUpgradeDialog(BuildContext context, ChallengeModel challenge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Premium Challenge'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is a premium challenge that requires a subscription to participate.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium Benefits:', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 8),
                  Text('• Unlimited premium challenges',
                      style: AppTextStyles.body),
                  Text('• Extra coins and rewards', style: AppTextStyles.body),
                  Text('• Priority support', style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/subscription-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.textOnGold,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challengeProvider = Provider.of<ChallengeProvider>(context);

    if (challengeProvider.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(challengeProvider.errorMessage)),
        );
      });
    }

    final joinedCount = challengeProvider.participatingChallenges
        .where((c) => !challengeProvider.isCompleted(c.id))
        .length;

    final header = MlqHeroHeader(
      title: 'Quest',
      highlight: 'Challenges',
      subtitle: joinedCount > 0
          ? '$joinedCount in progress · build habits, earn coins and badges'
          : 'Build habits, earn coins and badges',
      showBack: !widget.isInHomeScreen && Navigator.of(context).canPop(),
      artAsset: null,
      action: Material(
        color: Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Lead Market',
          icon: const Icon(Icons.shopping_bag_rounded,
              color: AppColors.secondary),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LeadMarketSponsorsScreen(),
            ),
          ),
        ),
      ),
      bottom: MlqSegmentTabs(
        labels: _tabs,
        selected: _tabController.index,
        onDark: true,
        onChanged: (i) => _tabController.animateTo(i),
      ),
    );

    final body = challengeProvider.isLoading
        ? const MlqLoadingState(message: 'Loading challenges...')
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOpen(challengeProvider),
              _buildJoined(challengeProvider),
              _buildCompleted(challengeProvider),
            ],
          );

    final content = Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );

    if (widget.isInHomeScreen) return content;
    return Scaffold(body: content);
  }

  Widget _buildOpen(ChallengeProvider provider) {
    final user = Provider.of<UserProvider>(context).user;
    if (!Entitlements.hasPaidAccess(user)) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: FeatureLockCard(
          title: 'Challenges',
          description:
              'Join challenges with a paid plan. Goals and Gratitude Jar stay free.',
          icon: Icons.emoji_events_rounded,
        ),
      );
    }

    final open = [
      ...provider.activePremiumChallenges,
      ...provider.activeBasicChallenges,
    ].where((c) => !provider.isParticipatingIn(c.id)).toList();

    return _buildList(
      provider,
      open,
      featureFirst: true,
      emptyTitle: 'No open challenges',
      emptyMessage: "You've joined them all. New challenges drop regularly!",
    );
  }

  Widget _buildJoined(ChallengeProvider provider) {
    final joined = provider.participatingChallenges
        .where((c) => !provider.isCompleted(c.id))
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
    return _buildList(
      provider,
      joined,
      emptyTitle: "You haven't joined any challenges",
      emptyMessage: 'Pick one from Open to start earning coins and badges.',
      emptyAction: 'Browse open',
      onEmptyAction: () => _tabController.animateTo(0),
    );
  }

  Widget _buildCompleted(ChallengeProvider provider) {
    final done = provider.participatingChallenges
        .where((c) => provider.isCompleted(c.id))
        .toList();
    return _buildList(
      provider,
      done,
      emptyTitle: 'No completed challenges yet',
      emptyMessage: 'Finish a challenge to see it here with your badge.',
    );
  }

  Widget _buildList(
    ChallengeProvider provider,
    List<ChallengeModel> items, {
    bool featureFirst = false,
    required String emptyTitle,
    required String emptyMessage,
    String? emptyAction,
    VoidCallback? onEmptyAction,
  }) {
    final Widget child;
    if (items.isEmpty) {
      child = ListView(
        children: [
          const SizedBox(height: 24),
          MlqEmptyState(
            title: emptyTitle,
            message: emptyMessage,
            icon: Icons.emoji_events_rounded,
            actionLabel: emptyAction,
            onAction: onEmptyAction,
          ),
        ],
      );
    } else {
      child = LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 800 ? 880.0 : double.infinity;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final c = items[index];
              final state = provider.isCompleted(c.id)
                  ? _ChallengeState.completed
                  : provider.isParticipatingIn(c.id)
                      ? _ChallengeState.joined
                      : _ChallengeState.open;
              final Widget card = featureFirst && index == 0
                  ? _FeaturedChallengeCard(
                      challenge: c,
                      onTap: () => _openChallengeDetail(context, c),
                    )
                  : _ChallengeRow(
                      challenge: c,
                      state: state,
                      onTap: () => _openChallengeDetail(context, c),
                    );
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                ),
              ).animate().fadeIn(
                    duration: 300.ms,
                    delay: (40 * index.clamp(0, 8)).ms,
                  );
            },
          );
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.refreshChallenges(),
      child: child,
    );
  }
}

enum _ChallengeState { open, joined, completed }

const _badgeDir = 'assets/images/badges';

/// Existing badge art that matches a challenge's habit theme.
String _challengeArt(String title) {
  final t = title.toLowerCase();
  bool has(String s) => t.contains(s);

  if (has('gratitude') || has('thank')) {
    if (has('flame') || has('streak')) return '$_badgeDir/flame_of_gratitude.png';
    if (has('centurion') || has('devotee') || has('master') || has('marathon')) {
      return '$_badgeDir/eternal_gratitude.png';
    }
    if (has('starter') || has('novice')) return '$_badgeDir/seed_of_thanks.png';
    return '$_badgeDir/tree_of_thanks.png';
  }
  if (has('vision')) {
    return has('legend')
        ? '$_badgeDir/legacy_builder.png'
        : '$_badgeDir/master_planner.png';
  }
  if (has('course') || has('learn') || has('knowledge') || has('wisdom')) {
    if (has('connoisseur')) return '$_badgeDir/sage_of_learning.png';
    if (has('collector')) return '$_badgeDir/scholars_cap.png';
    if (has('explorer')) return '$_badgeDir/curious_mind.png';
    return '$_badgeDir/knowledge_Seeker.png';
  }
  if (has('streak')) return '$_badgeDir/step_climber.png';
  if (has('daily goal')) return '$_badgeDir/sharp_shooter.png';
  if (has('main goal') || has('milestone')) return '$_badgeDir/goal_voyager.png';
  if (has('well-rounded') || has('achiev')) return '$_badgeDir/achievers_medal.png';
  if (has('goal') || has('dream')) return '$_badgeDir/peak_reacher.png';
  if (has('exam') || has('waec') || has('jamb') || has('excellen')) {
    return '$_badgeDir/scholars_cap.png';
  }
  return '$_badgeDir/super_power.png';
}

({String text, Color color}) _deadline(ChallengeModel c) {
  final left = c.endDate.difference(DateTime.now());
  if (left.isNegative) return (text: 'Ended', color: AppColors.textSecondary);
  if (left.inHours < 24) {
    return (text: 'Ends in ${left.inHours}h', color: AppColors.error);
  }
  final days = left.inDays;
  return (
    text: days == 1 ? '1 day left' : '$days days left',
    color: AppColors.textSecondary,
  );
}

class _ArtTile extends StatelessWidget {
  final String asset;
  final double padding;

  const _ArtTile({required this.asset, this.padding = 14});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.plum, AppColors.primary],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.secondary,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _RewardPills extends StatelessWidget {
  final ChallengeModel challenge;

  const _RewardPills({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (challenge.xpReward > 0)
          MlqPill(label: '+${challenge.xpReward} XP', icon: Icons.bolt_rounded),
        if (challenge.coinReward > 0)
          MlqPill(
            label: '+${challenge.coinReward} coins',
            icon: Icons.monetization_on_rounded,
            background: AppColors.secondary.withOpacity(0.3),
            foreground: AppColors.goldText,
          ),
        if (challenge.isPremium)
          const MlqPill.gold(
              label: 'Premium', icon: Icons.workspace_premium_rounded),
      ],
    );
  }
}

BoxDecoration _cardDecoration({bool premium = false}) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      border: Border.all(
        color: premium ? AppColors.secondary : AppColors.border,
        width: premium ? 1.4 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.plum.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );

class _FeaturedChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onTap;

  const _FeaturedChallengeCard({required this.challenge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline(challenge);
    final sponsor = challenge.isPremium &&
            challenge.organizationName.trim().isNotEmpty
        ? challenge.organizationName
        : null;

    return Container(
      decoration: _cardDecoration(premium: challenge.isPremium),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ArtTile(asset: _challengeArt(challenge.title), padding: 28),
                    const Positioned(
                      left: 12,
                      top: 12,
                      child: MlqPill.gold(
                          label: 'Featured', icon: Icons.star_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3.copyWith(height: 1.2),
                    ),
                    if (sponsor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sponsored by $sponsor',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.goldText),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      challenge.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _RewardPills(challenge: challenge)),
                        const SizedBox(width: 8),
                        Text(
                          deadline.text,
                          style: AppTextStyles.caption.copyWith(
                            color: deadline.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    QuestButton(
                      text: 'View challenge',
                      type: QuestButtonType.secondary,
                      height: 44,
                      isFullWidth: true,
                      onPressed: onTap,
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

class _ChallengeRow extends StatelessWidget {
  final ChallengeModel challenge;
  final _ChallengeState state;
  final VoidCallback onTap;

  const _ChallengeRow({
    required this.challenge,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deadline = _deadline(challenge);
    final done = state == _ChallengeState.completed;

    return Container(
      decoration: _cardDecoration(premium: challenge.isPremium),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: _ArtTile(asset: _challengeArt(challenge.title)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      _RewardPills(challenge: challenge),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : state == _ChallengeState.joined
                                    ? Icons.directions_run_rounded
                                    : Icons.schedule_rounded,
                            size: 14,
                            color: done ? AppColors.success : deadline.color,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              done
                                  ? 'Completed'
                                  : state == _ChallengeState.joined
                                      ? 'Joined · ${deadline.text}'
                                      : deadline.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color:
                                    done ? AppColors.success : deadline.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
