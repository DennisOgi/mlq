import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'package:my_leadership_quest/screens/auth/login_screen.dart';
import 'package:my_leadership_quest/screens/subscription/subscription_management_screen.dart';
import 'package:my_leadership_quest/screens/coins/coin_transaction_history_screen.dart';
import 'package:my_leadership_quest/screens/admin/admin_login_screen.dart';
import 'package:my_leadership_quest/screens/admin/school_courses_admin_screen.dart';
import '../../services/admin_service.dart';
import '../../providers/school_course_provider.dart';
import 'parent_portal_screen.dart';
import 'account_settings_screen.dart';
import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';
import '../../services/push_notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Refresh entitlements to ensure premium status is current
      _refreshPremiumStatus();

      // Initialize school course provider for school admin check
      _initializeSchoolProvider();
    });

    // Show fallback message after 3 seconds if user is still null
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.user == null) {
          setState(() {
            _showFallback = true;
          });
        }
      }
    });
  }

  Future<void> _initializeSchoolProvider() async {
    final schoolProvider =
        Provider.of<SchoolCourseProvider>(context, listen: false);
    await schoolProvider.initialize();
  }

  Future<void> _refreshPremiumStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.refreshEntitlements();
    debugPrint('🟣 [Profile] Premium status refreshed');
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);
    final user = userProvider.user;
    final badges = userProvider.badges;

    debugPrint(
        'ProfileScreen - User: ${user?.name}, Authenticated: ${userProvider.isAuthenticated}');

    if (user == null) {
      debugPrint('ProfileScreen - User is null, showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 28, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'My Profile',
                style: AppTextStyles.heading3.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showFallback) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Loading your profile...'),
              ] else ...[
                const Icon(
                  Icons.wifi_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This might be due to network connectivity issues.\nPlease check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Try to reinitialize the user
                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    setState(() {
                      _showFallback = false;
                    });
                    // Manually reinitialize the user
                    await userProvider.reinitializeUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_rounded,
                size: 28, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              'My Profile',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            _buildUserInfoCard(context, user),
            const SizedBox(height: 24),

            // Stats section
            Text(
              'My Stats',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(context, user, goalProvider),
            const SizedBox(height: 24),

            // Badges section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'My Badges',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${badges.length}',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Show all badges dialog
                    _showAllBadgesDialog(context, badges);
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBadgesGrid(context, badges),
            const SizedBox(height: 24),

            // Settings section
            Text(
              'Settings',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(context, user),
            const SizedBox(height: 24),

            const SizedBox.shrink(),

            // Admin Portal (only for admin users)
            FutureBuilder<bool>(
              future: AdminService.instance.isAdmin(
                  userProvider:
                      Provider.of<UserProvider>(context, listen: false)),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return Column(
                    children: [
                      Text(
                        'Admin Tools',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: AppColors.primary,
                            ),
                          ),
                          title: const Text('Admin Portal'),
                          subtitle:
                              const Text('Access admin dashboard and tools'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const AdminLoginScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: AppColors.secondary,
                            ),
                          ),
                          title: const Text('School Onboarding (Admin)'),
                          subtitle: const Text(
                              'Create school org, add seats, invite students'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.of(context)
                                .pushNamed('/admin-school-onboarding');
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink(); // Hide if not admin
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: AppTextStyles.heading1.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),

          // User name and premium checkmark
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name,
                style: AppTextStyles.heading2.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              // Premium chip - uses UserProvider's isPremium (synced from database)
              if (user.isPremium)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF9C27B0), // Purple
                        Color(0xFF673AB7), // Deep Purple
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF9C27B0).withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Premium',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(width: 6),
              // "via School" badge when entitlements include a school org
              FutureBuilder<Map<String, dynamic>>(
                future: SupabaseService.instance.fetchEntitlements(),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final hasSchool =
                      data != null && (data['has_school'] == true);
                  final isPremium =
                      data != null && (data['is_premium'] == true);
                  if (!isPremium || !hasSchool) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white70, width: 0.8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.school_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('via School',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          Text(
            'Age: ${user.age}',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),

          // Coins and badges count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(
                icon: Icons.monetization_on,
                value: user.coins.toStringAsFixed(1),
                label: 'Coins',
                color: Colors.white,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              _buildStatItem(
                icon: Icons.emoji_events,
                value:
                    Provider.of<UserProvider>(context).badges.length.toString(),
                label: 'Badges',
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.heading3.copyWith(
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, UserModel user, GoalProvider goalProvider) {
    // Calculate stats
    final completedGoalsCount =
        goalProvider.dailyGoals.where((goal) => goal.isCompleted).length;

    final currentStreak = goalProvider.getCurrentStreak();

    final mainGoalsProgress = goalProvider.mainGoals.isEmpty
        ? 0.0
        : goalProvider.mainGoals
                .map((goal) => goal.progressPercentage)
                .reduce((a, b) => a + b) /
            goalProvider.mainGoals.length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Goals Completed',
          value: completedGoalsCount.toString(),
          icon: Icons.task_alt,
          color: AppColors.tertiary,
        ),
        _buildStatCard(
          title: 'Current Streak',
          value: '$currentStreak days',
          icon: Icons.local_fire_department,
          color: AppColors.accent2,
        ),
        _buildStatCard(
          title: 'Main Goals Progress',
          value: '${(mainGoalsProgress * 100).toInt()}%',
          icon: Icons.trending_up,
          color: AppColors.secondary,
        ),
        _buildStatCard(
          title: 'Challenges Joined',
          value: Provider.of<ChallengeProvider>(context)
              .participatingChallengeIds
              .length
              .toString(),
          icon: Icons.emoji_events,
          color: AppColors.accent1,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading3,
          ),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBadgesGrid(BuildContext context, List<BadgeModel> badges) {
    if (badges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Badges Yet',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete goals and challenges to earn badges!',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show up to 4 badges in the grid
    final displayBadges = badges.length > 4 ? badges.sublist(0, 4) : badges;

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: displayBadges.map((badge) {
        return GestureDetector(
          onTap: () {
            _showBadgeDetailsDialog(context, badge);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.asset(
                badge.imageAsset,
                fit: BoxFit.cover,
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0));
      }).toList(),
    );
  }

  Widget _buildSettingsCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.edit,
            title: 'Edit Profile',
            onTap: () {
              _showEditProfileDialog(context, user);
            },
          ),
          const Divider(),
          _buildSettingsItem(
            icon: Icons.card_membership,
            title: 'My Subscription',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          _buildSettingsItem(
            icon: Icons.manage_accounts,
            title: 'Account Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AccountSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          _buildSettingsItem(
            icon: Icons.monetization_on,
            title: 'Coin Transactions',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CoinTransactionHistoryScreen(),
                ),
              );
            },
          ),
          const Divider(),
          // Parent Portal - accessible to all users (parents can login separately)
          _buildSettingsItem(
            icon: Icons.family_restroom,
            title: 'Parent Portal',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ParentPortalScreen(),
              ),
            ),
          ),
          const Divider(),
          _buildSettingsItem(
            icon: Icons.info,
            title: 'About',
            onTap: () => _showAboutDialog(context),
          ),
          // Dev-only: View Welcome Screen button
          if (kDebugMode) ...[
            const Divider(),
            _buildSettingsItem(
              icon: Icons.movie_filter_rounded,
              title: 'View Welcome Screen',
              onTap: () {
                Navigator.of(context).pushNamed('/welcome-preview');
              },
            ),
          ],
          // Dev-only shortcuts hidden per user request
          // if (kDebugMode) ...[
          //   const Divider(),
          //   _buildSettingsItem(
          //     icon: Icons.build,
          //     title: 'Open Onboarding (Dev)',
          //     onTap: () async {
          //       await Provider.of<UserProvider>(context, listen: false).resetFirstTimeUser();
          //       if (!mounted) return;
          //       Navigator.of(context).pushNamed('/onboarding');
          //     },
          //   ),
          //   const Divider(),
          //   _buildSettingsItem(
          //     icon: Icons.notifications_active,
          //     title: 'Test Notification',
          //     onTap: () async {
          //       try {
          //         await PushNotificationService.instance.showTestNotification(
          //           title: 'Test Notification 🎯',
          //           body: 'This is a test notification from My Leadership Quest!',
          //         );
          //         if (!mounted) return;
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           const SnackBar(
          //             content: Text('Test notification sent! Check your notification tray.'),
          //             backgroundColor: Colors.green,
          //           ),
          //         );
          //       } catch (e) {
          //         if (!mounted) return;
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(
          //             content: Text('Failed to send notification: $e'),
          //             backgroundColor: Colors.red,
          //           ),
          //         );
          //       }
          //     },
          //   ),
          // ],
          const Divider(),
          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _showLogoutConfirmationDialog(context),
          ),
          // School Admin Portal - for school admins with premium
          Consumer<SchoolCourseProvider>(
            builder: (context, schoolProvider, _) {
              if (schoolProvider.isSchoolAdmin && schoolProvider.hasPremium) {
                return Column(
                  children: [
                    const Divider(),
                    _buildSettingsItem(
                      icon: Icons.school,
                      title: 'School Courses Admin',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const SchoolCoursesAdminScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (user.isAdmin) ...[
            // Only show this option for admins
            const Divider(),
            _buildSettingsItem(
              icon: Icons.admin_panel_settings,
              title: 'Admin Portal',
              onTap: () {
                Navigator.of(context).pushNamed('/admin-login');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.secondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.body,
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    String name = user.name;
    int age = user.age;
    // Approximate birthday based on current age (defaults to mid-year)
    DateTime? birthday = DateTime(DateTime.now().year - age, 6, 15);

    int _calculateAge(DateTime dob, DateTime today) {
      int years = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        years--;
      }
      return years;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Profile', style: AppTextStyles.heading3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name field
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    controller: TextEditingController(text: name),
                    onChanged: (value) {
                      name = value;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Birthday picker (replaces age stepper)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cake, color: AppColors.secondary),
                    title: Text('Birthday', style: AppTextStyles.body),
                    subtitle: Text(
                      birthday != null
                          ? '${birthday!.day.toString().padLeft(2, '0')}/${birthday!.month.toString().padLeft(2, '0')}/${birthday!.year}  (Age: $age)'
                          : 'Select your birthday',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      // Allowed ages: 8 to 14 (inclusive) — match previous constraints
                      final firstDate =
                          DateTime(now.year - 14, now.month, now.day);
                      final lastDate =
                          DateTime(now.year - 8, now.month, now.day);
                      DateTime initialDate = birthday ??
                          DateTime(now.year - age, now.month, now.day);
                      if (initialDate.isBefore(firstDate))
                        initialDate = firstDate;
                      if (initialDate.isAfter(lastDate)) initialDate = lastDate;

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked != null) {
                        setState(() {
                          birthday = picked;
                          age = _calculateAge(picked, now);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Name cannot be empty',
                            style: AppTextStyles.body
                                .copyWith(color: Colors.white),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    // Update user profile
                    userProvider.updateUserProfile(
                      name: name,
                      age: age,
                    );

                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Profile updated successfully',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBadgeDetailsDialog(BuildContext context, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(badge.name, style: AppTextStyles.heading3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.asset(
                    badge.imageAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                badge.description ?? badge.defaultDescription,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Earned on ${badge.earnedDate.day}/${badge.earnedDate.month}/${badge.earnedDate.year}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            QuestButton(
              text: 'Close',
              type: QuestButtonType.primary,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAllBadgesDialog(BuildContext context, List<BadgeModel> badges) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('All Badges', style: AppTextStyles.heading3),
          content: SizedBox(
            width: double.maxFinite,
            child: badges.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Badges Yet',
                          style: AppTextStyles.heading3,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete goals and challenges to earn badges!',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: badges.length,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final badge = badges[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showBadgeDetailsDialog(context, badge);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.asset(
                                  badge.imageAsset,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badge.name,
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            QuestButton(
              text: 'Close',
              type: QuestButtonType.primary,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, UserModel? user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Manage Subscription ListTile - NOW VISIBLE FOR TESTING
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.workspace_premium,
                color: AppColors.primary,
              ),
            ),
            title: const Text('Manage Subscription'),
            subtitle: const Text('Upgrade to Premium for unlimited features'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionManagementScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.monetization_on,
                color: AppColors.accent1,
              ),
            ),
            title: const Text('Coin History'),
            subtitle: const Text('View your coin transactions and purchases'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CoinTransactionHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(
            child: Text('About My Leadership Quest',
                style: AppTextStyles.heading3)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.emoji_events,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'My Leadership Quest™',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            Text(
              'Version 1.0.0',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'My Leadership Quest helps kids achieve personal growth through goal setting, gamification, and AI coaching.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 LeadGame Solutions Ltd',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          QuestButton(
            text: 'Close',
            type: QuestButtonType.primary,
            isFullWidth: true,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Logout', style: AppTextStyles.heading3),
          content: Text('Are you sure you want to logout?'),
          actions: [
            QuestButton(
              text: 'Cancel',
              type: QuestButtonType.secondary,
              isFullWidth: false,
              onPressed: () => Navigator.pop(context),
            ),
            QuestButton(
              text: 'Logout',
              type: QuestButtonType.primary,
              isFullWidth: false,
              onPressed: () async {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // ✅ SECURITY FIX: Clear all provider states to prevent cross-account data leakage
                  debugPrint(
                      '🔒 Clearing all provider states before logout...');

                  // Clear gratitude provider state
                  final gratitudeProvider =
                      Provider.of<GratitudeProvider>(context, listen: false);
                  gratitudeProvider.clearEntries();

                  // Clear mini course provider state
                  final miniCourseProvider =
                      Provider.of<MiniCourseProvider>(context, listen: false);
                  miniCourseProvider.clearState();
                  await miniCourseProvider.clearAttemptedQuizzesCache();

                  // Note: GoalProvider doesn't have clearState method yet
                  // UserProvider.logout() already clears goals cache via _clearGoalsCache()

                  // Clear post provider state (Victory Wall)
                  final postProvider =
                      Provider.of<PostProvider>(context, listen: false);
                  postProvider.clearPosts();

                  debugPrint('✅ All provider states cleared');

                  // Call the logout method from UserProvider
                  await Provider.of<UserProvider>(context, listen: false)
                      .logout();

                  // Close loading indicator
                  Navigator.of(context).pop();

                  // Navigate to the login screen instead of onboarding
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false, // This removes all previous routes
                  );
                } catch (e) {
                  // Close loading indicator
                  Navigator.of(context).pop();
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error logging out: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reset App', style: AppTextStyles.heading3),
          content: Text(
            'This will reset the app to its initial state. All data will be lost. This action cannot be undone.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                // Reset the app
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);
                userProvider.resetFirstTimeUser();

                Navigator.pop(context);

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'App reset successfully. Restart the app to see changes.',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
