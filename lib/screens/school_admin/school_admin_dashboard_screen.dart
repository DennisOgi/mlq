import 'package:flutter/material.dart';
import '../../models/school_analytics_model.dart';
import '../../services/school_analytics_service.dart';
import 'package:intl/intl.dart';

class SchoolAdminDashboardScreen extends StatefulWidget {
  const SchoolAdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SchoolAdminDashboardScreen> createState() =>
      _SchoolAdminDashboardScreenState();
}

class _SchoolAdminDashboardScreenState
    extends State<SchoolAdminDashboardScreen> with SingleTickerProviderStateMixin {
  final SchoolAnalyticsService _analyticsService = SchoolAnalyticsService();
  
  late TabController _tabController;
  
  SchoolAnalytics? _schoolAnalytics;
  MonthlyLeaderboard? _monthlyLeaderboard;
  List<StudentPerformance> _studentsAtRisk = [];
  
  bool _isLoading = true;
  String? _schoolId;
  String _selectedMonth = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Check access
      final hasAccess = await _analyticsService.hasSchoolAdminAccess();
      if (!hasAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have school admin access'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Get school ID
      _schoolId = await _analyticsService.getCurrentUserSchoolId();
      if (_schoolId == null) {
        throw Exception('School ID not found');
      }

      // Load all data
      final analytics = await _analyticsService.getSchoolAnalytics(_schoolId!);
      final leaderboard = await _analyticsService.getMonthlyLeaderboard(
        _schoolId!,
        monthKey: _selectedMonth,
      );
      final atRisk = await _analyticsService.getStudentsAtRisk(_schoolId!);

      setState(() {
        _schoolAnalytics = analytics;
        _monthlyLeaderboard = leaderboard;
        _studentsAtRisk = atRisk;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
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
        title: const Text('School Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.warning), text: 'At Risk'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildLeaderboardTab(),
                _buildStudentsTab(),
                _buildAtRiskTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_schoolAnalytics == null) {
      return const Center(child: Text('No data available'));
    }

    final analytics = _schoolAnalytics!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // School name
            Text(
              analytics.schoolName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(analytics.generatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // Key metrics cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Total Students',
                  analytics.totalStudents.toString(),
                  Icons.people,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Active Students',
                  analytics.activeStudents.toString(),
                  Icons.person_add,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Total XP',
                  NumberFormat.compact().format(analytics.totalXp),
                  Icons.star,
                  Colors.amber,
                ),
                _buildMetricCard(
                  'Monthly XP',
                  NumberFormat.compact().format(analytics.monthlyXp),
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Courses Completed',
                  analytics.totalCoursesCompleted.toString(),
                  Icons.school,
                  Colors.purple,
                ),
                _buildMetricCard(
                  'Badges Earned',
                  analytics.totalBadgesEarned.toString(),
                  Icons.emoji_events,
                  Colors.pink,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Engagement rate
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Engagement Rate',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: analytics.engagementRate / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        analytics.engagementRate > 70
                            ? Colors.green
                            : analytics.engagementRate > 40
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${analytics.engagementRate.toStringAsFixed(1)}% of students are active this month',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Additional stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Statistics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      'Gratitude Entries',
                      analytics.totalGratitudeEntries.toString(),
                      Icons.favorite,
                    ),
                    const Divider(),
                    _buildStatRow(
                      'Challenges Completed',
                      analytics.totalChallengesCompleted.toString(),
                      Icons.flag,
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

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        // Month selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Top 20 Students - ${DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedMonth-01'))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _showMonthPicker,
              ),
            ],
          ),
        ),
        Expanded(
          child: _monthlyLeaderboard == null ||
                  _monthlyLeaderboard!.topStudents.isEmpty
              ? const Center(child: Text('No leaderboard data available'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _monthlyLeaderboard!.topStudents.length,
                    itemBuilder: (context, index) {
                      final student = _monthlyLeaderboard!.topStudents[index];
                      return _buildLeaderboardTile(student);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('All Students View'),
          const SizedBox(height: 8),
          const Text('Coming soon...'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Refresh Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildAtRiskTab() {
    return _studentsAtRisk.isEmpty
        ? const Center(child: Text('No students at risk'))
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _studentsAtRisk.length,
              itemBuilder: (context, index) {
                final student = _studentsAtRisk[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: student.avatarUrl != null
                          ? NetworkImage(student.avatarUrl!)
                          : null,
                      child: student.avatarUrl == null
                          ? Text(student.name[0].toUpperCase())
                          : null,
                    ),
                    title: Text(student.name),
                    subtitle: Text(
                      'Total XP: ${student.totalXp} • Monthly XP: ${student.monthlyXp}',
                    ),
                    trailing: const Icon(Icons.warning, color: Colors.orange),
                  ),
                );
              },
            ),
          );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(StudentPerformance student) {
    Color rankColor;
    if (student.rank == 1) {
      rankColor = Colors.amber;
    } else if (student.rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (student.rank == 3) {
      rankColor = Colors.brown[300]!;
    } else {
      rankColor = Colors.grey[600]!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: student.avatarUrl != null
                  ? NetworkImage(student.avatarUrl!)
                  : null,
              child: student.avatarUrl == null
                  ? Text(student.name[0].toUpperCase())
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${student.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly XP: ${student.monthlyXp}'),
            Text(
              'Courses: ${student.coursesCompleted} • Badges: ${student.badgesEarned}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${student.monthlyXp} XP',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '₦${student.coins.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showMonthPicker() {
    // Simple month picker - you can enhance this
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: const Text('Month picker coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
