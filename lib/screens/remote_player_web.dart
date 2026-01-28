/// lib/screens/remote_player_web.dart
/// Web-specific implementation using iframe.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Builds an iframe-based embed player for Flutter Web.
Widget buildEmbedPlayer(String embedUrl) {
  return _WebEmbedPlayer(embedUrl: embedUrl);
}

class _WebEmbedPlayer extends StatefulWidget {
  final String embedUrl;
  
  const _WebEmbedPlayer({required this.embedUrl});

  @override
  State<_WebEmbedPlayer> createState() => _WebEmbedPlayerState();
}

class _WebEmbedPlayerState extends State<_WebEmbedPlayer> {
  late String _viewId;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'vidking-player-${widget.embedUrl.hashCode}';
    _registerView();
  }

  void _registerView() {
    // Register the view factory for this iframe
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.embedUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('allow', 'autoplay; fullscreen; encrypted-media');
        return iframe;
      },
    );
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    return HtmlElementView(viewType: _viewId);
  }
}
