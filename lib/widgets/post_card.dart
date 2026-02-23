import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../widgets/username_with_checkmark.dart';
import '../screens/profile/user_profile_screen.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/child_friendly_comment_picker.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final bool isCurrentUserPost;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.isCurrentUserPost = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUserId = userProvider.user?.id ?? '';
    final isAdmin = userProvider.user?.isAdmin ?? false;
    final isLikedByCurrentUser = post.isLikedByUser(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(0, -2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info and gradient accent
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.03),
                  AppColors.secondary.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final other = userProvider.getUserById(post.userId);
                      if (other != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(user: other),
                          ),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        // Enhanced user avatar with gradient ring
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                post.userName.isNotEmpty
                                    ? post.userName[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // User name and post time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UsernameWithCheckmark(
                                name: post.userName,
                                isPremium: context
                                    .read<UserProvider>()
                                    .isPremium(post.userId),
                                style: AppTextStyles.bodyBold,
                              ),
                              Text(
                                AppDateUtils.getRelativeTimeString(
                                    post.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Overflow actions: Delete (owner) or Report/Mute (others)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    switch (value) {
                      case 'delete':
                        if (onDelete != null) onDelete!();
                        break;
                      case 'admin_delete':
                        _confirmAdminDelete(context);
                        break;
                      case 'report':
                        _confirmReport(context);
                        break;
                      case 'mute':
                        _confirmMute(context);
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final List<PopupMenuEntry<String>> items = [];
                    
                    // Owner can delete their own post
                    if (isCurrentUserPost) {
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline),
                              SizedBox(width: 8),
                              Text('Delete Post')
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Admin can delete any post
                    if (isAdmin && !isCurrentUserPost) {
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'admin_delete',
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete (Admin)', style: TextStyle(color: Colors.red))
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Non-owners can report/mute
                    if (!isCurrentUserPost) {
                      items.addAll([
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined),
                              SizedBox(width: 8),
                              Text('Report Post')
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'mute',
                          child: Row(
                            children: [
                              Icon(Icons.volume_off_outlined),
                              SizedBox(width: 8),
                              Text('Mute User')
                            ],
                          ),
                        ),
                      ]);
                    }
                    
                    return items;
                  },
                ),
              ],
            ),
          ),

          // Post content with enhanced styling
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Text(
              post.content,
              style: AppTextStyles.body.copyWith(
                height: 1.5,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Image rendering intentionally disabled per Victory Wall policy (text-only)

          // Post interactions (likes, comments) with enhanced divider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.textSecondary.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Provider.of<PostProvider>(context, listen: false)
                        .likePost(post.id, currentUserId);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLikedByCurrentUser
                          ? AppColors.accent1.withOpacity(0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 6),
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            offset: const Offset(2, 2),
                            blurRadius: 6),
                      ],
                      border: Border.all(
                          color: isLikedByCurrentUser
                              ? AppColors.accent1.withOpacity(0.4)
                              : Colors.transparent,
                          width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLikedByCurrentUser
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isLikedByCurrentUser
                              ? AppColors.accent1
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          post.likesCount.toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isLikedByCurrentUser
                                ? AppColors.accent1
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showCommentsBottomSheet(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 6),
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            offset: const Offset(2, 2),
                            blurRadius: 6),
                      ],
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.comment_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          post.commentsCount.toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReport(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            _reportOption(
                ctx, 'Inappropriate language', 'inappropriate_language'),
            _reportOption(ctx, 'Spam or misleading', 'spam'),
            _reportOption(ctx, 'Bullying or harassment', 'bullying'),
            _reportOption(ctx, 'Violence or dangerous content', 'violence'),
            _reportOption(ctx, 'Other', 'other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (reason != null && context.mounted) {
      // Show confirmation that report was received
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Thank you for your report. We will review it shortly.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // TODO: Submit to flagged_posts table via PostProvider
    }
  }

  Widget _reportOption(BuildContext ctx, String label, String value) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body,
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _confirmMute(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mute this user?'),
            content: const Text(
                'You will no longer see posts from this user. You can unmute later in settings.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Mute')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    // TODO: Hook to provider to store muted user list and filter in feed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Muted ${post.userName}'),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmAdminDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.red),
                SizedBox(width: 8),
                Text('Admin Delete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete this post?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Post by: ${post.userName}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.content.length > 100
                        ? '${post.content.substring(0, 100)}...'
                        : post.content,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This action cannot be undone.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete Post'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Deleting post...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    // Delete the post
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isAdmin = userProvider.user?.isAdmin ?? false;

    final success = await postProvider.deletePost(post.id, isAdmin: isAdmin);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(success
                  ? 'Post deleted successfully'
                  : 'Failed to delete post'),
            ],
          ),
          backgroundColor: success ? AppColors.success : Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showCommentsBottomSheet(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments (${post.commentsCount})',
                      style: AppTextStyles.heading3,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Comments list
              Expanded(
                child: post.comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: post.comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItem(
                              context, post.comments[index]);
                        },
                      ),
              ),

              // Child-friendly comment picker
              if (currentUser != null) ...[
                ChildFriendlyCommentPicker(
                  postId: post.id,
                  onCommentAdded: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(BuildContext context, CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UsernameWithCheckmark(
                  name: comment.userName,
                  isPremium:
                      context.read<UserProvider>().isPremium(comment.userId),
                  style: AppTextStyles.bodyBold,
                  iconSize: 14,
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 4),
                Text(
                  AppDateUtils.getRelativeTimeString(comment.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
