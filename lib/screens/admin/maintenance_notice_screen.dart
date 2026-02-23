import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/admin_service.dart';

class MaintenanceNoticeScreen extends StatefulWidget {
  const MaintenanceNoticeScreen({super.key});

  @override
  State<MaintenanceNoticeScreen> createState() => _MaintenanceNoticeScreenState();
}

class _MaintenanceNoticeScreenState extends State<MaintenanceNoticeScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    final notices = await _adminService.getAllMaintenanceNotices();
    setState(() {
      _notices = notices;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Notices'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotices,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNoticeDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Notice'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
              ? _buildEmptyState()
              : _buildNoticesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No maintenance notices',
            style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a notice to inform all users',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        return _buildNoticeCard(notice);
      },
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice) {
    final isActive = notice['is_active'] == true;
    final priority = notice['priority'] ?? 'normal';
    final createdAt = DateTime.tryParse(notice['created_at'] ?? '');

    Color priorityColor;
    IconData priorityIcon;
    switch (priority) {
      case 'critical':
        priorityColor = Colors.red;
        priorityIcon = Icons.error;
        break;
      case 'high':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      case 'low':
        priorityColor = Colors.grey;
        priorityIcon = Icons.info_outline;
        break;
      default:
        priorityColor = AppColors.primary;
        priorityIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? priorityColor.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(priorityIcon, color: priorityColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice['title'] ?? 'Untitled',
                    style: AppTextStyles.heading3.copyWith(
                      color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice['message'] ?? '',
              style: AppTextStyles.body.copyWith(
                color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  createdAt != null
                      ? 'Created: ${_formatDate(createdAt)}'
                      : '',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (isActive)
                  TextButton.icon(
                    onPressed: () => _deactivateNotice(notice['id']),
                    icon: const Icon(Icons.visibility_off, size: 18),
                    label: const Text('Deactivate'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                IconButton(
                  onPressed: () => _deleteNotice(notice['id']),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showCreateNoticeDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedPriority = 'normal';
    DateTime? endTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.campaign, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Create Maintenance Notice'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Scheduled Maintenance',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe the maintenance or announcement...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('Low')),
                    ButtonSegment(value: 'normal', label: Text('Normal')),
                    ButtonSegment(value: 'high', label: Text('High')),
                    ButtonSegment(value: 'critical', label: Text('Critical')),
                  ],
                  selected: {selectedPriority},
                  onSelectionChanged: (value) {
                    setDialogState(() => selectedPriority = value.first);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('End Time (optional): '),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() {
                              endTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Text(
                        endTime != null ? _formatDate(endTime!) : 'Set End Time',
                      ),
                    ),
                    if (endTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setDialogState(() => endTime = null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will send a notification to ALL users immediately.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _createNotice(
                  titleController.text,
                  messageController.text,
                  selectedPriority,
                  endTime,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Notice'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNotice(
    String title,
    String message,
    String priority,
    DateTime? endTime,
  ) async {
    setState(() => _isLoading = true);

    final success = await _adminService.createMaintenanceNotice(
      title: title,
      message: message,
      priority: priority,
      endTime: endTime,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice sent to all users!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadNotices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create notice'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deactivateNotice(String noticeId) async {
    final success = await _adminService.deactivateMaintenanceNotice(noticeId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice deactivated')),
        );
        _loadNotices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to deactivate notice')),
        );
      }
    }
  }

  Future<void> _deleteNotice(String noticeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _adminService.deleteMaintenanceNotice(noticeId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice deleted')),
          );
          _loadNotices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete notice')),
          );
        }
      }
    }
  }
}
