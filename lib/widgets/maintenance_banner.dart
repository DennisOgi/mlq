import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/admin_service.dart';

/// A banner widget that displays active maintenance notices to users
class MaintenanceBanner extends StatefulWidget {
  const MaintenanceBanner({super.key});

  @override
  State<MaintenanceBanner> createState() => _MaintenanceBannerState();
}

class _MaintenanceBannerState extends State<MaintenanceBanner> {
  static const String _dismissedNoticesKey = 'dismissed_maintenance_notices';
  
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;
  Set<String> _dismissedNotices = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedNotices().then((_) => _loadNotices());
  }

  Future<void> _loadDismissedNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_dismissedNoticesKey) ?? [];
      _dismissedNotices = dismissed.toSet();
    } catch (e) {
      debugPrint('Error loading dismissed notices: $e');
    }
  }

  Future<void> _saveDismissedNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedNoticesKey, _dismissedNotices.toList());
    } catch (e) {
      debugPrint('Error saving dismissed notices: $e');
    }
  }

  Future<void> _loadNotices() async {
    try {
      final notices = await AdminService().getActiveMaintenanceNotices();
      if (mounted) {
        // Clean up dismissed notices that are no longer active
        final activeIds = notices.map((n) => n['id']?.toString()).toSet();
        _dismissedNotices.removeWhere((id) => !activeIds.contains(id));
        await _saveDismissedNotices();
        
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading maintenance notices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _dismissNotice(String noticeId) async {
    setState(() {
      _dismissedNotices.add(noticeId);
    });
    await _saveDismissedNotices();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    // Filter out dismissed notices
    final visibleNotices = _notices
        .where((n) => !_dismissedNotices.contains(n['id']?.toString()))
        .toList();

    if (visibleNotices.isEmpty) return const SizedBox.shrink();

    return Column(
      children: visibleNotices.map((notice) => _buildNoticeBanner(notice)).toList(),
    );
  }

  Widget _buildNoticeBanner(Map<String, dynamic> notice) {
    final priority = notice['priority'] ?? 'normal';
    final title = notice['title'] ?? 'Notice';
    final message = notice['message'] ?? '';
    final noticeId = notice['id']?.toString() ?? '';

    // Priority-based styling
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    IconData icon;

    switch (priority) {
      case 'critical':
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        icon = Icons.error_rounded;
        break;
      case 'high':
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        iconColor = Colors.orange.shade700;
        icon = Icons.warning_rounded;
        break;
      case 'low':
        backgroundColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        iconColor = Colors.grey.shade600;
        icon = Icons.info_outline_rounded;
        break;
      default: // normal
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        iconColor = Colors.blue.shade700;
        icon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFullNotice(context, notice),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.length > 100 
                            ? '${message.substring(0, 100)}...' 
                            : message,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to read more',
                        style: AppTextStyles.caption.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                IconButton(
                  icon: Icon(Icons.close, color: iconColor, size: 18),
                  onPressed: () => _dismissNotice(noticeId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullNotice(BuildContext context, Map<String, dynamic> notice) {
    final priority = notice['priority'] ?? 'normal';
    final title = notice['title'] ?? 'Notice';
    final message = notice['message'] ?? '';

    Color headerColor;
    switch (priority) {
      case 'critical':
        headerColor = Colors.red.shade600;
        break;
      case 'high':
        headerColor = Colors.orange.shade600;
        break;
      case 'low':
        headerColor = Colors.grey.shade600;
        break;
      default:
        headerColor = AppColors.primary;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.heading3.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Message content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: headerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
