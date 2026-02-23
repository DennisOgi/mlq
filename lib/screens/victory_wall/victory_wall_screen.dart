import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../widgets/victory_composer.dart';
import '../../services/badge_service.dart';
import '../../services/victory_wall_service.dart';
import '../community/community_detail_screen.dart';
import '../subscription/subscription_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Victory Wall scopes and sorting (top-level as enums cannot be nested in classes)
enum _Scope { all, mine, school }
enum _Sort { newest, mostLiked }

class VictoryWallScreen extends StatefulWidget {
  final bool isInHomeScreen;
  
  const VictoryWallScreen({super.key, this.isInHomeScreen = false});

  @override
  State<VictoryWallScreen> createState() => _VictoryWallScreenState();
}

class _VictoryWallScreenState extends State<VictoryWallScreen> {
  // Local state for filtering and sorting (no backend dependency)
  final ScrollController _scrollController = ScrollController();
  _Scope _scope = _Scope.all;
  _Sort _sort = _Sort.newest;

  // New posts polling/banner
  Timer? _pollTimer;
  DateTime? _latestSeen;
  bool _hasNewPostsBanner = false;

  @override
  void initState() {
    super.initState();
    // Initialize latest seen from current provider state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final posts = context.read<PostProvider>().posts;
      if (posts.isNotEmpty) {
        _latestSeen = posts.map((p) => p.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      }
      _syncVictoryPostCountAndCheckBadges();
      context.read<CommunityProvider>().loadMyCommunities();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final provider = context.read<PostProvider>();
      final beforeLatest = _latestSeen;
      try {
        await provider.maybeRefreshPosts(minAge: const Duration(seconds: 30), silent: true);
        final posts = provider.posts;
        if (posts.isNotEmpty) {
          final latestNow = posts.map((p) => p.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
          if (beforeLatest == null || latestNow.isAfter(beforeLatest)) {
            if (mounted) setState(() => _hasNewPostsBanner = true);
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final posts = postProvider.posts;
    final visiblePosts = _computeVisiblePosts(posts);
    final userProvider = Provider.of<UserProvider>(context);
    final bool isLoading = postProvider.isLoading;
    final bool isLoadingMore = postProvider.isLoadingMore;
    final bool hasMorePosts = postProvider.hasMorePosts;
    final String? error = postProvider.lastError;

    // Show error snackbar if there's an error
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(error)),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => postProvider.refreshPosts(),
              ),
            ),
          );
          postProvider.clearError();
        }
      });
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Victory Wall', 
            style: TextStyle(
              color: Colors.white, 
              fontSize: 24, 
              fontFamily: AppTextStyles.heading2.fontFamily,
              fontWeight: FontWeight.bold,
            )
          ),
          backgroundColor: AppColors.primary,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                await postProvider.refreshPosts();
              },
              tooltip: 'Refresh posts',
            ),
          ],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.transparent,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Feed', icon: Icon(Icons.forum)),
              Tab(text: 'Communities', icon: Icon(Icons.people_alt)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await postProvider.refreshPosts();
                return;
              },
              color: AppColors.secondary,
              backgroundColor: AppColors.background,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface
                ),
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.secondary))
                    : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _scrollController,
                          itemCount: (visiblePosts.isEmpty ? 2 : visiblePosts.length + 2), // +2 for header and load more button
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeaderChips(),
                                  if (_hasNewPostsBanner) _buildNewPostsBanner(postProvider),
                                  const VictoryComposer(),
                                ],
                              );
                            }
                            // If there are no posts to show, render inline empty state below composer
                            if (visiblePosts.isEmpty && index == 1) {
                              return _buildInlineEmptyState();
                            }
                            // Last item: Load more button
                            if (index == visiblePosts.length + 1) {
                              return _buildLoadMoreButton(postProvider, hasMorePosts, isLoadingMore);
                            }
                            
                            final post = visiblePosts[index - 1];
                            // Check if post is from the current user
                            final bool isCurrentUserPost = post.userId == userProvider.user?.id;
                            return PostCard(
                              post: post,
                              isCurrentUserPost: isCurrentUserPost,
                              onDelete: isCurrentUserPost ? () => _confirmDeletePost(context, post) : null,
                            ).animate(delay: (50 * index).ms)
                             .fadeIn(duration: 300.ms)
                             .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
                          },
                        ),
              ),
            ),
            _buildCommunitiesBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitiesBody(BuildContext context) {
    final communityProvider = Provider.of<CommunityProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isPremium = userProvider.user?.isPremium ?? false;
    final communities = communityProvider.activeCommunities;
    final pendingInvites = communityProvider.pendingInvites;

    if (communityProvider.isLoading && communities.isEmpty && pendingInvites.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await communityProvider.loadMyCommunities();
      },
      color: AppColors.secondary,
      backgroundColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Premium header card with gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPremium
                    ? [AppColors.primary, AppColors.primary.withOpacity(0.85)]
                    : [Colors.grey.shade600, Colors.grey.shade500],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isPremium ? AppColors.primary : Colors.grey).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPremium ? Icons.groups_rounded : Icons.lock_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPremium ? 'Your Communities' : 'Communities',
                            style: AppTextStyles.heading3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPremium
                                ? 'Lead and inspire your groups'
                                : 'Premium feature',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPremium && (communities.isNotEmpty || pendingInvites.isNotEmpty))
                      Row(
                        children: [
                          if (pendingInvites.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mail, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${pendingInvites.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (communities.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${communities.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isPremium
                      ? 'Create spaces for your health group, study circle, team or friends to grow together.'
                      : 'Upgrade to Premium to create and manage your own communities.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isPremium
                        ? () => _showCreateCommunityDialog(context)
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionManagementScreen(),
                            ),
                          ),
                    icon: Icon(
                      isPremium ? Icons.add_circle_outline : Icons.star_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isPremium ? 'Create New Community' : 'Upgrade to Premium',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isPremium ? AppColors.primary : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
          
          const SizedBox(height: 20),
          
          // Pending invites section
          if (pendingInvites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Invites',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingInvites.length}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),
            for (int i = 0; i < pendingInvites.length; i++)
              _buildPendingInviteCard(pendingInvites[i], i, communityProvider),
            const SizedBox(height: 20),
          ],
          
          // Section header for communities list
          if (communities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Communities',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
          
          if (communities.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.diversity_3_rounded,
                      size: 48,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No communities yet',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPremium
                        ? 'Create your first community and start building your tribe!'
                        : 'Communities you join will appear here.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1))
          else
            Column(
              children: [
                for (int i = 0; i < communities.length; i++)
                  _buildCommunityCard(communities[i], i),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(CommunityModel community, int index) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (community.status) {
      case 'active':
        statusColor = Colors.green;
        statusLabel = 'Active';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_top;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = community.status;
        statusIcon = Icons.info;
        break;
    }

    final bool isOwner = community.isOwner;
    final bool isModerator = community.isModerator;
    final bool isClickable = community.status == 'active';
    
    // Category colors
    final categoryColors = {
      'Organization': const Color(0xFF6B5CE7),
      'Health': const Color(0xFF00C9A7),
      'Study': const Color(0xFF3B82F6),
      'Sports': const Color(0xFFEF4444),
      'Music': const Color(0xFFEC4899),
      'Other': AppColors.secondary,
    };
    final categoryColor = categoryColors[community.category] ?? AppColors.secondary;

    return GestureDetector(
      onTap: isClickable
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CommunityDetailScreen(community: community),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isOwner 
                ? AppColors.secondary.withOpacity(0.4)
                : (isClickable ? AppColors.primary.withOpacity(0.12) : Colors.grey.withOpacity(0.1)),
            width: isOwner ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Owner highlight bar
              if (isOwner)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.secondary, AppColors.secondary.withOpacity(0.8)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'You own this community',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Community avatar/icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: community.imageUrl == null
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      categoryColor.withOpacity(0.8),
                                      categoryColor,
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: categoryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: community.imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(community.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: community.imageUrl == null
                              ? Center(
                                  child: Text(
                                    community.name.isNotEmpty 
                                        ? community.name[0].toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        
                        // Community info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      community.name,
                                      style: AppTextStyles.bodyBold.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: 12, color: statusColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (community.description != null &&
                                  community.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  community.description!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Bottom row with tags and action
                    Row(
                      children: [
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isOwner 
                                ? AppColors.secondary.withOpacity(0.12)
                                : (isModerator 
                                    ? Colors.purple.withOpacity(0.1) 
                                    : AppColors.primary.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOwner 
                                    ? Icons.shield_rounded 
                                    : (isModerator ? Icons.admin_panel_settings : Icons.person),
                                size: 14,
                                color: isOwner 
                                    ? AppColors.secondary 
                                    : (isModerator ? Colors.purple : AppColors.primary),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOwner ? 'Owner' : (isModerator ? 'Moderator' : 'Member'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOwner 
                                      ? AppColors.secondary 
                                      : (isModerator ? Colors.purple : AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Category badge
                        if (community.category != null && community.category!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              community.category!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        
                        const Spacer(),
                        
                        // Open button
                        if (isClickable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Open',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ],
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
    ).animate(delay: Duration(milliseconds: 100 + (index * 80)))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _buildPendingInviteCard(CommunityModel community, int index, CommunityProvider communityProvider) {
    // Category colors
    final categoryColors = {
      'Organization': const Color(0xFF6B5CE7),
      'Health': const Color(0xFF00C9A7),
      'Study': const Color(0xFF3B82F6),
      'Sports': const Color(0xFFEF4444),
      'Music': const Color(0xFFEC4899),
      'Other': AppColors.secondary,
    };
    final categoryColor = categoryColors[community.category] ?? AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.orange.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Invite banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade300],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'You\'ve been invited to join this community',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Community avatar/icon
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: community.imageUrl == null
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    categoryColor.withOpacity(0.8),
                                    categoryColor,
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          image: community.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(community.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: community.imageUrl == null
                            ? Center(
                                child: Text(
                                  community.name.isNotEmpty ? community.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      
                      const SizedBox(width: 14),
                      
                      // Community info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community.name,
                              style: AppTextStyles.bodyBold.copyWith(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (community.description != null && community.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  community.description!,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (community.category != null && community.category!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    community.category!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: categoryColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Accept/Decline buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final success = await communityProvider.declineInvite(community.id);
                            if (mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invite declined'),
                                  backgroundColor: Colors.grey,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final success = await communityProvider.acceptInvite(community.id);
                            if (mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Welcome to ${community.name}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept Invite'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
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
    ).animate(delay: Duration(milliseconds: 50 + (index * 80)))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Future<void> _showCreateCommunityDialog(BuildContext context) async {
    final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedCategory;
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create a Community',
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Host a space for your health group, study circle, team or friends.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Community name',
                      hintText: 'e.g. Sunrise Youth Fellowship',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Category',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Organization',
                      'Health',
                      'School',
                      'Study',
                      'Friends',
                      'Other',
                    ].map((cat) {
                      final selected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: AppColors.secondary.withOpacity(0.15),
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: selected ? AppColors.secondary : AppColors.textPrimary,
                        ),
                        onSelected: (value) {
                          setState(() {
                            selectedCategory = value ? cat : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Short description',
                      hintText: 'What is this community about?',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: QuestButton(
                      text: submitting ? 'Creating...' : 'Submit for approval',
                      type: QuestButtonType.primary,
                      onPressed: submitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please enter a community name.'),
                                    backgroundColor: Colors.red[700],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                submitting = true;
                              });
                              final ok = await communityProvider.requestCommunityCreation(
                                name: name,
                                description: descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                                category: selectedCategory,
                              );
                              if (!mounted) return;
                              setState(() {
                                submitting = false;
                              });
                              if (ok) {
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Community request submitted for approval.'),
                                    backgroundColor: AppColors.secondary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              } else {
                                final msg = communityProvider.lastError ??
                                    'Could not submit community request.';
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: Colors.red[700],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Compute visible posts based on selected scope and sort options
  List<PostModel> _computeVisiblePosts(List<PostModel> posts) {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.user?.id;
    final userSchoolId = userProvider.user?.schoolId;

    List<PostModel> filtered = posts;
    if (_scope == _Scope.mine && userId != null) {
      filtered = posts.where((p) => p.userId == userId).toList();
    } else if (_scope == _Scope.school && userSchoolId != null) {
      filtered = posts.where((p) => p.schoolId == userSchoolId).toList();
    }

    switch (_sort) {
      case _Sort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _Sort.mostLiked:
        filtered.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
    }
    return filtered;
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-2, -2), blurRadius: 4),
            BoxShadow(color: Colors.black.withOpacity(0.06), offset: const Offset(2, 2), blurRadius: 4),
          ],
          border: Border.all(color: selected ? AppColors.secondary : Colors.transparent, width: 1.2),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.secondary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Header chips for scope and sort
  Widget _buildHeaderChips() {
    final userProvider = Provider.of<UserProvider>(context);
    final hasSchool = userProvider.user?.schoolId != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  label: 'All',
                  selected: _scope == _Scope.all,
                  onTap: () => setState(() => _scope = _Scope.all),
                ),
                _chip(
                  label: 'My Posts',
                  selected: _scope == _Scope.mine,
                  onTap: () => setState(() => _scope = _Scope.mine),
                ),
                if (hasSchool)
                  _chip(
                    label: 'My School',
                    selected: _scope == _Scope.school,
                    onTap: () => setState(() => _scope = _Scope.school),
                  ),
                const SizedBox(width: 12),
                _chip(
                  label: 'Newest',
                  selected: _sort == _Sort.newest,
                  onTap: () => setState(() => _sort = _Sort.newest),
                ),
                _chip(
                  label: 'Most Liked',
                  selected: _sort == _Sort.mostLiked,
                  onTap: () => setState(() => _sort = _Sort.mostLiked),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Inline empty state below the composer
  Widget _buildInlineEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: _buildEmptyState(),
    );
  }

  // New posts banner
  Widget _buildNewPostsBanner(PostProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _hasNewPostsBanner = false;
            final posts = provider.posts;
            if (posts.isNotEmpty) {
              _latestSeen = posts.map((p) => p.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
            }
          });
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fiber_new, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('New posts available — Tap to view', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  // Load more button for pagination
  Widget _buildLoadMoreButton(PostProvider provider, bool hasMore, bool isLoading) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            '🎉 You\'ve reached the end!',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Center(
        child: isLoading
            ? CircularProgressIndicator(color: AppColors.secondary)
            : ElevatedButton.icon(
                onPressed: () => provider.loadMorePosts(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load More Posts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
      ),
    );
  }

  // Confirm and handle post deletion
  Future<void> _confirmDeletePost(BuildContext context, PostModel postToDelete) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.background,
          title: const Text('Delete Victory Post?'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (confirm && mounted) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final isAdmin = userProvider.user?.isAdmin ?? false;
      
      final success = await postProvider.deletePost(postToDelete.id, isAdmin: isAdmin);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Your victory post has been deleted' 
              : 'Failed to delete post'),
          backgroundColor: success ? AppColors.secondary : Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // Note: _showCreatePostDialog is still available but the inline composer is the primary flow

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              size: 60,
              color: AppColors.primary,
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'Your Victory Wall is Empty!',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Share your achievements and celebrate your victories with friends!',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 32),
          QuestButton(
            text: 'Share Your First Victory',
            onPressed: () {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
            },
            type: QuestButtonType.secondary,
            icon: Icons.celebration,
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final TextEditingController contentController = TextEditingController();
    String? errorMessage;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final user = userProvider.user!;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.celebration, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text('Share Your Victory!', style: AppTextStyles.heading3),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What did you accomplish today?',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    hintText: 'I completed...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.secondary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  maxLines: 4,
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (contentController.text.trim().isEmpty) {
                    setState(() {
                      errorMessage = 'Please enter your victory';
                    });
                    return;
                  }
                  
                  // Create the post
                  final newPost = PostModel(
                    id: const Uuid().v4(),
                    userId: user.id,
                    userName: user.name,
                    content: contentController.text,
                    createdAt: DateTime.now(),
                  );
                  
                  // Submit post with content moderation
                  final result = await postProvider.addPost(newPost);
                  
                  if (result['success']) {
                    // Show success snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Victory shared successfully!',
                              style: AppTextStyles.body.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    
                    Navigator.of(dialogContext).pop();
                    
                    // Track victory post and trigger badge checks
                    try {
                      final badgeService = BadgeService();
                      await badgeService.trackVictoryPost();
                      final newBadges = await badgeService.checkForAchievements();
                      for (final badge in newBadges) {
                        if (!mounted) break;
                        badgeService.showBadgeEarnedDialog(context, badge);
                        try {
                          await VictoryWallService.createBadgeEarnedPost(
                            userProvider: userProvider,
                            postProvider: postProvider,
                            badge: badge,
                          );
                        } catch (_) {}
                      }
                    } catch (_) {}
                  } else {
                    // Show error message
                    setState(() {
                      errorMessage = result['message'];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration, size: 18),
                    const SizedBox(width: 8),
                    const Text('Post Victory'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBadgeEarnedDialog(BuildContext context, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Badge Earned!', style: AppTextStyles.heading2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.asset(
                    badge.imageAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                badge.name,
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                badge.defaultDescription,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            QuestButton(
              text: 'Awesome!',
              type: QuestButtonType.primary,
              isFullWidth: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncVictoryPostCountAndCheckBadges() async {
    try {
      final userProvider = context.read<UserProvider>();
      final postProvider = context.read<PostProvider>();
      final user = userProvider.user;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final existingCount = prefs.getInt('victory_posts') ?? 0;
      final actualCount = postProvider.getPostsByUserId(user.id).length;

      if (actualCount > existingCount) {
        await prefs.setInt('victory_posts', actualCount);
        // After backfill, check for achievements and surface any new badges
        final badgeService = BadgeService();
        final newBadges = await badgeService.checkForAchievements();
        for (final badge in newBadges) {
          if (!mounted) break;
          badgeService.showBadgeEarnedDialog(context, badge);
          try {
            await VictoryWallService.createBadgeEarnedPost(
              userProvider: userProvider,
              postProvider: postProvider,
              badge: badge,
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
