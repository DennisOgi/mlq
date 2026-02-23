import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../models/school_course_model.dart';
import '../../providers/school_course_provider.dart';
import '../../theme/app_theme.dart';
import 'school_course_form_screen.dart';

/// School Admin Dashboard for managing school-specific mini courses
/// This is a PREMIUM feature for schools
class SchoolCoursesAdminScreen extends StatefulWidget {
  const SchoolCoursesAdminScreen({super.key});

  @override
  State<SchoolCoursesAdminScreen> createState() => _SchoolCoursesAdminScreenState();
}

class _SchoolCoursesAdminScreenState extends State<SchoolCoursesAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolCourseProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SchoolCourseProvider>(
      builder: (context, provider, child) {
        if (!provider.hasSchool) {
          return _buildNoSchoolView();
        }

        if (!provider.hasPremium) {
          return _buildPremiumRequiredView(provider);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('School Courses'),
                Text(
                  provider.schoolName ?? 'Your School',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSchoolSettingsDialog(provider),
                tooltip: 'School Settings',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : () => provider.refresh(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.dashboard),
                  text: 'Overview',
                ),
                Tab(
                  icon: Badge(
                    label: Text('${provider.pendingCourses.length}'),
                    isLabelVisible: provider.pendingCourses.isNotEmpty,
                    child: const Icon(Icons.pending_actions),
                  ),
                  text: 'Pending',
                ),
                Tab(
                  icon: const Icon(Icons.library_books),
                  text: 'All Courses',
                ),
                Tab(
                  icon: const Icon(Icons.category),
                  text: 'Categories',
                ),
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(provider),
                    _buildPendingTab(provider),
                    _buildAllCoursesTab(provider),
                    _buildCategoriesTab(provider),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToCourseForm(null),
            icon: const Icon(Icons.add),
            label: const Text('Create Course'),
            backgroundColor: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildNoSchoolView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('School Courses')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text(
                'No School Associated',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You need to be associated with a school to manage school courses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumRequiredView(SchoolCourseProvider provider) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('School Courses')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.workspace_premium, size: 60, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Premium Feature',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'School Mini Courses is a premium feature.\nUpgrade your school subscription to unlock custom course creation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to subscription/upgrade page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact support to upgrade your school subscription')),
                  );
                },
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // OVERVIEW TAB
  // =====================================================

  Widget _buildOverviewTab(SchoolCourseProvider provider) {
    final analytics = provider.analytics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // School branding card
          _buildSchoolBrandingCard(provider),
          const SizedBox(height: 24),

          // Stats grid
          _buildStatsGrid(analytics),
          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(provider),
          const SizedBox(height: 24),

          // Recent courses
          _buildRecentCourses(provider),
        ],
      ),
    );
  }

  Widget _buildSchoolBrandingCard(SchoolCourseProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Row(
        children: [
          // School logo
          GestureDetector(
            onTap: () => _uploadSchoolLogo(provider),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: provider.schoolLogo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        provider.schoolLogo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                      ),
                    )
                  : _buildLogoPlaceholder(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.schoolName ?? 'Your School',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap logo to upload school branding',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, color: Colors.grey[400]),
        Text('Logo', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> analytics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Courses',
          '${analytics['total_courses'] ?? 0}',
          Icons.library_books,
          AppColors.primary,
        ),
        _buildStatCard(
          'Published',
          '${analytics['published_courses'] ?? 0}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Views',
          '${analytics['total_views'] ?? 0}',
          Icons.visibility,
          Colors.blue,
        ),
        _buildStatCard(
          'Completions',
          '${analytics['total_completions'] ?? 0}',
          Icons.emoji_events,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(SchoolCourseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Create Course',
                Icons.add_circle,
                AppColors.primary,
                () => _navigateToCourseForm(null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Add Category',
                Icons.category,
                Colors.purple,
                () => _showAddCategoryDialog(provider),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.getNeumorphicDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCourses(SchoolCourseProvider provider) {
    final recentCourses = provider.allCourses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Courses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentCourses.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AppTheme.getNeumorphicDecoration(),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.library_books_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No courses yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _navigateToCourseForm(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first course'),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentCourses.map((course) => _buildCourseListItem(course, provider)),
      ],
    );
  }

  // =====================================================
  // PENDING TAB
  // =====================================================

  Widget _buildPendingTab(SchoolCourseProvider provider) {
    final pendingCourses = provider.pendingCourses;

    if (pendingCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            const Text(
              'No Pending Approvals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All courses have been reviewed',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingCourses.length,
      itemBuilder: (context, index) {
        final course = pendingCourses[index];
        return _buildPendingCourseCard(course, provider);
      },
    );
  }

  Widget _buildPendingCourseCard(SchoolCourse course, SchoolCourseProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${course.creator?.name ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCourseChip(course.topic, Icons.topic),
              const SizedBox(width: 8),
              _buildCourseChip('${course.xpReward} XP', Icons.star),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(course, provider),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveCourse(course, provider),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ALL COURSES TAB
  // =====================================================

  Widget _buildAllCoursesTab(SchoolCourseProvider provider) {
    final courses = provider.allCourses;

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Courses Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first school course',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCourseForm(null),
              icon: const Icon(Icons.add),
              label: const Text('Create Course'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return _buildCourseListItem(courses[index], provider);
      },
    );
  }

  Widget _buildCourseListItem(SchoolCourse course, SchoolCourseProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getStatusColor(course.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getStatusIcon(course.status),
            color: _getStatusColor(course.status),
          ),
        ),
        title: Text(
          course.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(course.topic),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildMiniChip(course.statusDisplay, _getStatusColor(course.status)),
                const SizedBox(width: 8),
                Text(
                  '${course.viewCount} views • ${course.completionCount} completions',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleCourseAction(value, course, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'view', child: Text('View Progress')),
            if (course.status == SchoolCourseStatus.draft)
              const PopupMenuItem(value: 'publish', child: Text('Publish')),
            if (course.status == SchoolCourseStatus.published)
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // CATEGORIES TAB
  // =====================================================

  Widget _buildCategoriesTab(SchoolCourseProvider provider) {
    final categories = provider.categories;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${categories.length} Categories',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No categories yet'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddCategoryDialog(provider),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Category'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) {
                    // Handle reorder
                  },
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryItem(category, provider, key: ValueKey(category.id));
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(SchoolCourseCategory category, SchoolCourseProvider provider, {Key? key}) {
    final courseCount = provider.getCoursesByCategory(category.id).length;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(category.icon),
            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
          ),
        ),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$courseCount courses'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditCategoryDialog(category, provider),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteCategory(category, provider),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  Widget _buildCourseChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getStatusColor(SchoolCourseStatus status) {
    switch (status) {
      case SchoolCourseStatus.draft:
        return Colors.grey;
      case SchoolCourseStatus.pendingApproval:
        return Colors.orange;
      case SchoolCourseStatus.published:
        return Colors.green;
      case SchoolCourseStatus.archived:
        return Colors.blue;
      case SchoolCourseStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SchoolCourseStatus status) {
    switch (status) {
      case SchoolCourseStatus.draft:
        return Icons.edit_note;
      case SchoolCourseStatus.pendingApproval:
        return Icons.pending;
      case SchoolCourseStatus.published:
        return Icons.check_circle;
      case SchoolCourseStatus.archived:
        return Icons.archive;
      case SchoolCourseStatus.rejected:
        return Icons.cancel;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'language':
        return Icons.translate;
      case 'history':
        return Icons.history_edu;
      case 'art':
        return Icons.palette;
      case 'music':
        return Icons.music_note;
      case 'sports':
        return Icons.sports;
      case 'technology':
        return Icons.computer;
      default:
        return Icons.book;
    }
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  void _navigateToCourseForm(SchoolCourse? course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchoolCourseFormScreen(course: course),
      ),
    ).then((_) {
      context.read<SchoolCourseProvider>().refresh();
    });
  }

  Future<void> _uploadSchoolLogo(SchoolCourseProvider provider) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final url = await provider.uploadSchoolLogo(bytes, image.name);

        if (url != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School logo updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e')),
        );
      }
    }
  }

  void _showSchoolSettingsDialog(SchoolCourseProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('School Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Upload Logo'),
              onTap: () {
                Navigator.pop(context);
                _uploadSchoolLogo(provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Brand Colors'),
              onTap: () {
                Navigator.pop(context);
                _showBrandColorsDialog(provider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBrandColorsDialog(SchoolCourseProvider provider) {
    final colors = ['#FFD60A', '#00C4FF', '#A1E44D', '#FF70A6', '#FF9505', '#9B59B6'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Primary Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () async {
                await provider.updateSchoolBranding(primaryColor: color);
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                  border: provider.schoolPrimaryColor == color
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(SchoolCourseProvider provider) {
    final nameController = TextEditingController();
    String selectedIcon = 'book';
    String selectedColor = '#00C4FF';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Mathematics',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['book', 'math', 'science', 'language', 'history', 'art'].map((icon) {
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedIcon == icon ? AppColors.primary.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                        border: selectedIcon == icon
                            ? Border.all(color: AppColors.primary)
                            : null,
                      ),
                      child: Icon(_getCategoryIcon(icon)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await provider.createCategory(
                    name: nameController.text,
                    icon: selectedIcon,
                    color: selectedColor,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(SchoolCourseCategory category, SchoolCourseProvider provider) {
    final nameController = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await provider.updateCategory(
                  categoryId: category.id,
                  name: nameController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(SchoolCourseCategory category, SchoolCourseProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteCategory(category.id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveCourse(SchoolCourse course, SchoolCourseProvider provider) async {
    final success = await provider.approveCourse(course.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Course approved!' : 'Failed to approve course'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog(SchoolCourse course, SchoolCourseProvider provider) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rejecting: ${course.title}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Provide feedback for the teacher...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                await provider.rejectCourse(course.id, reasonController.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Course rejected')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _handleCourseAction(String action, SchoolCourse course, SchoolCourseProvider provider) async {
    switch (action) {
      case 'edit':
        _navigateToCourseForm(course);
        break;
      case 'view':
        _showCourseProgressDialog(course, provider);
        break;
      case 'publish':
        await provider.publishCourse(course.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course published!')),
          );
        }
        break;
      case 'archive':
        await provider.archiveCourse(course.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course archived')),
          );
        }
        break;
      case 'delete':
        _confirmDeleteCourse(course, provider);
        break;
    }
  }

  void _showCourseProgressDialog(SchoolCourse course, SchoolCourseProvider provider) async {
    final progressData = await provider.getCourseProgressData(course.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${course.title} - Progress'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: progressData.isEmpty
              ? const Center(child: Text('No students have started this course yet'))
              : ListView.builder(
                  itemCount: progressData.length,
                  itemBuilder: (context, index) {
                    final progress = progressData[index];
                    final student = progress['student'] as Map<String, dynamic>?;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (student?['name'] as String? ?? 'S')[0].toUpperCase(),
                        ),
                      ),
                      title: Text(student?['name'] ?? 'Student'),
                      subtitle: Text(
                        progress['completed_at'] != null
                            ? 'Completed - Score: ${progress['quiz_score'] ?? 0}%'
                            : 'In Progress',
                      ),
                      trailing: progress['completed_at'] != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.hourglass_empty, color: Colors.orange),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCourse(SchoolCourse course, SchoolCourseProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to delete "${course.title}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteCourse(course.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
