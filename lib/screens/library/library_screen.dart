import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants/app_constants.dart';
import '../../models/library_video_model.dart';
import '../../models/school_library_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/school_library_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/library_thumbnail.dart';
import '../../models/yt_library_models.dart';
import '../../widgets/library_watch_limit_dialog.dart';
import '../../widgets/feature_lock_card.dart';
import '../../widgets/mlq_ui_primitives.dart';
import '../../utils/entitlements.dart';
import 'library_playlist_screen.dart';
import 'library_video_player_screen.dart';
import 'school_library_viewer_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  /// 0 = Explore (global catalog), 1 = School library
  int _segment = 0;
  String? _schoolLoadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLibrary());
  }

  void _initLibrary() {
    if (!mounted) return;
    final lib = context.read<LibraryProvider>();
    final uid = context.read<UserProvider>().user?.id;
    lib.loadIfStale(userId: uid);
    _maybeLoadSchool();
  }

  void _maybeLoadSchool() {
    final schoolId = context.read<UserProvider>().user?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return;
    if (_schoolLoadedFor == schoolId) return;
    _schoolLoadedFor = schoolId;
    context.read<SchoolLibraryProvider>().loadForSchool(
          schoolId: schoolId,
          publishedOnly: true,
        );
  }

  Future<void> _refreshLibrary() async {
    final uid = context.read<UserProvider>().user?.id;
    if (_segment == 1) {
      await context
          .read<SchoolLibraryProvider>()
          .refresh(publishedOnly: true);
    } else {
      await context.read<LibraryProvider>().refresh(userId: uid);
    }
  }

  void _openSchoolItem(SchoolLibraryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchoolLibraryViewerScreen(item: item),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openVideo(LibraryVideo video, {String? ytVideoId}) async {
    final uid = context.read<UserProvider>().user?.id;
    final lib = context.read<LibraryProvider>();
    final watchId = ytVideoId ?? video.youtubeId;

    if (uid != null) {
      final status = await lib.tryStartWatch(uid, watchId);
      if (!status.allowed && mounted) {
        await showLibraryWatchLimitDialog(context, status);
        return;
      }
    }

    if (!mounted) return;
    lib.trackView(video.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryVideoPlayerScreen(
          video: video,
          userId: uid,
          ytVideoId: ytVideoId,
          watchAlreadyRecorded: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (!Entitlements.hasPaidAccess(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digital Library')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: FeatureLockCard(
            title: 'Digital Library',
            description:
                'Watch leadership videos with Monthly or Quarterly.',
            icon: Icons.video_library_rounded,
          ),
        ),
      );
    }

    final hasSchool =
        user?.schoolId != null && user!.schoolId!.isNotEmpty;
    if (hasSchool && _schoolLoadedFor != user.schoolId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoadSchool();
      });
    }

    final lib = context.watch<LibraryProvider>();
    final isSearching = lib.searchActive && _segment == 0;
    final showSchool = hasSchool && _segment == 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshLibrary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(lib, isSearching),
            if (hasSchool && !isSearching)
              SliverToBoxAdapter(child: _buildSegmentBar()),
            if (showSchool)
              ..._schoolSlivers()
            else if (lib.status == LibraryStatus.loading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (lib.status == LibraryStatus.error)
              SliverFillRemaining(child: _ErrorState(onRetry: _refreshLibrary))
            else ...[
              if (isSearching)
                _SearchResults(lib: lib, onOpen: _openVideo)
              else if (lib.usesYoutubeCatalog)
                _YoutubeHomeContent(lib: lib)
              else if (lib.activeTopic != 'All')
                _SearchOrFilterResults(lib: lib, onOpen: _openVideo)
              else
                _LegacyHomeContent(lib: lib, onOpen: _openVideo),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: MlqSegmentTabs(
        labels: const ['Explore', 'My School'],
        selected: _segment,
        onChanged: (index) {
          if (_segment == index) return;
          setState(() => _segment = index);
          if (index == 1) _maybeLoadSchool();
        },
      ),
    );
  }

  List<Widget> _schoolSlivers() {
    final schoolLib = context.watch<SchoolLibraryProvider>();
    if (schoolLib.loading && schoolLib.items.isEmpty) {
      return const [
        SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }
    if (schoolLib.error != null && schoolLib.items.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    schoolLib.error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _refreshLibrary,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final items = schoolLib.publishedItems;
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Your school has not published any library resources yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final schoolName =
        context.read<UserProvider>().user?.schoolName?.trim();
    final groups = _groupSchoolLessons(items);
    final name = (schoolName == null || schoolName.isEmpty)
        ? 'Your school'
        : schoolName;
    return [
      SliverToBoxAdapter(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: _SchoolCatalog(
              name: name,
              lessonCount: items.length,
              classCount: groups.length,
              groups: groups,
              onOpen: _openSchoolItem,
            ),
          ),
        ),
      ),
    ];
  }

  SliverAppBar _buildAppBar(LibraryProvider lib, bool isSearching) {
    return SliverAppBar(
      backgroundColor: AppColors.plum,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context)),
      pinned: true,
      floating: true,
      snap: true,
      expandedHeight: isSearching ? kToolbarHeight + 16 : 56,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: isSearching
            ? Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Colors.white,
                    selectionColor: Color(0x55FFFFFF),
                    selectionHandleColor: Colors.white,
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  autofocus: true,
                  keyboardAppearance: Brightness.dark,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search videos, topics, channels…',
                    hintStyle: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.7), size: 20),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  onChanged: (v) => lib.setSearch(v),
                ),
              )
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      'Library',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_segment == 0 && lib.totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${lib.totalCount} videos',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_segment == 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: AppColors.secondary.withOpacity(0.6), width: 1),
                    ),
                    child: Text(
                      'BETA',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ],
                ],
              ),
      ),
      actions: [
        if (!isSearching && _segment == 0)
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {
              lib.setSearchActive(true);
              _searchCtrl.clear();
            },
          ),
        if (isSearching)
          TextButton(
            onPressed: () {
              lib.setSearchActive(false);
              _searchCtrl.clear();
              _searchFocus.unfocus();
            },
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
        if (!isSearching && _segment == 0 && lib.ytBookmarked.isNotEmpty)
          IconButton(
            tooltip: 'Watch Later',
            icon: const Icon(Icons.bookmark_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      _BookmarksScreen(onOpen: _openVideo)),
            ),
          ),
      ],
    );
  }
}

class _SchoolGroup {
  final String label;
  final List<SchoolLibraryItem> items;
  const _SchoolGroup(this.label, this.items);
}

List<_SchoolGroup> _groupSchoolLessons(List<SchoolLibraryItem> items) {
  const order = ['JSS1', 'JSS2', 'SS1', 'SS2', 'More'];
  final buckets = {for (final key in order) key: <SchoolLibraryItem>[]};
  for (final item in items) {
    buckets[_schoolClassKey(item.title)]!.add(item);
  }
  return [
    for (final key in order)
      if (buckets[key]!.isNotEmpty) _SchoolGroup(key, buckets[key]!),
  ];
}

String _schoolClassKey(String title) {
  final t = title.trim().toUpperCase();
  if (t.startsWith('JSS1')) return 'JSS1';
  if (t.startsWith('JSS2')) return 'JSS2';
  if (t.startsWith('SS1') || t.startsWith('SSS1')) return 'SS1';
  if (t.startsWith('SS2') || t.startsWith('SSS2')) return 'SS2';
  return 'More';
}

String _schoolLessonTitle(String title) {
  return title
      .replaceFirst(
        RegExp(r'^(JSS1|JSS2|SS1|SS2|SSS1|SSS2)\s*[-–—:]?\s*',
            caseSensitive: false),
        '',
      )
      .trim();
}

class _LessonWeek {
  final String? week;
  final String? term;
  final String title;
  final List<SchoolLibraryItem> items;
  const _LessonWeek({
    required this.week,
    required this.term,
    required this.title,
    required this.items,
  });
}

final RegExp _weekPattern = RegExp(r'week\s*(\d+)', caseSensitive: false);
final RegExp _termPattern = RegExp(r'term\s*(\d+)', caseSensitive: false);

List<_LessonWeek> _bundleWeeks(List<SchoolLibraryItem> items) {
  final order = <String>[];
  final buckets = <String, List<SchoolLibraryItem>>{};
  for (final item in items) {
    final week = _weekPattern.firstMatch(item.title)?.group(1);
    final key = week ?? 'item:${item.id}';
    buckets.putIfAbsent(key, () {
      order.add(key);
      return <SchoolLibraryItem>[];
    }).add(item);
  }
  return [for (final key in order) _weekFrom(key, buckets[key]!)];
}

_LessonWeek _weekFrom(String key, List<SchoolLibraryItem> source) {
  final week = key.startsWith('item:') ? null : key;
  final items = [...source]..sort((a, b) {
      int rank(SchoolLibraryItem item) {
        final type = item.resourceType;
        if (type == SchoolLibraryResourceType.videoFile ||
            type == SchoolLibraryResourceType.youtube) {
          return 0;
        }
        return 1;
      }

      return rank(a).compareTo(rank(b));
    });
  String? term;
  var topic = '';
  for (final item in items) {
    final termMatch = _termPattern.firstMatch(item.title);
    if (termMatch != null) term = 'Term ${termMatch.group(1)}';
    final candidate = _topicFromTitle(item.title);
    if (candidate.length > topic.length) topic = candidate;
  }
  if (topic.isEmpty) {
    topic = week != null ? 'Lesson' : _schoolLessonTitle(items.first.title);
  }
  return _LessonWeek(week: week, term: term, title: topic, items: items);
}

String _topicFromTitle(String title) {
  var text = _schoolLessonTitle(title);
  text = text.replaceFirst(RegExp(r'^term\s*\d+\s*', caseSensitive: false), '');
  text = text.replaceFirst(RegExp(r'^week\s*\d+\s*', caseSensitive: false), '');
  text = text.replaceFirst(RegExp(r'^[-–—:]\s*'), '');
  text = text.replaceFirst(
    RegExp(r'\s*[-–—]\s*videos?$', caseSensitive: false),
    '',
  );
  return text.trim();
}

String _sectionMeta(List<_LessonWeek> weeks) {
  final numbered = weeks.where((week) => week.week != null).length;
  if (numbered == weeks.length && numbered > 0) {
    return numbered == 1 ? '1 week' : '$numbered weeks';
  }
  final count = weeks.fold<int>(0, (sum, week) => sum + week.items.length);
  return count == 1 ? '1 lesson' : '$count lessons';
}

class _SchoolCatalog extends StatelessWidget {
  final String name;
  final int lessonCount;
  final int classCount;
  final List<_SchoolGroup> groups;
  final void Function(SchoolLibraryItem item) onOpen;

  const _SchoolCatalog({
    required this.name,
    required this.lessonCount,
    required this.classCount,
    required this.groups,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCHOOL LIBRARY',
            style: GoogleFonts.poppins(
              color: AppColors.goldText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: wide ? 34 : 28,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 3,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 12),
          Text(
            '$lessonCount lessons · $classCount classes',
            style: GoogleFonts.nunito(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final group in groups) ...[
            const SizedBox(height: 28),
            _ClassSection(group: group, onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

class _ClassSection extends StatelessWidget {
  final _SchoolGroup group;
  final void Function(SchoolLibraryItem item) onOpen;
  const _ClassSection({required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final weeks = _bundleWeeks(group.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              group.label,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              _sectionMeta(weeks),
              style: GoogleFonts.nunito(
                color: AppColors.textHint,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 680 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: weeks.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 168,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => _WeekCard(
                week: weeks[index],
                onOpen: onOpen,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  final _LessonWeek week;
  final void Function(SchoolLibraryItem item) onOpen;
  const _WeekCard({required this.week, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final eyebrow = week.week != null
        ? (week.term ?? 'WEEK').toUpperCase()
        : 'LESSON';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: week.items.length == 1 ? () => onOpen(week.items.first) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (week.week != null)
                    Text(
                      week.week!.padLeft(2, '0'),
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: GoogleFonts.poppins(
                            color: AppColors.textHint,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          week.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  for (var i = 0; i < week.items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _OpenButton(
                        item: week.items[i],
                        onTap: () => onOpen(week.items[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  final SchoolLibraryItem item;
  final VoidCallback onTap;
  const _OpenButton({required this.item, required this.onTap});

  bool get _video =>
      item.resourceType == SchoolLibraryResourceType.videoFile ||
      item.resourceType == SchoolLibraryResourceType.youtube;

  String get _label {
    if (_video) return 'Watch';
    if (item.resourceType == SchoolLibraryResourceType.pdf) return 'Notes';
    if (item.resourceType == SchoolLibraryResourceType.image) return 'View';
    return 'Open';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _video ? AppColors.textOnGold : AppColors.primary;
    return Material(
      color: _video ? AppColors.secondary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: _video
                ? null
                : Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _video
                    ? Icons.play_arrow_rounded
                    : Icons.description_outlined,
                size: 16,
                color: foreground,
              ),
              const SizedBox(width: 4),
              Text(
                _label,
                style: GoogleFonts.poppins(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── YouTube-synced home (Khan Academy, Crash Course, TED-Ed, etc.) ───────────

class _YoutubeHomeContent extends StatelessWidget {
  final LibraryProvider lib;
  const _YoutubeHomeContent({required this.lib});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Playlists',
            icon: Icons.playlist_play_rounded,
          ),
        ),
        if (lib.playlists.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Educational videos are being curated. Pull down to refresh.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PlaylistCard(playlist: lib.playlists[i]),
                childCount: lib.playlists.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final YtPlaylist playlist;
  final bool compact;

  const _PlaylistCard({required this.playlist, this.compact = false});

  Color _difficultyColor() {
    switch (playlist.difficulty) {
      case 'beginner':
        return Colors.greenAccent;
      case 'advanced':
        return Colors.redAccent;
      case 'intermediate':
        return Colors.amberAccent;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LibraryPlaylistScreen(playlist: playlist),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (playlist.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: playlist.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.primarySoft),
                    )
                  else
                    Container(color: AppColors.primarySoft),
                  if (playlist.difficulty != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _difficultyColor().withOpacity(0.85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          playlist.difficulty!,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            playlist.title,
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
          Text(
            '${playlist.videoCount} videos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: compact ? 10 : 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTabs extends StatelessWidget {
  final LibraryProvider lib;
  const _SubjectTabs({required this.lib});

  @override
  Widget build(BuildContext context) {
    if (lib.usesYoutubeCatalog) {
      return _HorizontalFilterBar(
        height: 48,
        children: [
          for (var i = 0; i < lib.subjects.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildSubjectChip(context, lib.subjects[i]),
          ],
        ],
      );
    }
    return _TopicPills(lib: lib);
  }

  Widget _buildSubjectChip(BuildContext context, String key) {
    final active = lib.activeSubject == key;
    final count = lib.subjectCounts[key] ?? 0;
    return GestureDetector(
      onTap: () => lib.setSubject(key),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: active
              ? null
              : Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          count > 0 ? '${ytSubjectLabel(key)} ($count)' : ytSubjectLabel(key),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable chip row that works inside [CustomScrollView] on mobile/web.
class _HorizontalFilterBar extends StatelessWidget {
  final double height;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _HorizontalFilterBar({
    required this.height,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 6),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: padding,
          clipBehavior: Clip.none,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

typedef LibraryOpenVideo = Future<void> Function(LibraryVideo video, {String? ytVideoId});

class _SearchResults extends StatelessWidget {
  final LibraryProvider lib;
  final LibraryOpenVideo onOpen;

  const _SearchResults({required this.lib, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().user?.id;
    final results = lib.searchResults;

    if (results.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            lib.searchQuery.length < 2
                ? 'Type at least 2 characters to search'
                : 'No videos match "${lib.searchQuery}"',
            style: GoogleFonts.nunito(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final v = results[i];
          final playable = lib.toPlayable(v, topic: 'general');
          return ListTile(
            leading: v.thumbnailUrl != null
                ? Image.network(v.thumbnailUrl!, width: 64, height: 36, fit: BoxFit.cover)
                : const Icon(Icons.play_circle, color: AppColors.textHint),
            title: Text(v.title,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            subtitle: Text(v.durationLabel,
                style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            onTap: () => onOpen(playable, ytVideoId: v.id),
          );
        },
        childCount: results.length,
      ),
    );
  }
}

// ── Legacy home (curated library_videos fallback) ─────────────────────────────

class _LegacyHomeContent extends StatelessWidget {
  final LibraryProvider lib;
  final LibraryOpenVideo onOpen;

  const _LegacyHomeContent({required this.lib, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        if (lib.featured != null)
          _FeaturedHero(video: lib.featured!, onOpen: onOpen),
        if (lib.all.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(title: 'Curated Videos', icon: Icons.video_library_rounded),
          _VideoCarousel(videos: lib.all.take(12).toList(), onOpen: onOpen),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }
}

class _HomeContent extends _LegacyHomeContent {
  const _HomeContent({required super.lib, required super.onOpen});
}

// ── Featured Hero ────────────────────────────────────────────────────────────

class _FeaturedHero extends StatelessWidget {
  final LibraryVideo video;
  final LibraryOpenVideo onOpen;

  const _FeaturedHero({required this.video, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(video),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LibraryThumbnail(
                  video: video,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      _ThumbnailPlaceholder(topic: video.topic),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.25),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Info overlay
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '★  FEATURED TODAY',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            video.topic,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          video.channelName,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        if (video.durationSeconds > 0) ...[
                          Text(
                            '  ·  ${video.durationLabel}',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Play button
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Topic Pills ───────────────────────────────────────────────────────────────

class _TopicPills extends StatelessWidget {
  final LibraryProvider lib;
  const _TopicPills({required this.lib});

  @override
  Widget build(BuildContext context) {
    final topics = lib.availableTopics;
    return _HorizontalFilterBar(
      height: 42,
      children: [
        for (var i = 0; i < topics.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildTopicChip(topics[i]),
        ],
      ],
    );
  }

  Widget _buildTopicChip(String topic) {
    final active = lib.activeTopic == topic;
    return GestureDetector(
      onTap: () => lib.setTopic(topic),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: active
              ? null
              : Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(
          topic,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Video Carousel ────────────────────────────────────────────────────────────

class _VideoCarousel extends StatelessWidget {
  final List<LibraryVideo> videos;
  final LibraryOpenVideo onOpen;
  final bool compact;

  const _VideoCarousel(
      {required this.videos, required this.onOpen, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cardW = compact ? 160.0 : 220.0;
    final listH = compact ? 168.0 : 194.0;

    return SizedBox(
      height: listH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 0),
        itemBuilder: (_, i) {
          return SizedBox(
            width: cardW + 12,
            height: listH,
            child: _VideoCard(
              video: videos[i],
              onOpen: onOpen,
              width: cardW,
              compact: compact,
            ),
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final LibraryVideo video;
  final LibraryOpenVideo onOpen;
  final double width;
  final bool compact;

  const _VideoCard({
    required this.video,
    required this.onOpen,
    required this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    const metaH = 52.0;
    const channelH = 14.0;
    const titleH = metaH - channelH;

    return GestureDetector(
      onTap: () => onOpen(video),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbH = constraints.maxHeight - metaH - gap;
            return ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: width,
                      height: thumbH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LibraryThumbnail(
                            video: video,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _ThumbnailPlaceholder(topic: video.topic),
                          ),
                          if (video.durationSeconds > 0)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  video.durationLabel,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: gap),
                  SizedBox(
                    height: metaH,
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: titleH,
                          child: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: compact ? 11.5 : 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: channelH,
                          child: Text(
                            video.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              height: 1.1,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Search / Filter Results ───────────────────────────────────────────────────

class _SearchOrFilterResults extends StatelessWidget {
  final LibraryProvider lib;
  final LibraryOpenVideo onOpen;

  const _SearchOrFilterResults({required this.lib, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final videos = lib.filtered;

    if (videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              lib.searchActive
                  ? 'No videos match "${lib.searchQuery}"'
                  : 'No videos in "${lib.activeTopic}" yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            if (!lib.searchActive && lib.activeTopic != 'All') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => lib.setTopic('All'),
                child: const Text('Show all topics'),
              ),
            ],
          ],
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              lib.searchActive
                  ? '${videos.length} result${videos.length == 1 ? '' : 's'} for "${lib.searchQuery}"'
                  : '${videos.length} video${videos.length == 1 ? '' : 's'} in ${lib.activeTopic}',
              style: GoogleFonts.nunito(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridVideoCard(video: videos[i], onOpen: onOpen)
                  .animate(delay: (i * 30).ms)
                  .fade(duration: 280.ms)
                  .slideY(begin: 0.05),
              childCount: videos.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridVideoCard extends StatelessWidget {
  final LibraryVideo video;
  final LibraryOpenVideo onOpen;

  const _GridVideoCard({required this.video, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LibraryThumbnail(
                    video: video,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _ThumbnailPlaceholder(topic: video.topic),
                  ),
                  if (video.durationSeconds > 0)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(video.durationLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: SizedBox(
              height: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        video.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          height: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bookmarks Screen ──────────────────────────────────────────────────────────

class _BookmarksScreen extends StatelessWidget {
  final LibraryOpenVideo onOpen;
  const _BookmarksScreen({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final ytVideos = lib.ytBookmarked;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.plum,
        title: Text('Watch Later',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ytVideos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded,
                      size: 56, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text('No saved videos yet',
                      style: GoogleFonts.nunito(
                          color: AppColors.textHint, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Tap the bookmark icon on any video to save it.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          color: AppColors.textHint, fontSize: 13)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.92,
              ),
              itemCount: ytVideos.length,
              itemBuilder: (_, i) {
                final v = ytVideos[i];
                final playable = lib.toPlayable(v, topic: 'general');
                return _GridVideoCard(video: playable, onOpen: onOpen);
              },
            ),
    );
  }
}

// ── Shared Helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final String topic;
  const _ThumbnailPlaceholder({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarySoft,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_topicIcon(topic), color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(topic,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off_rounded,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('Could not load library',
              style: GoogleFonts.nunito(
                  color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

IconData _subjectIcon(String subject) {
  switch (subject) {
    case 'mathematics':
      return Icons.calculate_rounded;
    case 'biology':
      return Icons.biotech_rounded;
    case 'chemistry':
      return Icons.science_rounded;
    case 'physics':
      return Icons.bolt_rounded;
    case 'english':
      return Icons.menu_book_rounded;
    case 'foreign_language':
      return Icons.translate_rounded;
    case 'history':
      return Icons.history_edu_rounded;
    case 'health_wellness':
      return Icons.favorite_rounded;
    default:
      return Icons.school_rounded;
  }
}

IconData _topicIcon(String topic) {
  if (topic.contains('Biology')) return Icons.biotech_rounded;
  if (topic.contains('Chemistry')) return Icons.science_rounded;
  if (topic.contains('Physics')) return Icons.bolt_rounded;
  if (topic.contains('Science')) return Icons.public_rounded;
  if (topic.contains('Math')) return Icons.calculate_rounded;
  if (topic.contains('English') || topic.contains('Literature'))
    return Icons.menu_book_rounded;
  if (topic.contains('History')) return Icons.history_edu_rounded;
  if (topic.contains('Geography') || topic.contains('Civics'))
    return Icons.map_rounded;
  if (topic.contains('Technology') || topic.contains('Coding'))
    return Icons.code_rounded;
  if (topic.contains('Study')) return Icons.school_rounded;
  if (topic.contains('Health')) return Icons.favorite_rounded;
  if (topic.contains('Career') || topic.contains('Life Skills'))
    return Icons.work_outline_rounded;
  if (topic.contains('Communication') || topic.contains('Leadership'))
    return Icons.groups_rounded;
  if (topic.contains('Mindset') || topic.contains('Psychology'))
    return Icons.self_improvement_rounded;
  if (topic.contains('Philosophy')) return Icons.psychology_alt_rounded;
  return Icons.play_circle_rounded;
}
