import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../constants/app_constants.dart';
import '../../models/school_library_item.dart';
import '../../providers/school_library_provider.dart';
import '../../widgets/library_youtube_embed.dart';

/// Opens a school library item: YouTube, uploaded video, image, or PDF/link.
class SchoolLibraryViewerScreen extends StatefulWidget {
  final SchoolLibraryItem item;

  const SchoolLibraryViewerScreen({super.key, required this.item});

  @override
  State<SchoolLibraryViewerScreen> createState() =>
      _SchoolLibraryViewerScreenState();
}

class _SchoolLibraryViewerScreenState extends State<SchoolLibraryViewerScreen> {
  YoutubePlayerController? _yt;
  VideoPlayerController? _video;
  String? _signedUrl;
  bool _loading = true;
  String? _error;
  bool _useNativeYt = false;

  SchoolLibraryItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _useNativeYt = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      if (item.resourceType == SchoolLibraryResourceType.youtube) {
        final id = item.youtubeId;
        if (id == null || id.isEmpty) {
          throw Exception('Missing YouTube id');
        }
        if (_useNativeYt) {
          _yt = YoutubePlayerController(
            initialVideoId: id,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              enableCaption: true,
            ),
          );
        }
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (item.hasStorageFile) {
        final url =
            await context.read<SchoolLibraryProvider>().signedUrl(item);
        if (!mounted) return;
        _signedUrl = url;

        if (item.resourceType == SchoolLibraryResourceType.videoFile) {
          _video = VideoPlayerController.networkUrl(Uri.parse(url));
          await _video!.initialize();
          _video!.addListener(_onVideoTick);
          if (!mounted) return;
          await _video!.play();
        }
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (item.externalUrl != null && item.externalUrl!.isNotEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      throw Exception('No playable content on this item');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _togglePlay() async {
    final video = _video;
    if (video == null) return;
    if (video.value.isPlaying) {
      await video.pause();
    } else {
      await video.play();
    }
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoTick);
    _yt?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (item.resourceType) {
      case SchoolLibraryResourceType.youtube:
        return _stage(player: _youtubePlayer());
      case SchoolLibraryResourceType.videoFile:
        return _stage(player: _uploadedPlayer());
      case SchoolLibraryResourceType.image:
        return _imageBody();
      case SchoolLibraryResourceType.pdf:
      case SchoolLibraryResourceType.document:
      case SchoolLibraryResourceType.link:
        return _documentBody();
    }
  }

  Widget _stage({required Widget player}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final byWidth = constraints.maxWidth * 9 / 16;
        final cap = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.56
            : byWidth;
        final height = byWidth < cap ? byWidth : cap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: ColoredBox(
                color: Colors.black,
                child: player,
              ),
            ),
            Expanded(child: _details(showPlayHint: true)),
          ],
        );
      },
    );
  }

  Widget _youtubePlayer() {
    final id = item.youtubeId!;
    if (_useNativeYt && _yt != null) {
      return YoutubePlayer(
        controller: _yt!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.secondary,
      );
    }
    if (kIsWeb && libraryYoutubeEmbedSupported) {
      return buildLibraryYoutubeEmbed(id);
    }
    return _playFallback(
      onTap: () => _openExternal('https://www.youtube.com/watch?v=$id'),
      label: 'Watch on YouTube',
    );
  }

  Widget _uploadedPlayer() {
    final video = _video;
    if (_loading || video == null || !video.value.isInitialized) {
      return _preparing();
    }
    final playing = video.value.isPlaying;
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          ),
          if (!playing)
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 42),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _videoBar(video),
          ),
        ],
      ),
    );
  }

  Widget _videoBar(VideoPlayerController video) {
    final value = video.value;
    final total = value.duration.inMilliseconds;
    final pos = value.position.inMilliseconds.clamp(0, total == 0 ? 0 : total);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 8, 2),
        child: Row(
          children: [
            IconButton(
              onPressed: _togglePlay,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: AppColors.secondary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: total == 0 ? 0 : pos / total,
                  onChanged: (v) {
                    video.seekTo(Duration(
                      milliseconds: (v * total).round(),
                    ));
                  },
                ),
              ),
            ),
            Text(
              _clock(value.position),
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preparing() {
    return const ColoredBox(
      color: Color(0xFF14141C),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Preparing video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playFallback({required VoidCallback? onTap, required String label}) {
    return ColoredBox(
      color: const Color(0xFF14141C),
      child: Center(
        child: TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.play_circle_fill_rounded,
              color: Colors.white, size: 28),
          label: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _documentBody() {
    final url = _signedUrl ?? item.externalUrl;
    final isPdf = item.resourceType == SchoolLibraryResourceType.pdf;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _CoverCard(item: item),
              const SizedBox(height: 22),
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(
                    icon: isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.open_in_new_rounded,
                    label: item.resourceType.label,
                  ),
                  if (item.sizeLabel.isNotEmpty) _Chip(label: item.sizeLabel),
                ],
              ),
              if (item.description != null &&
                  item.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  item.description!,
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (url != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openExternal(url),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: const Color(0xFF1A1408),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    isPdf
                        ? 'Open PDF'
                        : item.resourceType ==
                                SchoolLibraryResourceType.document
                            ? 'Open document'
                            : 'Open link',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageBody() {
    final url = _signedUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (url != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'Could not load image',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _details(showPlayHint: false),
      ],
    );
  }

  Widget _details({required bool showPlayHint}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          item.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              icon: showPlayHint
                  ? Icons.play_circle_fill_rounded
                  : Icons.image_rounded,
              label: item.resourceType.label,
              gold: showPlayHint,
            ),
            if (item.sizeLabel.isNotEmpty) _Chip(label: item.sizeLabel),
          ],
        ),
        if (item.description != null &&
            item.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            item.description!,
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

class _CoverCard extends StatelessWidget {
  final SchoolLibraryItem item;
  const _CoverCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPdf = item.resourceType == SchoolLibraryResourceType.pdf;
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF14141C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPdf ? Icons.description_outlined : Icons.link_rounded,
            color: AppColors.secondary,
            size: 28,
          ),
          const SizedBox(height: 14),
          Text(
            item.resourceType.label.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Container(width: 36, height: 3, color: AppColors.secondary),
          const SizedBox(height: 12),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool gold;
  const _Chip({required this.label, this.icon, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final color = gold ? AppColors.secondary : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: gold
            ? AppColors.secondary.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.nunito(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
