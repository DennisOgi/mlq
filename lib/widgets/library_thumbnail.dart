import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/library_video_model.dart';

/// YouTube thumbnail with automatic quality fallback when mq/hq 404.
class LibraryThumbnail extends StatelessWidget {
  final LibraryVideo video;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const LibraryThumbnail({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: video.thumbnailUrl,
      fit: fit,
      placeholder: placeholder,
      errorWidget: (ctx, url, err) {
        final fallbacks = video.thumbnailFallbacks;
        final idx = fallbacks.indexOf(url);
        if (idx >= 0 && idx + 1 < fallbacks.length) {
          return CachedNetworkImage(
            imageUrl: fallbacks[idx + 1],
            fit: fit,
            errorWidget: (c, u, e) =>
                errorWidget?.call(c, u, e) ??
                _BrokenThumb(topic: video.topic),
          );
        }
        return errorWidget?.call(ctx, url, err) ??
            _BrokenThumb(topic: video.topic);
      },
    );
  }
}

class _BrokenThumb extends StatelessWidget {
  final String topic;
  const _BrokenThumb({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white38, size: 28),
      ),
    );
  }
}
