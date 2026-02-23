import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/challenge_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/school_course_provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import 'challenge_form_screen.dart';
import 'challenge_participants_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'community_management_screen.dart';
import 'maintenance_notice_screen.dart';
import 'school_courses_admin_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  static const routeName = '/admin-dashboard';

  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  List<ChallengeModel> _challenges = [];
  bool _isLoadingMonthlyTop = true;
  List<Map<String, dynamic>> _monthlyTopUsers = [];

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _loadMonthlyTopUsers();
  }

  Future<void> _loadMonthlyTopUsers() async {
    setState(() {
      _isLoadingMonthlyTop = true;
    });

    try {
      final users = await AdminService.instance.getTopMonthlyUsers(limit: 3);
      if (!mounted) return;
      setState(() {
        _monthlyTopUsers = users;
        _isLoadingMonthlyTop = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMonthlyTop = false;
      });
    }
  }

  Future<void> _sendMonthlyWinnersCongrats() async {
    try {
      final count = await AdminService.instance.sendMonthlyWinnersCongrats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Sent monthly winner congratulations to $count user(s)'
                : 'No new winner notifications to send (already sent for this month)',
          ),
          backgroundColor: count > 0 ? Colors.green : Colors.blueGrey,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send winner congratulations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadChallenges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final challenges = await AdminService.instance.getAllChallenges();
      setState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load challenges'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteChallenge(String id) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this challenge?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final success = await AdminService.instance.deleteChallenge(id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadChallenges();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_rounded),
            tooltip: 'Send Monthly Winner Congrats',
            onPressed: _sendMonthlyWinnersCongrats,
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Maintenance Notices',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MaintenanceNoticeScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'Community Management',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CommunityManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics Dashboard',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AnalyticsDashboardScreen(),
                ),
              );
            },
          ),
          // School Courses Admin - only show if user is school admin
          Consumer<SchoolCourseProvider>(
            builder: (context, provider, _) {
              if (provider.isSchoolAdmin && provider.hasPremium) {
                return IconButton(
                  icon: const Icon(Icons.school),
                  tooltip: 'School Courses',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SchoolCoursesAdminScreen(),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _loadChallenges(),
                  _loadMonthlyTopUsers(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthlyTopUsersCard(),
                  const SizedBox(height: 16),
                  if (_challenges.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No challenges found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first challenge by clicking the + button',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) => const ChallengeFormScreen(),
                                    ),
                                  )
                                  .then((_) => _loadChallenges());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Challenge'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._challenges.map((challenge) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: challenge.type == ChallengeType.premium
                                ? AppColors.secondary.withOpacity(0.5)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: challenge.type == ChallengeType.premium
                                    ? AppColors.secondary.withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      challenge.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      challenge.type == ChallengeType.premium
                                          ? 'Premium'
                                          : 'Basic',
                                    ),
                                    backgroundColor: challenge.type ==
                                            ChallengeType.premium
                                        ? AppColors.secondary
                                        : Colors.grey.shade400,
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    challenge.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildInfoChip(
                                        Icons.calendar_today,
                                        challenge.timeline,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoChip(
                                        Icons.monetization_on,
                                        '${challenge.coinReward} coins',
                                      ),
                                      const SizedBox(width: 8),
                                      if (challenge.isPremium &&
                                          challenge.coinsCost > 0)
                                        _buildInfoChip(
                                          Icons.shopping_cart,
                                          'Cost: ${challenge.coinsCost} coins',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ChallengeFormScreen(
                                                challenge: challenge,
                                              ),
                                            ),
                                          )
                                          .then((_) => _loadChallenges());
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ChallengeParticipantsScreen(
                                            challengeId: challenge.id,
                                            challengeTitle: challenge.title,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.people),
                                    label: const Text('Participants'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _deleteChallenge(challenge.id),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ChallengeFormScreen(),
            ),
          ).then((_) => _loadChallenges());
        },
        backgroundColor: AppColors.secondary,
        heroTag: 'admin_add_challenge_fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthlyTopUsersCard() {
    final now = DateTime.now();
    final monthLabel = '${_monthName(now.month)} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.95),
            AppColors.secondary.withOpacity(0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Top 3 Users of the Month',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingMonthlyTop)
            Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading monthly leaders...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
          else if (_monthlyTopUsers.isEmpty)
            Text(
              'No monthly leaderboard data available yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.95)),
            )
          else
            Column(
              children: List.generate(_monthlyTopUsers.length, (index) {
                final user = _monthlyTopUsers[index];
                final rank = index + 1;
                final name = (user['name'] ?? 'Unknown').toString();
                final school = (user['school_name'] ?? '').toString();
                final monthlyXp = (user['monthly_xp'] ?? 0).toString();
                final avatarUrl = user['avatar_url']?.toString();
                final medalColor = rank == 1
                    ? const Color(0xFFFFD700)
                    : rank == 2
                        ? const Color(0xFFC0C0C0)
                        : const Color(0xFFCD7F32);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: medalColor.withOpacity(0.2),
                          border: Border.all(color: medalColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: medalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.85),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? (avatarUrl.startsWith('assets/')
                                ? AssetImage(avatarUrl) as ImageProvider
                                : NetworkImage(avatarUrl))
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (school.isNotEmpty)
                              Text(
                                school,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              '$monthlyXp XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tap the trophy in the top bar to send their congratulations.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadMonthlyTopUsers,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
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
    if (m < 1 || m > 12) return 'Unknown';
    return months[m - 1];
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
