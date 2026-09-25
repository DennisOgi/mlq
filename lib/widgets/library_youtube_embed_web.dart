// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

/// In-app YouTube iframe for Flutter Web — keeps users inside the app.
Widget buildLibraryYoutubeEmbed(String youtubeId) {
  final viewType = 'library-yt-$youtubeId';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    final iframe = html.IFrameElement()
      ..src =
          'https://www.youtube-nocookie.com/embed/$youtubeId?rel=0&modestbranding=1&playsinline=1&enablejsapi=1'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int _) => iframe,
    );
  }

  return HtmlElementView(viewType: viewType);
}

bool get libraryYoutubeEmbedSupported => true;
