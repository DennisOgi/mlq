import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

class SchoolLeaderboardsScreen extends StatefulWidget {
  static const routeName = '/admin-school-leaderboards';

  const SchoolLeaderboardsScreen({super.key});

  @override
  State<SchoolLeaderboardsScreen> createState() =>
      _SchoolLeaderboardsScreenState();
}

class _SchoolLeaderboardsScreenState extends State<SchoolLeaderboardsScreen> {
  bool _isLoading = true;
  String? _error;

  // Grouped by school_id: { school_id: { 'school_name': '...', 'users': [...] } }
  Map<String, Map<String, dynamic>> _groupedData = {};
  Map<String, Map<String, dynamic>> _filteredData = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await AdminService.instance.getTopUsersPerSchool(limit: 3);
      if (!mounted) return;

      final grouped = <String, Map<String, dynamic>>{};

      for (var user in data) {
        final schoolId = (user['school_id'] ?? '').toString();
        final schoolName = (user['school_name'] ?? 'Unknown School').toString();

        if (schoolId.isEmpty) continue;

        if (!grouped.containsKey(schoolId)) {
          grouped[schoolId] = {
            'school_name': schoolName,
            'users': <Map<String, dynamic>>[],
          };
        }

        grouped[schoolId]!['users'].add(user);
      }

      setState(() {
        _groupedData = grouped;
        _isLoading = false;
        _filterSchools();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterSchools() {
    if (_searchQuery.isEmpty) {
      _filteredData = Map.from(_groupedData);
    } else {
      _filteredData = Map.fromEntries(
        _groupedData.entries.where((entry) {
          final schoolName = (entry.value['school_name'] as String).toLowerCase();
          return schoolName.contains(_searchQuery.toLowerCase());
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text('School Leaderboards'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading data:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Try Again'),
              )
            ],
          ),
        ),
      );
    }

    if (_groupedData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 16),
            Text(
              'No school leaderboards available.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: _filteredData.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: const Center(
                        child: Text(
                          'No schools match your search.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredData.length,
                    itemBuilder: (context, index) {
                      final sortedSchools = _filteredData.values.toList();
                      final schoolData = sortedSchools[index];
                      final schoolName = schoolData['school_name'] as String;
                      final users = schoolData['users'] as List<Map<String, dynamic>>;

                      return Card(
          margin: const EdgeInsets.only(bottom: 24),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // School Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        schoolName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                      // Student List
                      ...users.map((user) => _buildUserRow(user)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for a school...',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _filterSchools();
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _filterSchools();
          });
        },
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final rank = (user['rank'] ?? 0) as int;
    final name = (user['name'] ?? 'Unknown').toString();
    final monthlyXp = (user['monthly_xp'] ?? 0) as int;
    final coins = double.tryParse((user['coins'] ?? 0).toString()) ?? 0.0;
    final avatarUrl = user['avatar_url']?.toString();

    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Rank Indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3 ? medalColor.withValues(alpha: 0.2) : Colors.grey.shade100,
              border: Border.all(
                  color: rank <= 3 ? medalColor : Colors.grey.shade300,
                  width: 2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3 ? medalColor : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? (avatarUrl.startsWith('assets/')
                    ? AssetImage(avatarUrl) as ImageProvider
                    : NetworkImage(avatarUrl))
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      '$monthlyXp Monthly XP',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.monetization_on,
                        size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 4),
                    Text(
                      '${coins.toStringAsFixed(0)} Coins',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
