import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../widgets/premium_challenge_card.dart';
import '../../widgets/trial_expired_modal.dart';
import '../shop/shop_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';

class ChallengesScreen extends StatefulWidget {
  final bool isInHomeScreen;

  const ChallengesScreen({super.key, this.isInHomeScreen = false});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UserProvider userProvider;
  late ChallengeProvider challengeProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    // Refresh challenges when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      challengeProvider.refreshChallenges();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Feature gate for premium challenges - show upgrade prompt
  void _openChallengeDetail(BuildContext context, ChallengeModel challenge) {
    final challengeProvider =
        Provider.of<ChallengeProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isJoined = challengeProvider.isParticipatingIn(challenge.id);
    final isPremiumUser = userProvider.user?.isPremium == true;

    if (challenge.isPremium && !isJoined && !isPremiumUser) {
      // Show upgrade prompt for premium challenges
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
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Benefits:',
                    style: AppTextStyles.bodyBold,
                  ),
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
              // Navigate to subscription management with proper context
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/subscription-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create the TabBar widget
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      indicatorColor: Colors.transparent, // Remove the underline/outline border
      dividerColor: Colors.transparent, // Remove the bottom divider/border line
      labelColor: AppColors.secondary, // Active tab gold
      unselectedLabelColor: const Color.fromARGB(137, 233, 228, 228),
      labelStyle: AppTextStyles.bodyBold
          .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      unselectedLabelStyle: AppTextStyles.body
          .copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      tabs: const [
        Tab(text: 'Basic'),
        Tab(text: 'Premium'),
        Tab(text: 'My Challenges'),
      ],
    );

    // Get providers for updating UI
    final challengeProvider = Provider.of<ChallengeProvider>(context);

    // Create the content widget
    final content = challengeProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildBasicChallenges(),
              _buildPremiumChallenges(),
              _buildMyChallenges(),
            ],
          );

    // Show error snackbar if there is an error
    if (challengeProvider.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(challengeProvider.errorMessage)),
        );
      });
    }

    // If this screen is displayed within the HomeScreen, return a column with TabBar and content
    if (widget.isInHomeScreen) {
      return Column(
        children: [
          Container(
            color: AppColors.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 28, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Challenges',
                            style: AppTextStyles.heading3
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.shopping_bag,
                            color: AppColors.secondary),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ShopScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 6.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(child: tabBar),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    // Return the full Scaffold when shown as a standalone screen
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 28, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              'Challenges',
              style: AppTextStyles.heading3.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag, color: AppColors.secondary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ShopScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: tabBar.preferredSize,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(child: tabBar),
            ),
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildBasicChallenges() {
    final challengeProvider = Provider.of<ChallengeProvider>(context);
    // Only show active (non-expired) basic challenges that user hasn't joined
    final basicChallenges = challengeProvider.activeBasicChallenges
        .where((c) => !challengeProvider.isParticipatingIn(c.id))
        .toList();

    return _buildChallengesList(
      challenges: basicChallenges,
      emptyMessage: 'No basic challenges available',
      emptyDescription: 'Check back later for new challenges!',
    );
  }

  Widget _buildPremiumChallenges() {
    final challengeProvider = Provider.of<ChallengeProvider>(context);
    // Only show active (non-expired) premium challenges that user hasn't joined
    final premium = challengeProvider.activePremiumChallenges
        .where((c) => !challengeProvider.isParticipatingIn(c.id))
        .toList();

    if (premium.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium,
                    size: 64, color: AppColors.secondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Premium Challenges — Coming Soon',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We\'re curating exciting, prize-backed premium challenges with partners. Check back soon!',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: Join a school or upgrade to be first in line when new premium challenges drop.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: premium.length,
      itemBuilder: (context, index) {
        final challenge = premium[index];
        return PremiumChallengeCard(
          challenge: challenge,
          isUnlocked: false,
          showSponsorRegistration: false,
          onTap: () => _openChallengeDetail(context, challenge),
        ).animate().fadeIn(
            duration: Duration(milliseconds: 300),
            delay: Duration(milliseconds: 50 * index));
      },
    );
  }

  Widget _buildMyChallenges() {
    final challengeProvider = Provider.of<ChallengeProvider>(context);
    final participatingChallenges = challengeProvider.participatingChallenges;

    return _buildChallengesList(
      challenges: participatingChallenges,
      emptyMessage: 'You haven\'t joined any challenges',
      emptyDescription: 'Join challenges to earn coins and rewards!',
      isParticipating: true,
    );
  }

  Widget _buildChallengesList({
    required List<ChallengeModel> challenges,
    required String emptyMessage,
    required String emptyDescription,
    bool isPremium = false,
    bool isParticipating = false,
  }) {
    final challengeProvider = Provider.of<ChallengeProvider>(context);

    if (challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPremium ? Icons.star : Icons.emoji_events,
                size: 64,
                color: isPremium ? AppColors.accent1 : AppColors.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                emptyDescription,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        final isParticipatingInThisChallenge =
            challengeProvider.isParticipatingIn(challenge.id);

        // For joined premium challenges, show richer premium layout with actions
        if (isParticipatingInThisChallenge && challenge.isPremium) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumChallengeCard(
                challenge: challenge,
                isUnlocked: true,
                showSponsorRegistration: false,
                onTap: () => _openChallengeDetail(context, challenge),
              ),
              if (challengeProvider.isCompleted(challenge.id))
                Padding(
                  padding:
                      const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Completed',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // View details button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: QuestButton(
                  text: 'View Details',
                  type: QuestButtonType.primary,
                  isFullWidth: true,
                  onPressed: () => _openChallengeDetail(context, challenge),
                ),
              ),
              const SizedBox(height: 8),
              // Leave challenge button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: QuestButton(
                  text: 'Leave Challenge',
                  type: QuestButtonType.outline,
                  isFullWidth: true,
                  onPressed: () async {
                    challengeProvider.leaveChallenge(challenge.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'You left the ${challenge.title} challenge',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                        backgroundColor: AppColors.secondary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ).animate().fadeIn(
              duration: Duration(milliseconds: 300),
              delay: Duration(milliseconds: 50 * index));
        }

        // Default card for others (basic or not joined)
        return ChallengeCard(
          challenge: challenge,
          isParticipating: isParticipatingInThisChallenge,
          onTap: () => _openChallengeDetail(context, challenge),
        ).animate().fadeIn(
            duration: Duration(milliseconds: 300),
            delay: Duration(milliseconds: 50 * index));
      },
    );
  }

  // Old purchase dialog removed in favor of detail-screen unlock flow.
}
