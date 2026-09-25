import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../widgets/username_with_checkmark.dart';
import '../screens/profile/user_profile_screen.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/date_utils.dart';
import '../widgets/child_friendly_comment_picker.dart';

class PostCard extends StatefulWidget {
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
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isVoting = false;

  PostModel get post => widget.post;
  bool get isCurrentUserPost => widget.isCurrentUserPost;
  VoidCallback? get onDelete => widget.onDelete;

  Color _priorityColor() {
    switch (post.priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUserId = userProvider.user?.id ?? '';
    final isAdmin = userProvider.user?.isAdmin ?? false;
    final isLikedByCurrentUser = post.isLikedByUser(currentUserId);
    final accentColor = post.isAdminPost
        ? _priorityColor()
        : post.isPoll
            ? AppColors.secondary
            : AppColors.secondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
        border: Border.all(
          color: post.isPinned ? accentColor : AppColors.border,
          width: post.isPinned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
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
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.plum, AppColors.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primarySoft,
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
                                name: post.isAdminPost || post.isPoll
                                    ? 'MLQ Team'
                                    : post.userName,
                                isPremium: post.isAdminPost || post.isPoll
                                    ? true
                                    : context
                                        .read<UserProvider>()
                                        .isPremium(post.userId),
                                style: AppTextStyles.bodyBold,
                              ),
                              Row(
                                children: [
                                  if (post.isPinned) ...[
                                    Icon(Icons.push_pin,
                                        size: 12, color: accentColor),
                                    const SizedBox(width: 4),
                                  ],
                                  if (post.isAdminPost)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _priorityColor().withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'OFFICIAL',
                                        style: AppTextStyles.caption.copyWith(
                                          color: _priorityColor(),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (post.isPoll)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'POLL',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
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
                    
                    // Owner can delete their own user posts
                    if (isCurrentUserPost && !isAdmin) {
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

                    // Admins can delete any post, announcement, or poll
                    if (isAdmin) {
                      items.add(
                        PopupMenuItem<String>(
                          value: 'admin_delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                post.isPoll
                                    ? 'Delete Poll'
                                    : post.isAdminPost
                                        ? 'Delete Announcement'
                                        : 'Delete (Admin)',
                                style: const TextStyle(color: Colors.red),
                              ),
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

          if (_achievement() case final a?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AchievementBanner(
                art: a.art,
                label: a.label,
                headline: a.headline,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _buildPostBody(context),
          ),

          // Image rendering intentionally disabled per Victory Wall policy (text-only)

          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                _ReactionPill(
                  icon: isLikedByCurrentUser
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: post.likesCount.toString(),
                  active: isLikedByCurrentUser,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Provider.of<PostProvider>(context, listen: false)
                        .likePost(post.id, currentUserId);
                  },
                ),
                const SizedBox(width: 8),
                _ReactionPill(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: post.commentsCount == 1
                      ? '1 comment'
                      : '${post.commentsCount} comments',
                  onTap: () => _showCommentsBottomSheet(context),
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

  /// Auto-generated win posts (badge, challenge, goal, milestone) are plain
  /// text, so they are recognised by the phrasing VictoryWallService uses.
  ({String art, String label, String headline})? _achievement() {
    if (post.isPoll || post.isAdminPost) return null;
    final text = post.content;
    final t = text.toLowerCase();
    final quoted = RegExp("'([^']{2,80})'").firstMatch(text)?.group(1);
    final firstName = post.userName.trim().split(' ').first;
    const dir = 'assets/images/badges';

    if (t.contains('badge') &&
        (t.contains('unlocked') || t.contains('earned') || t.contains('mine'))) {
      return (
        art: '$dir/achievers_medal.png',
        label: 'Badge unlocked',
        headline: quoted != null
            ? '$firstName earned the $quoted badge'
            : '$firstName earned a new badge',
      );
    }
    if (t.contains('challenge') &&
        RegExp(r'complet|conquer|crush|master|finished').hasMatch(t)) {
      return (
        art: '$dir/all_time_champion.png',
        label: 'Challenge complete',
        headline: quoted != null
            ? '$firstName completed $quoted'
            : '$firstName completed a challenge',
      );
    }
    if (t.contains('milestone achieved')) {
      return (
        art: '$dir/peak_reacher.png',
        label: 'Milestone',
        headline: '$firstName reached a milestone',
      );
    }
    if (t.contains('goal') &&
        quoted != null &&
        RegExp(r'crush|complet|conquer|done|achieved|finished').hasMatch(t)) {
      return (
        art: '$dir/goal_voyager.png',
        label: 'Goal complete',
        headline: '$firstName completed $quoted',
      );
    }
    return null;
  }

  Widget _buildPostBody(BuildContext context) {
    if (post.isPoll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.content,
            style: AppTextStyles.heading3.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildPollOptions(context),
          if (post.isExpired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This poll has ended.',
                style: AppTextStyles.caption.copyWith(color: Colors.grey),
              ),
            ),
        ],
      );
    }

    if (post.isAdminPost) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.title != null && post.title!.isNotEmpty)
            Text(
              post.title!,
              style: AppTextStyles.heading3.copyWith(
                color: _priorityColor(),
                fontSize: 17,
              ),
            ),
          if (post.title != null && post.title!.isNotEmpty)
            const SizedBox(height: 8),
          Text(
            post.content,
            style: AppTextStyles.body.copyWith(
              height: 1.5,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    return Text(
      post.content,
      style: AppTextStyles.body.copyWith(
        height: 1.5,
        fontSize: 15,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPollOptions(BuildContext context) {
    final totalVotes = post.totalPollVotes;
    final showResults = post.hasUserVoted || post.isExpired;

    if (post.pollOptions.isEmpty) {
      return Text(
        'Loading poll options...',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      );
    }

    return Column(
      children: post.pollOptions.map((option) {
        final fraction =
            totalVotes > 0 ? option.voteCount / totalVotes : 0.0;
        final percent = (fraction * 100).round();
        final isSelected = post.userVoteOptionId == option.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: (!showResults && !_isVoting && !post.isExpired)
                ? () => _castVote(context, option.id)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textSecondary.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? AppColors.secondary.withOpacity(0.08)
                    : AppColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: AppTextStyles.body.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (showResults)
                        Text(
                          '$percent%',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                    ],
                  ),
                  if (showResults) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalVotes > 0 ? fraction : 0,
                        minHeight: 6,
                        backgroundColor:
                            AppColors.textSecondary.withOpacity(0.12),
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _castVote(BuildContext context, String optionId) async {
    setState(() => _isVoting = true);
    final result = await context.read<PostProvider>().voteOnPoll(
          postId: post.id,
          optionId: optionId,
        );
    if (!mounted) return;
    setState(() => _isVoting = false);

    final message = result['message'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Vote recorded! Thanks for participating.'
              : (message ?? 'Could not submit vote.'),
        ),
        backgroundColor:
            result['success'] == true ? AppColors.secondary : Colors.red,
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
                Text(
                  post.isPoll
                      ? 'Delete this poll and all votes?'
                      : post.isAdminPost
                          ? 'Delete this announcement?'
                          : 'Are you sure you want to delete this post?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                    (post.title ?? post.content).length > 100
                        ? '${(post.title ?? post.content).substring(0, 100)}...'
                        : (post.title ?? post.content),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  post.isPoll
                      ? 'This cannot be undone and all votes will be removed.'
                      : 'This action cannot be undone.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
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

class _ReactionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ReactionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: active ? AppColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementBanner extends StatelessWidget {
  final String art;
  final String label;
  final String headline;

  const _AchievementBanner({
    required this.art,
    required this.label,
    required this.headline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.plum, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              art,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.secondary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: Colors.white,
                    height: 1.25,
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