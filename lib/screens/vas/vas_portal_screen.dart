import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../services/vas_daily_tips.dart';
import '../../services/vas_session.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../goals/goals_screen.dart';
import '../gratitude/gratitude_jar_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import 'vas_feature_gate.dart';

/// Entry for `/vas` — login/signup or authenticated shell.
class VasPortalScreen extends StatelessWidget {
  const VasPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (!userProvider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!userProvider.isAuthenticated) {
          return const VasAuthScreen();
        }
        return const VasShellScreen();
      },
    );
  }
}

/// Lightweight auth landing for telco/SMS users.
class VasAuthScreen extends StatelessWidget {
  const VasAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tip = VasDailyTips.forToday();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (VasSession.isDemo) const _VasDemoBanner(),
              const SizedBox(height: 8),
              Text(
                'My Leadership Quest',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Daily leadership for students via Shortcode 7089',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today · ${tip.habit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip.prompt,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SignupScreen(returnToVas: true),
                    ),
                  );
                },
                child: const Text('Create your free profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(returnToVas: true),
                    ),
                  );
                },
                child: const Text('I already have an account'),
              ),
              const SizedBox(height: 20),
              const Text(
                'With your profile you get Daily Goals, Gratitude Jar, and the global leaderboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VasShellScreen extends StatefulWidget {
  const VasShellScreen({super.key});

  @override
  State<VasShellScreen> createState() => _VasShellScreenState();
}

class _VasShellScreenState extends State<VasShellScreen> {
  int _index = 0;

  static const _tabs = [
    _VasTab('Today', Icons.wb_sunny_outlined),
    _VasTab('Goals', Icons.flag_outlined),
    _VasTab('Gratitude', Icons.favorite_outline),
    _VasTab('Ranks', Icons.emoji_events_outlined),
    _VasTab('More', Icons.grid_view_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _VasTodayHome(
        onOpenGoals: () => setState(() => _index = 1),
        onOpenGratitude: () => setState(() => _index = 2),
        onOpenRanks: () => setState(() => _index = 3),
      ),
      const GoalsScreen(),
      const GratitudeJarScreen(),
      const LeaderboardScreen(isInHomeScreen: false),
      const _VasMoreScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (VasSession.isDemo) const _VasDemoBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _VasTab {
  const _VasTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _VasDemoBanner extends StatelessWidget {
  const _VasDemoBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withOpacity(0.15),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Demo mode — billing not active. Telco review only.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VasTodayHome extends StatelessWidget {
  const _VasTodayHome({
    this.onOpenGoals,
    this.onOpenGratitude,
    this.onOpenRanks,
  });

  final VoidCallback? onOpenGoals;
  final VoidCallback? onOpenGratitude;
  final VoidCallback? onOpenRanks;

  @override
  Widget build(BuildContext context) {
    final tip = VasDailyTips.forToday();
    final user = context.watch<UserProvider>().user;
    final name = user?.name.split(' ').first ?? 'Leader';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MLQ Daily'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hi $name 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your daily leadership check-in',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY · ${tip.habit.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tip.prompt,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tip.taskHint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Do today\'s tasks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            icon: Icons.flag,
            color: AppColors.tertiary,
            title: 'Daily Goals',
            subtitle: 'Plan and complete your goals',
            onTap: onOpenGoals,
          ),
          _QuickAction(
            icon: Icons.favorite,
            color: AppColors.accent1,
            title: 'Gratitude Jar',
            subtitle: 'Log something you\'re thankful for',
            onTap: onOpenGratitude,
          ),
          _QuickAction(
            icon: Icons.emoji_events,
            color: AppColors.secondary,
            title: 'Global Leaderboard',
            subtitle: 'See how you rank with other leaders',
            onTap: onOpenRanks,
          ),
          const SizedBox(height: 16),
          const Text(
            'Keep showing up daily — small habits build great leaders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VasMoreScreen extends StatelessWidget {
  const _VasMoreScreen();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final full = VasSession.hasFullAppAccess(user);

    final gated = <_MoreItem>[
      _MoreItem(
        Icons.menu_book_outlined,
        'Mini-courses',
        VasLockReason.upgrade,
      ),
      _MoreItem(
        Icons.psychology_outlined,
        'AI Coach (Questor)',
        VasLockReason.upgrade,
      ),
      _MoreItem(
        Icons.sports_esports_outlined,
        'Challenges',
        VasLockReason.upgrade,
      ),
      _MoreItem(
        Icons.storefront_outlined,
        'Shop',
        VasLockReason.upgrade,
      ),
      _MoreItem(
        Icons.account_balance_wallet_outlined,
        'LeadWallet',
        VasLockReason.upgrade,
      ),
      _MoreItem(
        Icons.auto_awesome,
        'Victory Wall',
        VasLockReason.schoolCommunityOnly,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Included with your daily plan',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const _IncludedChip(Icons.flag, 'Goals'),
          const _IncludedChip(Icons.favorite, 'Gratitude'),
          const _IncludedChip(Icons.emoji_events, 'Global leaderboard'),
          const SizedBox(height: 20),
          const Text(
            'Full MLQ features',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final item in gated)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surface,
              leading: Icon(item.icon, color: AppColors.primary),
              title: Text(item.title),
              trailing: full && item.reason == VasLockReason.upgrade
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : Icon(
                      item.reason == VasLockReason.schoolCommunityOnly
                          ? Icons.info_outline
                          : Icons.lock_outline,
                      color: AppColors.textHint,
                    ),
              onTap: () {
                if (full && item.reason == VasLockReason.upgrade) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open the full MLQ app for this feature.',
                      ),
                    ),
                  );
                  return;
                }
                VasFeatureGate.showLocked(
                  context,
                  featureName: item.title,
                  reason: item.reason,
                );
              },
            ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              // Keep VAS mode so they return to the telco portal auth screen.
              await context.read<UserProvider>().logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.title, this.reason);
  final IconData icon;
  final String title;
  final VasLockReason reason;
}

class _IncludedChip extends StatelessWidget {
  const _IncludedChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
