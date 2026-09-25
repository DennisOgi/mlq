import 'package:flutter/material.dart';

/// Non-web platforms fall back to a thumbnail + external link pattern.
Widget buildLibraryYoutubeEmbed(String youtubeId) {
  return const SizedBox.shrink();
}

bool get libraryYoutubeEmbedSupported => false;
