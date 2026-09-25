import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/entitlements.dart';
import '../widgets/feature_lock_card.dart';
import '../services/badge_service.dart';
import '../services/victory_wall_service.dart';

class VictoryComposer extends StatefulWidget {
  const VictoryComposer({super.key});

  @override
  State<VictoryComposer> createState() => _VictoryComposerState();
}

class _VictoryComposerState extends State<VictoryComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (!Entitlements.hasPaidAccess(user)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: FeatureLockCard(
          compact: true,
          title: 'Post on the Victory Wall',
          description:
              'Sharing wins unlocks with a paid plan. You can still read the feed.',
          icon: Icons.celebration_rounded,
        ),
      );
    }

    final name = user?.name.trim() ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Share a win…',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _starter('🏆', 'Achievement', 'I achieved '),
              const SizedBox(width: 8),
              _starter('😊', 'Feeling', 'Today I feel '),
              const Spacer(),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.textOnGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Text(
                  _submitting ? 'Posting…' : 'Post',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _starter(String emoji, String label, String prefix) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (!_controller.text.startsWith(prefix)) {
            _controller.text = prefix + _controller.text;
          }
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            '$emoji $label',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      setState(() => _error = 'Please enter your victory');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null) {
      setState(() {
        _submitting = false;
        _error = 'You must be signed in';
      });
      return;
    }

    final newPost = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: content,
      createdAt: DateTime.now(),
    );

    final result = await postProvider.addPost(newPost);

    if (mounted) {
      if (result['success']) {
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Victory shared successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Track victory post and check for badges
        try {
          final badgeService = BadgeService();
          // Increment local counter for victory posts
          await badgeService.trackVictoryPost();
          // Check if any new badges are earned
          final newBadges = await badgeService.checkForAchievements();
          // Show dialog(s) and auto-post badge celebration(s)
          for (final badge in newBadges) {
            if (!mounted) break;
            badgeService.showBadgeEarnedDialog(context, badge);
            // Also share an automatic victory post for the badge
            try {
              await VictoryWallService.createBadgeEarnedPost(
                userProvider: userProvider,
                postProvider: postProvider,
                badge: badge,
              );
            } catch (_) {}
          }
        } catch (e) {
          // Non-fatal; posting succeeded even if badge checks fail
        }
      } else {
        setState(() => _error = result['message'] ?? 'Failed to post');
      }
    }

    if (mounted) setState(() => _submitting = false);
  }
}
