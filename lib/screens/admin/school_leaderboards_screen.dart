import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

/// App-admin view of every school's monthly leaderboard.
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
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await AdminService.instance.getAdminSchoolsForLeaderboard();
      if (!mounted) return;
      setState(() {
        _schools = data;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List<Map<String, dynamic>>.from(_schools);
    } else {
      _filtered = _schools.where((school) {
        final name = (school['school_name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }
  }

  void _openSchool(Map<String, dynamic> school) {
    final id = (school['school_id'] ?? '').toString();
    final name = (school['school_name'] ?? 'School').toString();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SchoolLeaderboardDetailScreen(
          schoolId: id,
          schoolName: name,
        ),
      ),
    );
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Could not load school leaderboards.\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_schools.isEmpty) {
      return const Center(child: Text('No schools found.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search schools',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilter();
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: _filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No schools match your search.')),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final school = _filtered[index];
                      final name =
                          (school['school_name'] ?? 'Unknown school').toString();
                      final count =
                          (school['student_count'] as num?)?.toInt() ?? 0;
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: const Icon(Icons.school,
                                color: AppColors.primary),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            count == 1 ? '1 student' : '$count students',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openSchool(school),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SchoolLeaderboardDetailScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const _SchoolLeaderboardDetailScreen({
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<_SchoolLeaderboardDetailScreen> createState() =>
      _SchoolLeaderboardDetailScreenState();
}

class _SchoolLeaderboardDetailScreenState
    extends State<_SchoolLeaderboardDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AdminService.instance.getAdminSchoolLeaderboard(
        widget.schoolId,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(widget.schoolName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('No students in this school yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final rank = (row['rank'] as num?)?.toInt() ?? index + 1;
                          final name = (row['name'] ?? 'Anonymous').toString();
                          final xp = (row['monthly_xp'] as num?)?.toInt() ?? 0;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: rank <= 3
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                foregroundColor:
                                    rank <= 3 ? Colors.white : Colors.black87,
                                child: Text('$rank'),
                              ),
                              title: Text(name),
                              trailing: Text(
                                '$xp XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
