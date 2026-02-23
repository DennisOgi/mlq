import 'package:flutter/material.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';

/// Admin screen for monitoring security and suspicious activities
class SecurityMonitoringScreen extends StatefulWidget {
  const SecurityMonitoringScreen({super.key});

  @override
  State<SecurityMonitoringScreen> createState() => _SecurityMonitoringScreenState();
}

class _SecurityMonitoringScreenState extends State<SecurityMonitoringScreen> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _suspiciousActivities = [];
  Map<String, dynamic> _systemStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load suspicious activities
      final activities = await _supabaseService.client
          .from('suspicious_activities')
          .select('*, profiles(name)')
          .eq('resolved', false)
          .order('created_at', ascending: false)
          .limit(50);
      
      // Load system statistics
      final stats = await _supabaseService.client.rpc('get_security_stats');
      
      setState(() {
        _suspiciousActivities = List<Map<String, dynamic>>.from(activities);
        _systemStats = Map<String, dynamic>.from(stats ?? {});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading security data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveActivity(String activityId) async {
    try {
      await _supabaseService.client
          .from('suspicious_activities')
          .update({'resolved': true})
          .eq('id', activityId);
      
      await _loadSecurityData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity marked as resolved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving activity: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    // Check if user is admin
    if (userProvider.user?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.error,
        ),
        body: Center(
          child: Text(
            'You do not have permission to access this screen.',
            style: AppTextStyles.body,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Monitoring'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSecurityData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  _buildSuspiciousActivitiesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Statistics',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Users',
                _systemStats['active_users']?.toString() ?? '0',
                Icons.people,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Goals Today',
                _systemStats['goals_completed_today']?.toString() ?? '0',
                Icons.check_circle,
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Suspicious Activities',
                _suspiciousActivities.length.toString(),
                Icons.warning,
                AppColors.error,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Rate Limit Hits',
                _systemStats['rate_limit_hits']?.toString() ?? '0',
                Icons.speed,
                AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading1.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspiciousActivitiesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suspicious Activities',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_suspiciousActivities.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 12),
                Text(
                  'No suspicious activities detected',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suspiciousActivities.length,
            itemBuilder: (context, index) {
              final activity = _suspiciousActivities[index];
              return _buildActivityCard(activity);
            },
          ),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final severity = activity['severity'] as String;
    final activityType = activity['activity_type'] as String;
    final description = activity['description'] as String;
    final userName = activity['profiles']?['name'] ?? 'Unknown User';
    final createdAt = DateTime.parse(activity['created_at']);
    
    Color severityColor;
    IconData severityIcon;
    
    switch (severity) {
      case 'critical':
        severityColor = AppColors.error;
        severityIcon = Icons.error;
        break;
      case 'high':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityColor = AppColors.warning;
        severityIcon = Icons.info;
        break;
      default:
        severityColor = AppColors.textSecondary;
        severityIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severityIcon, color: severityColor, size: 20),
              const SizedBox(width: 8),
              Text(
                severity.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: severityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activityType.replaceAll('_', ' ').toUpperCase(),
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'User: $userName',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _resolveActivity(activity['id']),
                child: Text(
                  'Mark as Resolved',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
