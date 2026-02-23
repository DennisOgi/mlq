import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/school_course_model.dart';
import '../../providers/school_course_provider.dart';
import '../../theme/app_theme.dart';
import 'school_course_viewer_screen.dart';

/// Student view for school-specific mini courses
/// Shows courses from their school with branding
class SchoolCoursesScreen extends StatefulWidget {
  const SchoolCoursesScreen({super.key});

  @override
  State<SchoolCoursesScreen> createState() => _SchoolCoursesScreenState();
}

class _SchoolCoursesScreenState extends State<SchoolCoursesScreen> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolCourseProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          return _buildNoPremiumView();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: CustomScrollView(
              slivers: [
                // School branded header
                _buildSliverAppBar(provider),

                // Search bar
                SliverToBoxAdapter(
                  child: _buildSearchBar(),
                ),

                // Categories
                if (provider.categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildCategoryFilter(provider),
                  ),

                // Continue learning section
                if (provider.inProgressCourses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildContinueLearning(provider),
                  ),

                // Featured courses
                if (provider.featuredCourses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(provider),
                  ),

                // All courses grid
                SliverToBoxAdapter(
                  child: _buildCoursesSection(provider),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
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
                'No School Linked',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask your school administrator to add you to your school to access exclusive courses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoPremiumView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('School Courses')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text(
                'Premium Feature',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'School courses are a premium feature. Contact your school administrator for access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(SchoolCourseProvider provider) {
    final primaryColor = provider.schoolPrimaryColor != null
        ? Color(int.parse(provider.schoolPrimaryColor!.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // School logo
                      if (provider.schoolLogo != null)
                        Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              provider.schoolLogo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.school,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.schoolName ?? 'Your School',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.publishedCourses.length} courses available',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
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
        title: const Text('School Courses'),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => provider.refresh(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: AppTheme.getNeumorphicDecoration(),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search courses...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(SchoolCourseProvider provider) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(
            'All',
            null,
            Icons.apps,
            AppColors.primary,
          ),
          ...provider.categories.map((category) {
            return _buildCategoryChip(
              category.name,
              category.id,
              _getCategoryIcon(category.icon),
              Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? categoryId, IconData icon, Color color) {
    final isSelected = _selectedCategoryId == categoryId;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = categoryId);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueLearning(SchoolCourseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'Continue Learning',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.inProgressCourses.length,
            itemBuilder: (context, index) {
              final progress = provider.inProgressCourses[index];
              return _buildContinueLearningCard(progress, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLearningCard(SchoolCourseProgress progress, SchoolCourseProvider provider) {
    final course = progress.course;
    if (course == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.getNeumorphicDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.play_circle_fill, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        course.topic,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.3, // TODO: Calculate actual progress
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '30%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(SchoolCourseProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Featured Courses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.featuredCourses.length,
            itemBuilder: (context, index) {
              final course = provider.featuredCourses[index];
              return _buildFeaturedCourseCard(course, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCourseCard(SchoolCourse course, SchoolCourseProvider provider) {
    final isCompleted = provider.isCourseCompleted(course.id);

    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: course.thumbnailUrl != null
              ? DecorationImage(
                  image: NetworkImage(course.thumbnailUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
          gradient: course.thumbnailUrl == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                )
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    course.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.timer, '${course.estimatedDuration} min'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.star, '${course.xpReward} XP'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSection(SchoolCourseProvider provider) {
    List<SchoolCourse> courses = provider.publishedCourses;

    // Filter by category
    if (_selectedCategoryId != null) {
      courses = provider.getCoursesByCategory(_selectedCategoryId!);
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      courses = courses.where((c) {
        return c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.topic.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategoryId != null ? 'Category Courses' : 'All Courses',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${courses.length} courses',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No courses found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              return _buildCourseCard(courses[index], provider);
            },
          ),
      ],
    );
  }

  Widget _buildCourseCard(SchoolCourse course, SchoolCourseProvider provider) {
    final isCompleted = provider.isCourseCompleted(course.id);
    final isStarted = provider.isCourseStarted(course.id);

    return GestureDetector(
      onTap: () => _openCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.getNeumorphicDecoration(),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: course.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: Image.network(
                        course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.school,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.school,
                      size: 40,
                      color: AppColors.primary,
                    ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompleted)
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.topic,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniChip(
                          '${course.estimatedDuration} min',
                          Icons.timer,
                        ),
                        const SizedBox(width: 8),
                        _buildMiniChip(
                          '${course.xpReward} XP',
                          Icons.star,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : isStarted
                                    ? Colors.orange.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCompleted
                                ? 'Review'
                                : isStarted
                                    ? 'Continue'
                                    : 'Start',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Colors.green
                                  : isStarted
                                      ? Colors.orange
                                      : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
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

  void _openCourse(SchoolCourse course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchoolCourseViewerScreen(courseId: course.id),
      ),
    );
  }
}
