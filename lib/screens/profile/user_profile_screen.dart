import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../constants/app_constants.dart' show AppTextStyles;
import '../../theme/app_colors.dart';
import '../../widgets/username_with_checkmark.dart';
import '../../providers/user_provider.dart';


/// Read-only profile screen for viewing other users.
class UserProfileScreen extends StatelessWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isPremium = userProvider.isPremium(user.id);

    return Scaffold(
      appBar: AppBar(
        title: UsernameWithCheckmark(
          name: user.name,
          isPremium: isPremium,
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user.avatarUrl != null
                  ? (user.avatarUrl!.startsWith('assets/')
                      ? AssetImage(user.avatarUrl!) as ImageProvider
                      : NetworkImage(user.avatarUrl!))
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: AppTextStyles.heading2.copyWith(fontSize: 40),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            UsernameWithCheckmark(
              name: user.name,
              isPremium: isPremium,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 8),
            Text('${user.xp} XP', style: AppTextStyles.body),
            const SizedBox(height: 24),
            // Additional stats could be added here later.
            _buildStatTile('Badges', user.badges.length.toString()),
            _buildStatTile('Coins', user.coins.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, String value) {
    return ListTile(
      title: Text(title, style: AppTextStyles.body),
      trailing: Text(value, style: AppTextStyles.heading3),
    );
  }
}
