import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/library_youtube_embed.dart';
import '../../widgets/library_thumbnail.dart';

import '../../constants/app_constants.dart';
import '../../models/library_video_model.dart';
import '../../models/yt_library_models.dart';
import '../../models/library_watch_limit.dart';
import '../../providers/library_provider.dart';
import '../../services/library_service.dart';
import '../../widgets/library_watch_limit_dialog.dart';

class LibraryVideoPlayerScreen extends StatefulWidget {
  final LibraryVideo video;
  final String? userId;
  final String? ytVideoId;
  final List<YtVideo>? playlistVideos;
  final String? playlistSubject;
  final bool watchAlreadyRecorded;

  const LibraryVideoPlayerScreen({
    super.key,
    required this.video,
    this.userId,
    this.ytVideoId,
    this.playlistVideos,
    this.playlistSubject,
    this.watchAlreadyRecorded = false,
  });

  @override
  State<LibraryVideoPlayerScreen> createState() =>
      _LibraryVideoPlayerScreenState();
}

class _LibraryVideoPlayerScreenState extends State<LibraryVideoPlayerScreen> {
  YoutubePlayerController? _yt;
  bool _descExpanded = false;
  List<LibraryVideo> _related = [];
  bool _loadingRelated = true;
  bool _useNativePlayer = false;
  bool _watchBlocked = false;
  bool _watchReady = false;

  @override
  void initState() {
    super.initState();
    _useNativePlayer = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _initWatchAccess();
    _loadRelated();
  }

  Future<void> _initWatchAccess() async {
    final uid = widget.userId;
    final videoId = widget.ytVideoId ?? widget.video.youtubeId;

    if (uid != null && !widget.watchAlreadyRecorded) {
      final status =
          await context.read<LibraryProvider>().tryStartWatch(uid, videoId);
      if (!mounted) return;
      if (!status.allowed) {
        setState(() {
          _watchBlocked = true;
          _watchReady = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showLibraryWatchLimitDialog(context, status);
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() => _watchReady = true);
    _setupPlayer();
  }

  void _setupPlayer() {
    if (_watchBlocked || !_useNativePlayer || _yt != null) return;
    _yt = YoutubePlayerController(
      initialVideoId: widget.video.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        loop: false,
      ),
    );
    _yt!.addListener(_onPlayerTick);
    setState(() {});
  }

  Future<void> _loadRelated() async {
    try {
      final videos = await LibraryService.instance.getRelated(widget.video);
      if (mounted) setState(() { _related = videos; _loadingRelated = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  DateTime? _lastProgressSave;

  void _onPlayerTick() {
    if (widget.ytVideoId == null || widget.userId == null || _yt == null) return;
    final pos = _yt!.value.position.inSeconds;
    final dur = _yt!.value.metaData.duration.inSeconds;
    final now = DateTime.now();
    if (_lastProgressSave != null &&
        now.difference(_lastProgressSave!) < const Duration(seconds: 30)) {
      return;
    }
    _lastProgressSave = now;
    context.read<LibraryProvider>().updateProgress(
          widget.userId!,
          widget.ytVideoId!,
          pos,
          dur,
        );
  }

  @override
  void dispose() {
    _yt?.removeListener(_onPlayerTick);
    _yt?.dispose();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  void _onFullscreenChanged(bool fullscreen) {
    if (kIsWeb) return;
    if (fullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _openRelated(LibraryVideo v) async {
    final uid = widget.userId;
    final watchId = v.youtubeId;
    if (uid != null) {
      final status =
          await context.read<LibraryProvider>().tryStartWatch(uid, watchId);
      if (!status.allowed && mounted) {
        await showLibraryWatchLimitDialog(context, status);
        return;
      }
    }
    if (!mounted) return;
    context.read<LibraryProvider>().trackView(v.id);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryVideoPlayerScreen(
          video: v,
          userId: widget.userId,
          watchAlreadyRecorded: true,
        ),
      ),
    );
  }

  Widget _buildInfoSection(LibraryProvider lib, bool isBookmarked) {
    return _VideoInfo(
      video: widget.video,
      isBookmarked: isBookmarked,
      userId: widget.userId,
      descExpanded: _descExpanded,
      onToggleDesc: () => setState(() => _descExpanded = !_descExpanded),
      related: _related,
      loadingRelated: _loadingRelated,
      onOpenRelated: _openRelated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final isBookmarked = widget.userId != null &&
        lib.isBookmarked(widget.video.id);

    if (!_watchReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_watchBlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(widget.video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top_rounded,
                    size: 56, color: AppColors.primary.withOpacity(0.8)),
                const SizedBox(height: 16),
                Text(
                  'Daily watch limit reached',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can watch up to $kLibraryDailyVideoLimit videos per day in the library. Try again tomorrow.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(color: Colors.white54, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_useNativePlayer && _yt != null) {
      return YoutubePlayerBuilder(
        onEnterFullScreen: () => _onFullscreenChanged(true),
        onExitFullScreen: () => _onFullscreenChanged(false),
        player: YoutubePlayer(
          controller: _yt!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.primary,
          progressColors: ProgressBarColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
          ),
        ),
        builder: (ctx, player) => Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          body: Column(
            children: [
              player,
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _buildInfoSection(lib, isBookmarked),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb && libraryYoutubeEmbedSupported) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D1A),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(widget.video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return SizedBox(
                    width: w,
                    height: w * 9 / 16,
                    child: buildLibraryYoutubeEmbed(widget.video.youtubeId),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(
                child: _buildInfoSection(lib, isBookmarked),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop native fallback — thumbnail preview (no external redirect button).
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.video.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LibraryThumbnail(video: widget.video, fit: BoxFit.cover),
                  Container(
                    color: Colors.black.withOpacity(0.35),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_filled_rounded,
                            size: 72, color: Colors.white),
                        const SizedBox(height: 12),
                        Text('In-app playback is available on mobile and web.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _buildInfoSection(lib, isBookmarked),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video Info Section ─────────────────────────────────────────────────────────

class _VideoInfo extends StatelessWidget {
  final LibraryVideo video;
  final bool isBookmarked;
  final String? userId;
  final bool descExpanded;
  final VoidCallback onToggleDesc;
  final List<LibraryVideo> related;
  final bool loadingRelated;
  final void Function(LibraryVideo) onOpenRelated;

  const _VideoInfo({
    required this.video,
    required this.isBookmarked,
    this.userId,
    required this.descExpanded,
    required this.onToggleDesc,
    required this.related,
    required this.loadingRelated,
    required this.onOpenRelated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.4), width: 1),
          ),
          child: Text(video.topic,
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
        const SizedBox(height: 10),
        Text(video.title,
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.smart_display_rounded,
                size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600)),
            ),
            if (video.durationSeconds > 0) ...[
              const Icon(Icons.schedule_rounded,
                  size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(video.durationLabel,
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: Colors.white38)),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (userId != null)
          _ActionChip(
            icon: isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: isBookmarked ? 'Saved' : 'Save',
            active: isBookmarked,
            onTap: () => context.read<LibraryProvider>().toggleBookmark(
                  video.id,
                  userId!,
                  isYt: video.id == video.youtubeId,
                ),
          ),
        const SizedBox(height: 18),
        if (video.description?.isNotEmpty == true) ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onToggleDesc,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video.description!,
                    maxLines: descExpanded ? null : 3,
                    overflow: descExpanded ? null : TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.6)),
                const SizedBox(height: 6),
                Text(
                  descExpanded ? 'Show less' : 'Read more',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (video.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: video.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('#$t',
                          style: GoogleFonts.nunito(
                              fontSize: 11, color: Colors.white38)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        Text('More like this',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 12),
        if (loadingRelated)
          const Center(
              child: CircularProgressIndicator(color: Colors.white24))
        else if (related.isEmpty)
          Text('No related videos yet.',
              style: GoogleFonts.nunito(
                  color: Colors.white38, fontSize: 13))
        else
          ...related.map((v) =>
              _RelatedRow(video: v, onTap: () => onOpenRelated(v))
                  .animate()
                  .fade(duration: 300.ms)),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionChip(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.18)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: active ? AppColors.primary : Colors.white54),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : Colors.white54,
                )),
          ],
        ),
      ),
    );
  }
}

class _RelatedRow extends StatelessWidget {
  final LibraryVideo video;
  final VoidCallback onTap;

  const _RelatedRow({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LibraryThumbnail(video: video, fit: BoxFit.cover),
                    if (video.durationSeconds > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
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
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.88),
                          height: 1.3)),
                  const SizedBox(height: 4),
                  Text(video.channelName,
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
