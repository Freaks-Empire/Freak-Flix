/// lib/screens/remote_player_native.dart
/// Native implementation using webview_flutter for mobile/desktop.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds a WebView-based embed player for native platforms.
Widget buildEmbedPlayer(String embedUrl) {
  return _NativeEmbedPlayer(embedUrl: embedUrl);
}

class _NativeEmbedPlayer extends StatefulWidget {
  final String embedUrl;
  
  const _NativeEmbedPlayer({required this.embedUrl});

  @override
  State<_NativeEmbedPlayer> createState() => _NativeEmbedPlayerState();
}

class _NativeEmbedPlayerState extends State<_NativeEmbedPlayer> {
  late WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _ready = true);
        },
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_ready)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
