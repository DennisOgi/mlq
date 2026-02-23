import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share your win',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'I accomplished...',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.celebration, size: 18),
              label: Text(_submitting ? 'Posting...' : 'Post'),
            ),
          ),
        ],
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
