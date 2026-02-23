import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class ChildFriendlyCommentPicker extends StatefulWidget {
  final String postId;
  final Function onCommentAdded;

  const ChildFriendlyCommentPicker({
    super.key,
    required this.postId,
    required this.onCommentAdded,
  });

  @override
  State<ChildFriendlyCommentPicker> createState() =>
      _ChildFriendlyCommentPickerState();
}

class _ChildFriendlyCommentPickerState
    extends State<ChildFriendlyCommentPicker> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final currentUser = userProvider.user;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.secondary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pick a reaction!',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '5 categories',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          // Categories tabs
          DefaultTabController(
            length: 5,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      _buildTab(Icons.emoji_emotions_rounded, 'Cheer'),
                      _buildTab(Icons.celebration_rounded, 'Praise'),
                      _buildTab(Icons.lightbulb_rounded, 'Inspire'),
                      _buildTab(Icons.favorite_rounded, 'Support'),
                      _buildTab(Icons.sentiment_very_satisfied_rounded, 'Fun'),
                    ],
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.secondary,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: TabBarView(
                    children: [
                      // Cheer - Encouraging comments
                      _buildCommentGrid(
                        context,
                        [
                          CommentOption(
                              text: "You can do it! 💪",
                              emoji: "💪",
                              color: const Color(0xFF4A90D9),
                              iconData: Icons.fitness_center),
                          CommentOption(
                              text: "Keep going! 🚀",
                              emoji: "🚀",
                              color: const Color(0xFF7B68EE),
                              iconData: Icons.rocket_launch),
                          CommentOption(
                              text: "Believe in yourself! ⭐",
                              emoji: "⭐",
                              color: const Color(0xFFFFB347),
                              iconData: Icons.star_rounded),
                          CommentOption(
                              text: "Never give up! 🌟",
                              emoji: "🌟",
                              color: const Color(0xFFFF8C42),
                              iconData: Icons.auto_awesome),
                          CommentOption(
                              text: "You're doing great! 🔥",
                              emoji: "🔥",
                              color: const Color(0xFFE74C3C),
                              iconData: Icons.local_fire_department),
                          CommentOption(
                              text: "Stay strong! 💎",
                              emoji: "💎",
                              color: const Color(0xFF00CED1),
                              iconData: Icons.diamond_rounded),
                        ],
                        postProvider,
                        currentUser,
                      ),

                      // Praise - Celebrating comments
                      _buildCommentGrid(
                        context,
                        [
                          CommentOption(
                              text: "Amazing job! 🎉",
                              emoji: "🎉",
                              color: const Color(0xFFE74C3C),
                              iconData: Icons.celebration),
                          CommentOption(
                              text: "Way to go champ! 🏆",
                              emoji: "🏆",
                              color: const Color(0xFFFFD700),
                              iconData: Icons.emoji_events),
                          CommentOption(
                              text: "You're awesome! 🌟",
                              emoji: "🌟",
                              color: const Color(0xFF9B59B6),
                              iconData: Icons.auto_awesome),
                          CommentOption(
                              text: "So proud of you! 👏",
                              emoji: "👏",
                              color: const Color(0xFF27AE60),
                              iconData: Icons.thumb_up_rounded),
                          CommentOption(
                              text: "Nailed it! 🎯",
                              emoji: "🎯",
                              color: const Color(0xFF3498DB),
                              iconData: Icons.gps_fixed),
                          CommentOption(
                              text: "Superstar! ⭐",
                              emoji: "⭐",
                              color: const Color(0xFFF39C12),
                              iconData: Icons.star_purple500_rounded),
                        ],
                        postProvider,
                        currentUser,
                      ),

                      // Inspire - Motivational comments
                      _buildCommentGrid(
                        context,
                        [
                          CommentOption(
                              text: "So inspiring! 💡",
                              emoji: "💡",
                              color: const Color(0xFFF1C40F),
                              iconData: Icons.lightbulb_rounded),
                          CommentOption(
                              text: "I want to try this! 🚀",
                              emoji: "🚀",
                              color: const Color(0xFF3498DB),
                              iconData: Icons.rocket_launch),
                          CommentOption(
                              text: "Great ideas! 💭",
                              emoji: "💭",
                              color: const Color(0xFF9B59B6),
                              iconData: Icons.cloud_rounded),
                          CommentOption(
                              text: "You're my hero! 🦸",
                              emoji: "🦸",
                              color: const Color(0xFFE74C3C),
                              iconData: Icons.person_rounded),
                          CommentOption(
                              text: "This motivates me! 🌈",
                              emoji: "🌈",
                              color: const Color(0xFF1ABC9C),
                              iconData: Icons.wb_sunny_rounded),
                          CommentOption(
                              text: "Goals! 🎯",
                              emoji: "🎯",
                              color: const Color(0xFFE67E22),
                              iconData: Icons.flag_rounded),
                        ],
                        postProvider,
                        currentUser,
                      ),

                      // Support - Caring comments
                      _buildCommentGrid(
                        context,
                        [
                          CommentOption(
                              text: "I'm here for you! 🤗",
                              emoji: "🤗",
                              color: const Color(0xFFFF6B9D),
                              iconData: Icons.volunteer_activism),
                          CommentOption(
                              text: "Sending good vibes! ✨",
                              emoji: "✨",
                              color: const Color(0xFF9B59B6),
                              iconData: Icons.auto_awesome),
                          CommentOption(
                              text: "You matter! 💜",
                              emoji: "💜",
                              color: const Color(0xFF8E44AD),
                              iconData: Icons.favorite_rounded),
                          CommentOption(
                              text: "We believe in you! 🌻",
                              emoji: "🌻",
                              color: const Color(0xFFF39C12),
                              iconData: Icons.local_florist),
                          CommentOption(
                              text: "Stay positive! 🌞",
                              emoji: "🌞",
                              color: const Color(0xFFFFB347),
                              iconData: Icons.wb_sunny_rounded),
                          CommentOption(
                              text: "You're not alone! 🤝",
                              emoji: "🤝",
                              color: const Color(0xFF3498DB),
                              iconData: Icons.handshake_rounded),
                        ],
                        postProvider,
                        currentUser,
                      ),

                      // Fun - Playful comments
                      _buildCommentGrid(
                        context,
                        [
                          CommentOption(
                              text: "This is epic! 😎",
                              emoji: "😎",
                              color: const Color(0xFF2ECC71),
                              iconData: Icons.sentiment_very_satisfied),
                          CommentOption(
                              text: "Love this! 😍",
                              emoji: "😍",
                              color: const Color(0xFFE74C3C),
                              iconData: Icons.favorite_rounded),
                          CommentOption(
                              text: "So cool! 🆒",
                              emoji: "🆒",
                              color: const Color(0xFF3498DB),
                              iconData: Icons.ac_unit_rounded),
                          CommentOption(
                              text: "Haha nice! 😄",
                              emoji: "😄",
                              color: const Color(0xFFF39C12),
                              iconData: Icons.sentiment_satisfied_alt),
                          CommentOption(
                              text: "Mind blown! 🤯",
                              emoji: "🤯",
                              color: const Color(0xFF9B59B6),
                              iconData: Icons.psychology_rounded),
                          CommentOption(
                              text: "Legendary! 👑",
                              emoji: "👑",
                              color: const Color(0xFFFFD700),
                              iconData: Icons.workspace_premium),
                        ],
                        postProvider,
                        currentUser,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.bodyBold.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentGrid(
    BuildContext context,
    List<CommentOption> options,
    PostProvider postProvider,
    UserModel currentUser,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        return _buildCommentButton(
            context, option, postProvider, currentUser, index);
      },
    );
  }

  Widget _buildCommentButton(
    BuildContext context,
    CommentOption option,
    PostProvider postProvider,
    UserModel currentUser,
    int index,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _addComment(context, option.text, postProvider, currentUser),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                option.color,
                option.color.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: option.color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background emoji
              Positioned(
                right: -6,
                bottom: -6,
                child: Text(
                  option.emoji,
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
              // Shimmer overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        option.iconData,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.text,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (index * 40).ms)
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }

  Future<void> _addComment(
    BuildContext context,
    String commentText,
    PostProvider postProvider,
    UserModel currentUser,
  ) async {
    try {
      final result = await postProvider.addCommentV2(
        widget.postId,
        CommentModel(
          id: const Uuid().v4(),
          userId: currentUser.id,
          userName: currentUser.name,
          content: commentText,
          createdAt: DateTime.now(),
        ),
      );

      // Show appropriate feedback
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Comment posted! ✅',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (result.offlineSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comment saved locally. Will sync when online.',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Could not add comment. Please try again.',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Call the callback
      widget.onCommentAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Error adding comment',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class CommentOption {
  final String text;
  final String emoji;
  final Color color;
  final IconData iconData;

  CommentOption({
    required this.text,
    required this.emoji,
    required this.color,
    required this.iconData,
  });
}
