import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../providers/mini_course_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_course_generator_service.dart';
import '../../services/community_course_service.dart';
import '../mini_courses/community_course_detail_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunityDetailScreen({Key? key, required this.community}) : super(key: key);

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMessages = true;
  bool _isLoadingMembers = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  RealtimeChannel? _messageChannel;
  
  // Community data (mutable for image updates)
  late CommunityModel _community;
  
  // Community course state
  CommunityMiniCourse? _todayCourse;
  bool _isLoadingCourse = true;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _tabController = TabController(length: 4, vsync: this);
    _loadMessages();
    _loadMembers();
    _loadTodayCourse();
    _subscribeToMessages();
  }
  
  Future<void> _loadTodayCourse() async {
    setState(() => _isLoadingCourse = true);
    try {
      final course = await CommunityCourseService.instance
          .getTodayCourseForCommunity(_community.id);

      if (mounted && course != null) {
        final miniProvider = Provider.of<MiniCourseProvider>(context, listen: false);
        miniProvider.upsertCommunityCourse(course);
      }

      setState(() {
        _todayCourse = course;
        _isLoadingCourse = false;
      });
    } catch (e) {
      debugPrint('Error loading today\'s course: $e');
      setState(() => _isLoadingCourse = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      debugPrint('Loading messages for community ${_community.id}');
      final response = await _supabase
          .from('community_messages')
          .select('*, profiles(id, name, avatar_url)')
          .eq('community_id', _community.id)
          .order('created_at', ascending: true)
          .limit(100);
      debugPrint('Loaded ${(response as List).length} messages');
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      debugPrint('Loading members for community ${_community.id}');
      // Load both active members and pending invites
      final response = await _supabase
          .from('community_members')
          .select('*, profiles!community_members_user_id_fkey(id, name, avatar_url, xp, monthly_xp)')
          .eq('community_id', _community.id)
          .neq('status', 'removed') // Get active and pending, exclude removed
          .order('status', ascending: true) // 'active' comes before 'pending'
          .order('role', ascending: true);
      debugPrint('Loaded ${(response as List).length} members');
      setState(() {
        _members = List<Map<String, dynamic>>.from(response as List);
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  void _showDeleteCommunityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community'),
        content: Text(
          'Are you sure you want to delete "${_community.name}"? This will remove the community for all members and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final provider = Provider.of<CommunityProvider>(context, listen: false);
              final success = await provider.deleteCommunity(_community.id);

              if (!mounted) return;

              if (success) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Community deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                final message = provider.lastError ?? 'Could not delete community. Please try again.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _subscribeToMessages() {
    _messageChannel = _supabase
        .channel('community_messages_${_community.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: _community.id,
          ),
          callback: (payload) async {
            // Fetch the new message with profile info
            final newMessage = await _supabase
                .from('community_messages')
                .select('*, profiles(id, name, avatar_url)')
                .eq('id', payload.newRecord['id'])
                .single();
            if (mounted) {
              setState(() {
                _messages.add(newMessage);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    debugPrint('Attempting to send message: "$content"');
    if (content.isEmpty || _isSending) {
      debugPrint('Message empty or already sending, aborting');
      return;
    }

    setState(() => _isSending = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      debugPrint('Sending message to community ${_community.id} from user $userId');
      
      await _supabase.from('community_messages').insert({
        'community_id': _community.id,
        'user_id': userId,
        'content': content,
      });
      debugPrint('Message sent successfully!');
      _messageController.clear();
      // Reload messages after sending
      await _loadMessages();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage) return;
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image == null) return;
      
      setState(() => _isUploadingImage = true);
      
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = '${_community.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'community_images/$fileName';
      
      // Upload to Supabase Storage
      await _supabase.storage.from('organization-assets').upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      // Get public URL
      final imageUrl = _supabase.storage.from('organization-assets').getPublicUrl(filePath);
      
      // Update community record
      await _supabase
          .from('communities')
          .update({'image_url': imageUrl})
          .eq('id', _community.id);
      
      // Update local state
      setState(() {
        _community = _community.copyWith(imageUrl: imageUrl);
        _isUploadingImage = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Community image updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get category color for theming
  Color get _categoryColor {
    final categoryColors = {
      'Organization': const Color(0xFF6B5CE7),
      'Health': const Color(0xFF00C9A7),
      'Study': const Color(0xFF3B82F6),
      'Sports': const Color(0xFFEF4444),
      'Music': const Color(0xFFEC4899),
      'Other': AppColors.secondary,
    };
    return categoryColors[_community.category] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _community.createdBy == _supabase.auth.currentUser?.id;
    
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: _categoryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _community.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: isOwner
                  ? [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'upload_image') {
                            _pickAndUploadImage();
                          } else if (value == 'delete_community') {
                            _showDeleteCommunityDialog();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'upload_image',
                            child: Row(
                              children: [
                                Icon(
                                  _isUploadingImage ? Icons.hourglass_top : Icons.add_photo_alternate,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(_isUploadingImage ? 'Uploading...' : 'Upload Community Image'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_community',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Community',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _categoryColor,
                        _categoryColor.withOpacity(0.8),
                        AppColors.primary.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // Community avatar
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  image: _community.imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_community.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _community.imageUrl == null
                                    ? Center(
                                        child: Text(
                                          _community.name.isNotEmpty
                                              ? _community.name[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _community.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (_community.category != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _community.category!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.people,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_members.length} members',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isOwner) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Owner',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: _categoryColor,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: _categoryColor,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_rounded, size: 20)),
                      Tab(text: 'Course', icon: Icon(Icons.school_rounded, size: 20)),
                      Tab(text: 'Ranks', icon: Icon(Icons.leaderboard_rounded, size: 20)),
                      Tab(text: 'Members', icon: Icon(Icons.group_rounded, size: 20)),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChatTab(),
            _buildCourseTab(),
            _buildLeaderboardTab(),
            _buildMembersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseTab() {
    final isOwner = widget.community.createdBy == _supabase.auth.currentUser?.id;
    
    if (_isLoadingCourse) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Mini Course",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => _showCreateCourseDialog(),
                  icon: Icon(
                    _todayCourse == null ? Icons.add : Icons.edit,
                    size: 18,
                  ),
                  label: Text(_todayCourse == null ? 'Create' : 'Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B00),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_todayCourse == null)
            _buildNoCourseCard(isOwner)
          else
            _buildCourseCard(_todayCourse!, isOwner),
        ],
      ),
    );
  }

  Widget _buildNoCourseCard(bool isOwner) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No course for today',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Create a mini course for your community members!'
                : 'Check back later for new content from the community owner.',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (isOwner) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateCourseDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseCard(CommunityMiniCourse course, bool isOwner) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CommunityCourseDetailScreen(courseId: course.id),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.1), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.topic, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(course.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (course.isCompleted)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteCourseDialog(course);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Course', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course.summary != null) ...[
                    Text(course.summary!, style: TextStyle(color: Colors.grey[600], fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                  ],
                  // Community courses don't give XP - only show quiz badge if present
                  if (course.hasQuiz)
                    Row(
                      children: [
                        _buildCourseStatChip(Icons.quiz, 'Quiz'),
                      ],
                    ),
                  if (course.hasQuiz) const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: course.isCompleted ? null : () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CommunityCourseDetailScreen(courseId: course.id),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: course.isCompleted ? Colors.grey[300] : const Color(0xFFFF6B00),
                        foregroundColor: course.isCompleted ? Colors.grey[600] : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(course.isCompleted ? 'Completed ✓' : 'Start Course', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCourseDialog(CommunityMiniCourse course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Are you sure you want to delete "${course.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await CommunityCourseService.instance.deleteCourse(course.id);
                final miniProvider = Provider.of<MiniCourseProvider>(context, listen: false);
                miniProvider.removeCommunityCourse(course.id);
                _loadTodayCourse();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Course deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete course: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B00).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B00)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B00))),
        ],
      ),
    );
  }

  void _showCreateCourseDialog() {
    final titleController = TextEditingController(text: _todayCourse?.title ?? '');
    final topicController = TextEditingController(text: _todayCourse?.topic ?? 'Community Lesson');
    final summaryController = TextEditingController(text: _todayCourse?.summary ?? '');
    final contentController = TextEditingController(
      text: _todayCourse?.content.map((c) => c['content'] as String? ?? '').join('\n\n') ?? '',
    );
    final aiPromptController = TextEditingController();
    bool isGenerating = false;
    bool showAiSection = true;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                _todayCourse == null ? Icons.add_circle : Icons.edit,
                color: _categoryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _todayCourse == null ? 'Create Mini Course' : 'Edit Mini Course',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Generation Section
                if (showAiSection) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade50,
                          Colors.blue.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                color: Colors.purple.shade700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI Course Generator',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setDialogState(() => showAiSection = false),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Describe the course you want to create and let AI generate it for you!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: aiPromptController,
                          decoration: InputDecoration(
                            hintText: 'e.g., A lesson about teamwork and collaboration for students...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isGenerating
                                ? null
                                : () async {
                                    if (aiPromptController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please describe the course you want to generate'),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    setDialogState(() => isGenerating = true);
                                    
                                    try {
                                      final result = await AiCourseGeneratorService.instance
                                          .generateCommunityMiniCourse(
                                        description: aiPromptController.text.trim(),
                                        communityName: _community.name,
                                        category: _community.category,
                                      );
                                      
                                      if (result != null) {
                                        setDialogState(() {
                                          titleController.text = result['title'] as String;
                                          topicController.text = result['topic'] as String;
                                          summaryController.text = result['summary'] as String? ?? '';
                                          
                                          // Convert content list to text
                                          final contentList = result['content'] as List<dynamic>;
                                          contentController.text = contentList
                                              .map((c) => c['content'] as String? ?? '')
                                              .join('\n\n');
                                          
                                          showAiSection = false;
                                          isGenerating = false;
                                        });
                                        
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text('Course generated! Review and save.'),
                                                ],
                                              ),
                                              backgroundColor: Colors.green.shade600,
                                            ),
                                          );
                                        }
                                      } else {
                                        setDialogState(() => isGenerating = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Failed to generate course. Please try again or write manually.'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      setDialogState(() => isGenerating = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              isGenerating ? 'Generating...' : 'Generate with AI',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR WRITE MANUALLY',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Show button to bring back AI section
                  GestureDetector(
                    onTap: () => setDialogState(() => showAiSection = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: Colors.purple.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Use AI to generate',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Manual input fields
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g., Building Confidence',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicController,
                  decoration: InputDecoration(
                    labelText: 'Topic',
                    hintText: 'e.g., Leadership Skills',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: InputDecoration(
                    labelText: 'Summary (optional)',
                    hintText: 'Brief description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'Content *',
                    hintText: 'Write your lesson content here.\n\nSeparate paragraphs with blank lines.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and content are required')),
                  );
                  return;
                }
                
                try {
                  final contentParagraphs = contentController.text.trim().split(RegExp(r'\n\n+'));
                  final content = contentParagraphs.map((p) => {'type': 'text', 'content': p.trim()}).toList();

                  final savedCourse = await CommunityCourseService.instance.upsertTodayCourse(
                    communityId: _community.id,
                    title: titleController.text.trim(),
                    topic: topicController.text.trim().isNotEmpty ? topicController.text.trim() : 'Community Lesson',
                    summary: summaryController.text.trim().isNotEmpty ? summaryController.text.trim() : null,
                    content: content,
                  );

                  if (mounted) {
                    if (savedCourse != null) {
                      final miniProvider = Provider.of<MiniCourseProvider>(context, listen: false);
                      miniProvider.upsertCommunityCourse(savedCourse);
                    }

                    Navigator.pop(context);
                    _loadTodayCourse();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Course saved successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save course: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _categoryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Course', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    if (_isLoadingMessages) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _categoryColor),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _categoryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.forum_rounded,
                          size: 56,
                          color: _categoryColor.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Start the conversation!',
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Be the first to share something with your community.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final profile = message['profiles'] as Map<String, dynamic>?;
                    final isMe = message['user_id'] == _supabase.auth.currentUser?.id;
                    
                    // Check if we should show date separator
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMessage = _messages[index - 1];
                      final prevDate = DateTime.tryParse(prevMessage['created_at'] ?? '');
                      final currDate = DateTime.tryParse(message['created_at'] ?? '');
                      if (prevDate != null && currDate != null) {
                        showDateSeparator = prevDate.day != currDate.day ||
                            prevDate.month != currDate.month ||
                            prevDate.year != currDate.year;
                      }
                    }
                    
                    return Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now()),
                        _buildMessageBubble(message, profile, isMe),
                      ],
                    );
                  },
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }
  
  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, Map<String, dynamic>? profile, bool isMe) {
    final name = profile?['name'] as String? ?? 'Unknown';
    final avatarUrl = profile?['avatar_url'] as String?;
    final content = message['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(message['created_at'] ?? '') ?? DateTime.now();
    final timeStr = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _categoryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _categoryColor.withOpacity(0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null 
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: _categoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_categoryColor, _categoryColor.withOpacity(0.85)],
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isMe ? _categoryColor : Colors.black).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _categoryColor,
                        ),
                      ),
                    ),
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_categoryColor, _categoryColor.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _categoryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_isLoadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    // Sort members by monthly_xp for leaderboard
    final sortedMembers = List<Map<String, dynamic>>.from(_members);
    sortedMembers.sort((a, b) {
      final aXp = (a['profiles']?['monthly_xp'] as num?)?.toInt() ?? 0;
      final bXp = (b['profiles']?['monthly_xp'] as num?)?.toInt() ?? 0;
      return bXp.compareTo(aXp);
    });

    final totalMembers = sortedMembers.length;

    if (sortedMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No members yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final profile = member['profiles'] as Map<String, dynamic>?;
        final name = profile?['name'] as String? ?? 'Unknown';
        final avatarUrl = profile?['avatar_url'] as String?;
        final monthlyXp = (profile?['monthly_xp'] as num?)?.toInt() ?? 0;
        final rank = index + 1;
        final role = member['role'] as String? ?? 'member';
        final isOwner = role == 'owner' || member['user_id'] == widget.community.createdBy;
        final followerCount = totalMembers > 0 ? (totalMembers - 1) : 0;

        Color? medalColor;
        if (rank == 1) medalColor = Colors.amber;
        if (rank == 2) medalColor = Colors.grey.shade400;
        if (rank == 3) medalColor = Colors.brown.shade300;
        Color cardBorderColor;
        Color cardBackground;
        if (rank == 1) {
          cardBorderColor = AppColors.secondary.withOpacity(0.7);
          cardBackground = AppColors.secondary.withOpacity(0.10);
        } else if (rank <= 3) {
          cardBorderColor = AppColors.primary.withOpacity(0.4);
          cardBackground = AppColors.primary.withOpacity(0.04);
        } else {
          cardBorderColor = AppColors.primary.withOpacity(0.05);
          cardBackground = AppColors.surface;
        }

        return Container
        (
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: cardBorderColor,
              width: rank == 1 ? 1.6 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: medalColor != null
                      ? Icon(Icons.emoji_events, color: medalColor)
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(name[0].toUpperCase(), style: TextStyle(color: AppColors.primary))
                      : null,
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Owner',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                isOwner
                    ? (followerCount == 1
                        ? 'Owner · 1 follower'
                        : 'Owner · $followerCount followers')
                    : _getRoleLabel(role),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$monthlyXp XP',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (rank <= 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      rank == 1
                          ? 'Top of the community'
                          : 'Top $rank',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab() {
    final userProvider = Provider.of<UserProvider>(context);
    final isOwner = widget.community.isOwner;

    return Column(
      children: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        Expanded(
          child: _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No members yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Add members to grow your community!',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMembers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final profile = member['profiles'] as Map<String, dynamic>?;
                          final name = profile?['name'] as String? ?? 'Unknown';
                          final avatarUrl = profile?['avatar_url'] as String?;
                          final role = member['role'] as String? ?? 'member';
                          final memberStatus = member['status'] as String? ?? 'active';
                          final userId = member['user_id'] as String?;
                          final isCurrentUser = userId == userProvider.user?.id;
                          final isPending = memberStatus == 'pending';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: isPending ? Colors.orange.shade50 : null,
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isPending 
                                        ? Colors.orange.withOpacity(0.2) 
                                        : AppColors.primary.withOpacity(0.2),
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null
                                        ? Text(name[0].toUpperCase(), 
                                            style: TextStyle(color: isPending ? Colors.orange : AppColors.primary))
                                        : null,
                                  ),
                                  if (isPending)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.schedule, color: Colors.white, size: 10),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(name, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isPending ? Colors.orange.shade800 : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'You',
                                        style: TextStyle(fontSize: 10, color: AppColors.secondary),
                                      ),
                                    ),
                                  if (isPending)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Pending',
                                        style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                isPending ? 'Invite sent - awaiting response' : _getRoleLabel(role),
                                style: TextStyle(
                                  color: isPending ? Colors.orange.shade600 : null,
                                  fontStyle: isPending ? FontStyle.italic : null,
                                ),
                              ),
                              trailing: isOwner && !isCurrentUser && role != 'owner'
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'remove' || value == 'cancel_invite') {
                                          _removeMember(userId!);
                                        } else if (value == 'promote') {
                                          _promoteMember(userId!);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (!isPending)
                                          const PopupMenuItem(
                                            value: 'promote',
                                            child: Row(
                                              children: [
                                                Icon(Icons.arrow_upward, color: Colors.green),
                                                SizedBox(width: 8),
                                                Text('Make Moderator'),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: isPending ? 'cancel_invite' : 'remove',
                                          child: Row(
                                            children: [
                                              Icon(isPending ? Icons.cancel : Icons.remove_circle, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text(isPending ? 'Cancel Invite' : 'Remove'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : isPending 
                                      ? Icon(Icons.hourglass_top, color: Colors.orange.shade400, size: 20)
                                      : _getRoleIcon(role),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Member';
    }
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icon(Icons.star, color: Colors.amber);
      case 'moderator':
        return Icon(Icons.shield, color: AppColors.secondary);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showAddMemberDialog() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> searchUsers(String query) async {
              if (query.length < 2) {
                setState(() => searchResults = []);
                return;
              }
              setState(() => isSearching = true);
              try {
                final response = await _supabase
                    .from('profiles')
                    .select('id, name, avatar_url')
                    .ilike('name', '%$query%')
                    .limit(10);
                
                // Filter out existing members
                final existingIds = _members.map((m) => m['user_id']).toSet();
                final filtered = (response as List)
                    .where((u) => !existingIds.contains(u['id']))
                    .toList();
                
                setState(() {
                  searchResults = List<Map<String, dynamic>>.from(filtered);
                  isSearching = false;
                });
              } catch (e) {
                debugPrint('Error searching users: $e');
                setState(() => isSearching = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Member',
                        style: AppTextStyles.heading3.copyWith(color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => searchUsers(value),
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (searchResults.isEmpty && searchController.text.length >= 2)
                    Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          final name = user['name'] as String? ?? 'Unknown';
                          final avatarUrl = user['avatar_url'] as String?;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.2),
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(name[0].toUpperCase(), style: TextStyle(color: AppColors.primary))
                                  : null,
                            ),
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () async {
                                await _addMember(user['id'] as String);
                                Navigator.pop(sheetContext);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addMember(String userId) async {
    debugPrint('Inviting member $userId to community ${_community.id}');
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      await _supabase.from('community_members').insert({
        'community_id': _community.id,
        'user_id': userId,
        'role': 'member',
        'status': 'pending', // User must accept the invite
        'invited_by': currentUserId,
      });
      debugPrint('Invite sent successfully!');
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite sent! The user must accept to join.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error inviting member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', _community.id)
          .eq('user_id', userId);
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing member: $e');
    }
  }

  Future<void> _promoteMember(String userId) async {
    try {
      await _supabase
          .from('community_members')
          .update({'role': 'moderator'})
          .eq('community_id', _community.id)
          .eq('user_id', userId);
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member promoted to moderator!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error promoting member: $e');
    }
  }
}
