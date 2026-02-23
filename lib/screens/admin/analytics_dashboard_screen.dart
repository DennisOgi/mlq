import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../constants/app_constants.dart' hide AppColors;

class AnalyticsDashboardScreen extends StatefulWidget {
  static const routeName = '/analytics-dashboard';

  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;

  Map<String, dynamic> _userAnalytics = {};
  Map<String, dynamic> _engagementAnalytics = {};
  Map<String, dynamic> _contentAnalytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadAllAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final userData = await AnalyticsService.instance.getUserAnalytics();
      setState(() {
        _userAnalytics = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 24), text: 'Users'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading analytics...',
                    style: AppTextStyles.body.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
              ],
            ),
    );
  }

  // ===== USERS TAB =====

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadAllAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserMetricsGrid(),
            const SizedBox(height: 24),
            _buildUserGrowthChart(),
            const SizedBox(height: 24),
            _buildRetentionCard(),
            const SizedBox(height: 24),
            _buildFeatureEngagementCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMetricsGrid() {
    final totalUsers = _userAnalytics['total_users'] ?? 0;
    final premiumUsers = _userAnalytics['premium_users'] ?? 0;
    final schoolUsers = _userAnalytics['school_users'] ?? 0;
    final freeUsers = _userAnalytics['free_users'] ?? 0;
    final newUsers = _userAnalytics['new_users_30d'] ?? 0;
    final activeUsers = _userAnalytics['active_users_7d'] ?? 0;
    final dau = _userAnalytics['dau'] ?? 0;
    final conversionRate = _userAnalytics['premium_conversion_rate'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Metrics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            _buildMetricCard(
              title: 'Total Users',
              value: _formatNumber(totalUsers),
              icon: Icons.people,
              color: AppColors.primary,
              subtitle: '$newUsers new (30d)',
            ),
            _buildMetricCard(
              title: 'Active Users (7d)',
              value: _formatNumber(activeUsers),
              icon: Icons.trending_up,
              color: AppColors.secondary,
              subtitle: 'DAU: $dau',
            ),
            _buildMetricCard(
              title: 'Premium Users',
              value: _formatNumber(premiumUsers),
              icon: Icons.star,
              color: Colors.amber,
              subtitle: '${conversionRate.toStringAsFixed(1)}% conversion',
            ),
            _buildMetricCard(
              title: 'School Users',
              value: _formatNumber(schoolUsers),
              icon: Icons.school,
              color: AppColors.tertiary,
              subtitle: 'Free: $freeUsers',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    final growthData = _userAnalytics['user_growth'] as List? ?? [];
    if (growthData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Growth (Last 30 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= growthData.length)
                            return const Text('');
                          final date =
                              growthData[value.toInt()]['date'] as String;
                          final parts = date.split('-');
                          return Text(
                            '${parts[2]}/${parts[1]}',
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        growthData.length,
                        (i) => FlSpot(i.toDouble(),
                            (growthData[i]['count'] as int).toDouble()),
                      ),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCard() {
    final retention =
        _userAnalytics['retention'] as Map<String, dynamic>? ?? {};
    final day7 = retention['day_7'] ?? 0.0;
    final day30 = retention['day_30'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Retention',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRetentionMetric('7-Day', day7),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRetentionMetric('30-Day', day30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionMetric(String label, double value) {
    final color = value >= 50
        ? AppColors.tertiary
        : (value >= 30 ? Colors.orange : Colors.red);

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: value / 100,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureEngagementCard() {
    final engagement =
        _userAnalytics['feature_engagement'] as Map<String, dynamic>? ?? {};
    if (engagement.isEmpty) return const SizedBox.shrink();

    final features = engagement.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feature Engagement (Last 30 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...features.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFeatureBar(
                    _formatFeatureName(entry.key),
                    entry.value as int,
                    features.first.value as int,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBar(String name, int value, int maxValue) {
    final percentage = maxValue > 0 ? value / maxValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(_formatNumber(value),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
      ],
    );
  }

  // ===== ENGAGEMENT TAB =====

  Widget _buildEngagementTab() {
    return RefreshIndicator(
      onRefresh: _loadAllAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEngagementOverview(),
            const SizedBox(height: 24),
            _buildFeatureEngagementBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementOverview() {
    final goals = _engagementAnalytics['goals'] as Map<String, dynamic>? ?? {};
    final challenges = _engagementAnalytics['challenges'] as Map<String, dynamic>? ?? {};
    final courses = _engagementAnalytics['courses'] as Map<String, dynamic>? ?? {};
    final victoryWall = _engagementAnalytics['victory_wall'] as Map<String, dynamic>? ?? {};
    final aiCoach = _engagementAnalytics['ai_coach'] as Map<String, dynamic>? ?? {};
    final gratitude = _engagementAnalytics['gratitude'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Engagement Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: [
            _buildEngagementCard(
              title: 'Goals',
              value: _formatNumber(goals['total_daily_goals'] ?? 0),
              subtitle: '${(goals['completion_rate'] ?? 0).toStringAsFixed(1)}% completed',
              icon: Icons.flag,
              color: AppColors.primary,
            ),
            _buildEngagementCard(
              title: 'Challenges',
              value: _formatNumber(challenges['total_participations'] ?? 0),
              subtitle: '${(challenges['completion_rate'] ?? 0).toStringAsFixed(1)}% completed',
              icon: Icons.emoji_events,
              color: Colors.amber,
            ),
            _buildEngagementCard(
              title: 'Mini Courses',
              value: _formatNumber(courses['total_started'] ?? 0),
              subtitle: '${courses['completed'] ?? 0} completed',
              icon: Icons.school,
              color: AppColors.secondary,
            ),
            _buildEngagementCard(
              title: 'Victory Wall',
              value: _formatNumber(victoryWall['total_posts'] ?? 0),
              subtitle: '${victoryWall['total_likes'] ?? 0} likes',
              icon: Icons.celebration,
              color: Colors.purple,
            ),
            _buildEngagementCard(
              title: 'AI Coach',
              value: _formatNumber(aiCoach['total_conversations'] ?? 0),
              subtitle: '${aiCoach['total_messages'] ?? 0} messages',
              icon: Icons.psychology,
              color: Colors.teal,
            ),
            _buildEngagementCard(
              title: 'Gratitude',
              value: _formatNumber(gratitude['total_entries'] ?? 0),
              subtitle: 'Last 30 days',
              icon: Icons.favorite,
              color: Colors.pink,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEngagementCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureEngagementBreakdown() {
    final goals = _engagementAnalytics['goals'] as Map<String, dynamic>? ?? {};
    final challenges = _engagementAnalytics['challenges'] as Map<String, dynamic>? ?? {};
    final courses = _engagementAnalytics['courses'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Completion Rates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCompletionBar(
              'Daily Goals',
              goals['completion_rate'] ?? 0.0,
              AppColors.primary,
            ),
            const SizedBox(height: 12),
            _buildCompletionBar(
              'Challenges',
              challenges['completion_rate'] ?? 0.0,
              Colors.amber,
            ),
            const SizedBox(height: 12),
            _buildCompletionBar(
              'Mini Courses',
              courses['completion_rate'] ?? 0.0,
              AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ===== CONTENT TAB =====

  Widget _buildContentTab() {
    return RefreshIndicator(
      onRefresh: _loadAllAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContentOverview(),
            const SizedBox(height: 24),
            _buildChallengePerformance(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentOverview() {
    final totalChallenges = _contentAnalytics['total_challenges'] ?? 0;
    final totalBadges = _contentAnalytics['total_badges_earned'] ?? 0;
    final uniqueBadges = _contentAnalytics['unique_badges'] ?? 0;
    final courseCompletion = _contentAnalytics['course_completion_rate'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Content Performance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            _buildMetricCard(
              title: 'Total Challenges',
              value: _formatNumber(totalChallenges),
              icon: Icons.emoji_events,
              color: Colors.amber,
              subtitle: 'Available',
            ),
            _buildMetricCard(
              title: 'Badges Earned',
              value: _formatNumber(totalBadges),
              icon: Icons.stars,
              color: Colors.purple,
              subtitle: '$uniqueBadges unique types',
            ),
            _buildMetricCard(
              title: 'Course Completion',
              value: '${courseCompletion.toStringAsFixed(1)}%',
              icon: Icons.school,
              color: AppColors.secondary,
              subtitle: 'Avg completion rate',
            ),
            _buildMetricCard(
              title: 'Avg Progress',
              value: '${(_contentAnalytics['avg_course_progress'] ?? 0).toStringAsFixed(0)}%',
              icon: Icons.trending_up,
              color: AppColors.tertiary,
              subtitle: 'Course progress',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChallengePerformance() {
    final challenges = _contentAnalytics['challenge_performance'] as List? ?? [];
    
    if (challenges.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No challenge data available',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Challenges (by Participation)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...challenges.take(10).map((challenge) {
              final title = challenge['title'] ?? 'Unknown';
              final participants = challenge['participants'] ?? 0;
              final completed = challenge['completed'] ?? 0;
              final completionRate = challenge['completion_rate'] ?? 0.0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCompletionColor(completionRate).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${completionRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getCompletionColor(completionRate),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$participants participants',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.check_circle, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$completed completed',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 70) return AppColors.tertiary;
    if (rate >= 40) return Colors.orange;
    return Colors.red;
  }

  // ===== HELPER METHODS =====

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatFeatureName(String key) {
    switch (key) {
      case 'goals':
        return 'Daily Goals';
      case 'challenges':
        return 'Challenges';
      case 'courses':
        return 'Mini Courses';
      case 'victory_wall':
        return 'Victory Wall';
      case 'ai_coach':
        return 'AI Coach';
      case 'gratitude':
        return 'Gratitude Journal';
      default:
        return key;
    }
  }
}
