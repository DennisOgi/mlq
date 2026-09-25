import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/post_provider.dart';
import '../../services/admin_service.dart';

class VictoryWallAdminScreen extends StatefulWidget {
  const VictoryWallAdminScreen({super.key});

  @override
  State<VictoryWallAdminScreen> createState() => _VictoryWallAdminScreenState();
}

class _VictoryWallAdminScreenState extends State<VictoryWallAdminScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _adminService.getAdminVictoryPosts();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Victory Wall Admin'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Announcements'),
            Tab(text: 'Polls'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPosts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAnnouncementDialog();
          } else {
            _showPollDialog();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'New Announcement' : 'New Poll'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPostList('admin_announcement'),
                _buildPostList('poll'),
              ],
            ),
    );
  }

  Widget _buildPostList(String postType) {
    final filtered =
        _posts.where((p) => p['post_type'] == postType).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              postType == 'poll' ? Icons.poll_outlined : Icons.campaign_outlined,
              size: 72,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              postType == 'poll' ? 'No polls yet' : 'No announcements yet',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create one for the community',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final post = filtered[index];
        final isPoll = post['post_type'] == 'poll';
        final expiresAt = post['expires_at'] != null
            ? DateTime.tryParse(post['expires_at'] as String)
            : null;
        final isExpired =
            expiresAt != null && expiresAt.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPoll
                  ? AppColors.secondary.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              child: Icon(
                isPoll ? Icons.poll : Icons.campaign,
                color: isPoll ? AppColors.secondary : AppColors.primary,
              ),
            ),
            title: Text(
              isPoll
                  ? (post['content'] as String? ?? 'Poll')
                  : (post['title'] as String? ?? 'Announcement'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (!isPoll && post['content'] != null)
                  (post['content'] as String),
                if (post['is_pinned'] == true) '📌 Pinned',
                if (isExpired) '⏱ Ended',
                if (expiresAt != null && !isExpired)
                  'Ends ${expiresAt.toLocal().toString().substring(0, 16)}',
              ].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: isPoll ? 'Delete poll' : 'Delete announcement',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeletePost(post),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePost(Map<String, dynamic> post) async {
    final isPoll = post['post_type'] == 'poll';
    final label = isPoll ? 'poll' : 'announcement';
    final title = isPoll
        ? (post['content'] as String? ?? 'this poll')
        : (post['title'] as String? ?? 'this announcement');

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete $label?'),
            content: Text(
              'Are you sure you want to delete "$title"? '
              'This cannot be undone${isPoll ? ' and all votes will be removed' : ''}.',
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
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) return;

    // RPC delete + remove from live Victory Wall feed if loaded.
    final success =
        await context.read<PostProvider>().deletePost(postId, isAdmin: true);
    if (!mounted) return;

    if (success) {
      await _loadPosts();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '${isPoll ? 'Poll' : 'Announcement'} deleted'
            : 'Failed to delete $label'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showAnnouncementDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String priority = 'normal';
    bool isPinned = true;
    bool notifyAll = true;
    DateTime? expiresAt;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Important Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. New feature launch!',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'What should the community know?',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setDialogState(() => priority = v ?? 'normal'),
                ),
                SwitchListTile(
                  title: const Text('Pin to top of Victory Wall'),
                  value: isPinned,
                  onChanged: (v) => setDialogState(() => isPinned = v),
                ),
                SwitchListTile(
                  title: const Text('Notify all users'),
                  value: notifyAll,
                  onChanged: (v) => setDialogState(() => notifyAll = v),
                ),
                ListTile(
                  title: Text(expiresAt == null
                      ? 'No expiry'
                      : 'Expires: ${expiresAt!.toLocal().toString().substring(0, 16)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 23, minute: 59),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      expiresAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    final postId = await _adminService.createAdminAnnouncement(
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      priority: priority,
      isPinned: isPinned,
      expiresAt: expiresAt,
      notifyAll: notifyAll,
    );

    if (!mounted) return;

    if (postId != null) {
      await context.read<PostProvider>().refreshAfterAdminPost();
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted to Victory Wall')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post announcement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showPollDialog() async {
    final questionController = TextEditingController();
    final optionControllers = List.generate(3, (_) => TextEditingController());
    bool isPinned = true;
    bool notifyAll = true;
    DateTime? expiresAt;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Community Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'What should the community vote on?',
                  ),
                ),
                const SizedBox(height: 12),
                ...optionControllers.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: 'Option ${entry.key + 1}',
                      ),
                    ),
                  );
                }),
                if (optionControllers.length < 6)
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        optionControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
                SwitchListTile(
                  title: const Text('Pin to top of Victory Wall'),
                  value: isPinned,
                  onChanged: (v) => setDialogState(() => isPinned = v),
                ),
                SwitchListTile(
                  title: const Text('Notify all users'),
                  value: notifyAll,
                  onChanged: (v) => setDialogState(() => notifyAll = v),
                ),
                ListTile(
                  title: Text(expiresAt == null
                      ? 'No expiry'
                      : 'Ends: ${expiresAt!.toLocal().toString().substring(0, 16)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date == null) return;
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 23, minute: 59),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      expiresAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create Poll'),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    final postId = await _adminService.createAdminPoll(
      question: questionController.text.trim(),
      options: optionControllers.map((c) => c.text).toList(),
      isPinned: isPinned,
      expiresAt: expiresAt,
      notifyAll: notifyAll,
    );

    if (!mounted) return;

    if (postId != null) {
      await context.read<PostProvider>().refreshAfterAdminPost();
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll posted to Victory Wall')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create poll (need 2+ options)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
