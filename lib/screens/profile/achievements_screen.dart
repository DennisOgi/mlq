import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/badge_model.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final List<BadgeType> _allBadgeTypes = BadgeType.values;
  bool _isLoading = true;
  Map<BadgeType, bool> _unlockedBadges = {};

  @override
  void initState() {
    super.initState();
    _loadBadgeStatus();
  }

  Future<void> _loadBadgeStatus() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    
    // Initialize all badges as locked
    Map<BadgeType, bool> unlockedStatus = {};
    for (var badgeType in _allBadgeTypes) {
      final String badgeKey = 'badge_${badgeType.toString().split('.').last}';
      unlockedStatus[badgeType] = prefs.getBool(badgeKey) ?? false;
    }
    
    // Also check user's badges from provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    for (var badge in userProvider.badges) {
      unlockedStatus[badge.type] = true;
    }
    
    setState(() {
      _unlockedBadges = unlockedStatus;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Achievements', style: AppTextStyles.heading),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildAchievementsGrid(),
    );
  }

  Widget _buildAchievementsGrid() {
    final userProvider = Provider.of<UserProvider>(context);
    final earnedBadges = userProvider.badges;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress summary
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Achievements',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 8),
              Text(
                'You have unlocked ${earnedBadges.length} out of ${_allBadgeTypes.length} badges!',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: earnedBadges.length / _allBadgeTypes.length,
                backgroundColor: Colors.grey[200],
                color: AppColors.primary,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        ),
        
        // Badges grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _allBadgeTypes.length,
            itemBuilder: (context, index) {
              final badgeType = _allBadgeTypes[index];
              final isUnlocked = _unlockedBadges[badgeType] ?? false;
              
              // Create a temporary badge model to access name and image
              final tempBadge = BadgeModel(
                id: 'temp',
                userId: 'temp',
                type: badgeType,
                earnedDate: DateTime.now(),
              );
              
              return GestureDetector(
                onTap: () => _showBadgeDetails(context, badgeType, isUnlocked),
                child: _buildBadgeItem(tempBadge, isUnlocked),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(BadgeModel badge, bool isUnlocked) {
    return Container(
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
          Stack(
            alignment: Alignment.center,
            children: [
              // Badge image
              Opacity(
                opacity: isUnlocked ? 1.0 : 0.3,
                child: Image.asset(
                  badge.imageAsset,
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                ).animate(
                  onPlay: isUnlocked 
                      ? (controller) => controller.repeat(reverse: true) 
                      : null,
                ).fadeIn(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
              
              // Lock icon for locked badges
              if (!isUnlocked)
                const Icon(
                  Icons.lock,
                  size: 30,
                  color: Colors.black54,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              badge.name,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black : Colors.black54,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeType badgeType, bool isUnlocked) {
    // Create a temporary badge model to access properties
    final tempBadge = BadgeModel(
      id: 'temp',
      userId: 'temp',
      type: badgeType,
      earnedDate: DateTime.now(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tempBadge.name,
          style: AppTextStyles.heading,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Badge image
                Opacity(
                  opacity: isUnlocked ? 1.0 : 0.3,
                  child: Image.asset(
                    tempBadge.imageAsset,
                    height: 120,
                    width: 120,
                  ).animate(
                    onPlay: isUnlocked 
                        ? (controller) => controller.repeat(reverse: true) 
                        : null,
                  ).fadeIn(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
                
                // Lock icon for locked badges
                if (!isUnlocked)
                  const Icon(
                    Icons.lock,
                    size: 40,
                    color: Colors.black54,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isUnlocked 
                  ? 'Badge Unlocked!' 
                  : 'Badge Locked',
              style: AppTextStyles.subtitle.copyWith(
                color: isUnlocked ? AppColors.primary : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tempBadge.defaultDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            if (isUnlocked) ...[
              const SizedBox(height: 16),
              Text(
                'My Achievements',
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
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
