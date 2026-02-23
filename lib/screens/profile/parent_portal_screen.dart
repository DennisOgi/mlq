import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/user_provider.dart';
import '../../services/parent_portal_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Parent Portal Screen - allows parents to view their children's analytics
/// Children link to parents by entering the parent's email in their account settings
class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen({super.key});

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  static const String _tutorialShownKey = 'parent_portal_tutorial_shown';
  
  final ParentPortalService _parentService = ParentPortalService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  Map<String, dynamic>? _childAnalytics;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _checkAndShowTutorial();
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_tutorialShownKey) ?? false;
    
    if (!hasShown && mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _showTutorialDialog();
        await prefs.setBool(_tutorialShownKey, true);
      }
    }
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.family_restroom, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('Parent Portal Guide')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTutorialSection(
                Icons.how_to_reg,
                'How It Works',
                'This portal lets you monitor your child\'s progress in the app. '
                'Your child must link their account to yours first.',
              ),
              const SizedBox(height: 16),
              _buildTutorialSection(
                Icons.link,
                'Linking Your Child',
                'To see your child\'s data:\n'
                '1. Your child opens their app\n'
                '2. Goes to Profile → Account Settings\n'
                '3. Enters YOUR email in "Parent Email"\n'
                '4. Come back here and tap Refresh',
              ),
              const SizedBox(height: 16),
              _buildTutorialSection(
                Icons.analytics,
                'What You Can See',
                '• XP and coin progress\n'
                '• Goal completion rates\n'
                '• Weekly activity chart\n'
                '• Active goals\n'
                '• Challenge participation\n'
                '• Gratitude entries',
              ),
              const SizedBox(height: 16),
              _buildTutorialSection(
                Icons.people,
                'Multiple Children',
                'If you have multiple children using the app, they can all link to your email. '
                'You\'ll see a selector to switch between them.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privacy: Only children who enter your email can be viewed by you.',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialSection(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadChildren() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final children = await _parentService.getMyChildren();
      
      setState(() {
        _children = children;
        _isLoading = false;
        
        if (children.isNotEmpty && _selectedChildId == null) {
          _selectedChildId = children.first['id'];
          _loadChildAnalytics();
        }
      });
    } catch (e) {
      debugPrint('Error loading children: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildAnalytics() async {
    if (_selectedChildId == null) return;
    
    setState(() => _isLoading = true);
    
    final analytics = await _parentService.getChildAnalytics(_selectedChildId!);
    
    setState(() {
      _childAnalytics = analytics.containsKey('error') ? null : analytics;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.user;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text('Parent Portal'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildNoChildrenView(currentUser?.email)
              : _buildDashboard(),
    );
  }

  Widget _buildNoChildrenView(String? parentEmail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.family_restroom,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Parent Portal',
                  style: AppTextStyles.heading.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your child\'s goal-setting journey',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
          
          const SizedBox(height: 32),
          
          // No children message
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.child_care,
                  size: 48,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Children Linked Yet',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 18,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To view your child\'s analytics, they need to add your email in their account settings.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 24),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'How to link your child:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstructionStep(1, 'Your child opens the app'),
                _buildInstructionStep(2, 'Goes to Profile → Account Settings'),
                _buildInstructionStep(3, 'Enters your email in "Parent Email" field'),
                if (parentEmail != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your email: $parentEmail',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildInstructionStep(4, 'Come back here and tap Refresh'),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
          
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: _loadChildren,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        // Child selector
        if (_children.length > 1) _buildChildSelector(),
        
        // Analytics content
        Expanded(
          child: _childAnalytics == null
              ? const Center(child: CircularProgressIndicator())
              : _buildAnalyticsContent(),
        ),
      ],
    );
  }

  Widget _buildChildSelector() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          final isSelected = child['id'] == _selectedChildId;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedChildId = child['id']);
              _loadChildAnalytics();
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isSelected ? Colors.white : AppColors.primary.withOpacity(0.1),
                    backgroundImage: child['avatar_url'] != null
                        ? NetworkImage(child['avatar_url'])
                        : null,
                    child: child['avatar_url'] == null
                        ? Icon(
                            Icons.person,
                            color: isSelected ? AppColors.primary : AppColors.primary,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    child['name'] ?? 'Child',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final stats = _childAnalytics!['stats'] as Map<String, dynamic>;
    final profile = _childAnalytics!['profile'] as Map<String, dynamic>;
    final mainGoals = _childAnalytics!['main_goals'] as List;
    final weeklyActivity = stats['weekly_activity'] as Map<String, int>;

    return RefreshIndicator(
      onRefresh: _loadChildAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child header
            _buildChildHeader(profile),
            
            const SizedBox(height: 20),
            
            // Stats overview
            _buildStatsOverview(stats),
            
            const SizedBox(height: 20),
            
            // Goal completion rates
            _buildCompletionRates(stats),
            
            const SizedBox(height: 20),
            
            // Weekly activity chart
            _buildWeeklyActivityChart(weeklyActivity),
            
            const SizedBox(height: 20),
            
            // Active goals
            if (mainGoals.isNotEmpty) _buildActiveGoals(mainGoals),
            
            const SizedBox(height: 20),
            
            // Engagement metrics
            _buildEngagementMetrics(stats),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChildHeader(Map<String, dynamic> profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? Icon(Icons.person, size: 35, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'] ?? 'Child',
                  style: AppTextStyles.heading.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level ${((profile['xp'] ?? 0) / 100).floor() + 1} Explorer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatsOverview(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total XP',
            '${stats['total_xp']}',
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Monthly XP',
            '${stats['monthly_xp']}',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Streak',
            '${stats['current_streak']} days',
            Icons.local_fire_department,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Coins',
            '${stats['coins']}',
            Icons.monetization_on,
            Colors.blue,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRates(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Completion',
            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildProgressBar(
            'Main Goals',
            stats['main_goal_completion_rate'],
            '${stats['main_goals_completed']}/${stats['main_goals_total']}',
            AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildProgressBar(
            'Daily Goals (30 days)',
            stats['daily_goal_completion_rate'],
            '${stats['daily_goals_completed']}/${stats['daily_goals_total']}',
            Colors.green,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildProgressBar(String label, int percentage, String count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
            Text('$percentage% ($count)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivityChart(Map<String, int> weeklyActivity) {
    final maxValue = weeklyActivity.values.fold(0, (max, v) => v > max ? v : max);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week\'s Activity',
            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyActivity.entries.map((entry) {
                final height = maxValue > 0 ? (entry.value / maxValue) * 80 : 0.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: entry.value > 0 ? AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildActiveGoals(List mainGoals) {
    final activeGoals = mainGoals.where((g) => g['is_completed'] != true).take(3).toList();
    
    if (activeGoals.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Goals',
            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...activeGoals.map((goal) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['title'] ?? 'Untitled Goal',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (goal['target_date'] != null)
                        Text(
                          'Due: ${_formatDate(goal['target_date'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (goal['progress'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${((goal['progress'] ?? 0) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          )),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildEngagementMetrics(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement',
            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEngagementItem(
                  Icons.emoji_events,
                  'Challenges',
                  '${stats['challenges_completed']}/${stats['challenges_joined']}',
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildEngagementItem(
                  Icons.favorite,
                  'Gratitude',
                  '${stats['gratitude_entries_count']}',
                  Colors.pink,
                ),
              ),
              Expanded(
                child: _buildEngagementItem(
                  Icons.military_tech,
                  'Badges',
                  '${stats['badges_count']}',
                  Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildEngagementItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
