import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/yt_library_models.dart';
import '../../providers/library_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/library_watch_limit_dialog.dart';
import 'library_video_player_screen.dart';

class LibraryPlaylistScreen extends StatefulWidget {
  final YtPlaylist playlist;

  const LibraryPlaylistScreen({super.key, required this.playlist});

  @override
  State<LibraryPlaylistScreen> createState() => _LibraryPlaylistScreenState();
}

class _LibraryPlaylistScreenState extends State<LibraryPlaylistScreen> {
  List<YtVideo> _videos = [];
  int _completed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<UserProvider>().user?.id;
    if (uid == null) return;
    final lib = context.read<LibraryProvider>();
    final videos = await lib.getPlaylistVideos(
      widget.playlist.id,
      uid,
      subject: widget.playlist.subject,
    );
    final done = await lib.getPlaylistCompletedCount(uid, widget.playlist.id);
    if (mounted) {
      setState(() {
        _videos = videos;
        _completed = done;
        _loading = false;
      });
    }
  }

  Future<void> _openVideo(YtVideo video) async {
    final uid = context.read<UserProvider>().user?.id;
    final lib = context.read<LibraryProvider>();

    if (uid != null) {
      final status = await lib.tryStartWatch(uid, video.id);
      if (!status.allowed && mounted) {
        await showLibraryWatchLimitDialog(context, status);
        return;
      }
    }

    if (!mounted) return;
    final playable = lib.toPlayable(
      video,
      topic: widget.playlist.subject,
      channel: widget.playlist.title,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryVideoPlayerScreen(
          video: playable,
          userId: uid,
          ytVideoId: video.id,
          playlistVideos: _videos,
          playlistSubject: widget.playlist.subject,
          watchAlreadyRecorded: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _videos.length;
    final progress = total == 0 ? 0.0 : _completed / total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.plum,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.playlist.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: widget.playlist.thumbnailUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(widget.playlist.title,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  '${ytSubjectLabel(widget.playlist.subject)} · $total videos',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$_completed of $total completed',
                    style: GoogleFonts.nunito(
                        color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ..._videos.map((v) => _VideoTile(video: v, onTap: () => _openVideo(v))),
              ],
            ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final YtVideo video;
  final VoidCallback onTap;

  const _VideoTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 120,
                    height: 68,
                    child: video.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnailUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(color: AppColors.primarySoft),
                  ),
                ),
                if (video.completed)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    ),
                  ),
              ],
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(video.durationLabel,
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
