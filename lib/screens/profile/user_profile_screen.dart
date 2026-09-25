import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../constants/app_constants.dart' show AppTextStyles;
import '../../theme/app_colors.dart';
import '../../widgets/username_with_checkmark.dart';
import '../../providers/user_provider.dart';

/// Profile screen for viewing other users.
class UserProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _fullUser;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFullProfile();
  }

  Future<void> _fetchFullProfile() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 Fetching profile for user ID: ${widget.user.id}, name: ${widget.user.name}');
      
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, name, age, avatar_url, xp, monthly_xp, coins, badges, interests, parent_email, weekly_reports_enabled, is_premium, timezone, school_id, school_name')
          .eq('id', widget.user.id)
          .maybeSingle();

      debugPrint('📦 Profile response: ${response != null ? "Data received" : "NULL response"}');
      
      if (response != null) {
        debugPrint('✅ Profile data - XP: ${response['xp']}, Monthly XP: ${response['monthly_xp']}, Badges: ${(response['badges'] as List?)?.length ?? 0}');
        
        if (mounted) {
          setState(() {
            _fullUser = UserModel(
              id: response['id'],
              name: response['name'] ?? 'Unknown User',
              age: (response['age'] as int?) ?? 0,
              avatarUrl: response['avatar_url'],
              xp: (response['xp'] as int?) ?? 0,
              monthlyXp: (response['monthly_xp'] as int?) ?? 0,
              coins: (response['coins'] as num?)?.toDouble() ?? 0.0,
              badges: List<String>.from(response['badges'] ?? []),
              interests: List<String>.from(response['interests'] ?? []),
              email: null,
              parentEmail: response['parent_email'],
              weeklyReportsEnabled: response['weekly_reports_enabled'] ?? false,
              isPremium: response['is_premium'] ?? false,
              isAdmin: false,
              timezone: response['timezone'],
              schoolId: response['school_id'],
              schoolName: response['school_name'],
            );
            _isLoading = false;
          });
        }
      } else {
        debugPrint('⚠️ Profile response is null for user ${widget.user.id}');
        if (mounted) {
          setState(() {
            _errorMessage = 'User profile not found';
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching full user profile: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isPremium = userProvider.isPremium(widget.user.id);
    
    // CRITICAL: Always use _fullUser if available, never fall back to widget.user
    // widget.user might have stale/incomplete data from the leaderboard
    final displayUser = _fullUser;

    return Scaffold(
      appBar: AppBar(
        title: UsernameWithCheckmark(
          name: displayUser?.name ?? widget.user.name,
          isPremium: isPremium,
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || displayUser == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Failed to load profile',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchFullProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: displayUser.avatarUrl != null
                            ? (displayUser.avatarUrl!.startsWith('assets/')
                                ? AssetImage(displayUser.avatarUrl!) as ImageProvider
                                : NetworkImage(displayUser.avatarUrl!))
                            : null,
                        child: displayUser.avatarUrl == null
                            ? Text(
                                displayUser.name.isNotEmpty
                                    ? displayUser.name[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.heading2.copyWith(fontSize: 40),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      UsernameWithCheckmark(
                        name: displayUser.name,
                        isPremium: isPremium,
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${displayUser.xp} XP',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (displayUser.monthlyXp > 0)
                        Text(
                          '${displayUser.monthlyXp} Monthly XP',
                          style: AppTextStyles.caption.copyWith(color: Colors.grey),
                        ),
                      const SizedBox(height: 24),
                      _buildStatTile('Badges', displayUser.badges.length.toString(), Icons.emoji_events),
                      _buildStatTile('Coins', displayUser.coins.toStringAsFixed(1), Icons.monetization_on),
                      const SizedBox(height: 24),
                      if (displayUser.badges.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Earned Badges', style: AppTextStyles.heading3),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: displayUser.badges.map((badgeName) {
                            return Chip(
                              label: Text(badgeName, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              avatar: const Icon(Icons.star, size: 16, color: AppColors.secondary),
                            );
                          }).toList(),
                        )
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        trailing: Text(value, style: AppTextStyles.heading3),
      ),
    );
  }
}
