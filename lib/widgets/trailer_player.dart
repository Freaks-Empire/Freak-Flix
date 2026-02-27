// lib/widgets/trailer_player.dart
//
// Cross-platform trailer widget with graceful fallback for desktop runtimes.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/platform/platform.dart';

bool useExternalTrailerLaunch({required bool isDesktopRuntime}) {
  return isDesktopRuntime;
}

class TrailerPlayer extends StatefulWidget {
  final String videoId; // e.g. "dQw4w9WgXcQ"

  const TrailerPlayer({super.key, required this.videoId});

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  YoutubePlayerController? _controller;
  bool _useExternalLaunch = false;

  @override
  void initState() {
    super.initState();
    _useExternalLaunch = useExternalTrailerLaunch(
      isDesktopRuntime: isDesktopPlatform,
    );
    if (_useExternalLaunch) {
      return;
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  Future<void> _openTrailerExternally(BuildContext context) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'In-app trailer playback is not available yet. Open the trailer URL manually.',
          ),
        ),
      );
    }
  }

  Widget _buildDesktopFallback(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(
              'https://img.youtube.com/vi/${widget.videoId}/maxresdefault.jpg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openTrailerExternally(context),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'In-app trailer playback is not available on $currentPlatformLabel yet. Tap to open YouTube.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useExternalLaunch) {
      return _buildDesktopFallback(context);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: YoutubePlayer(
          controller: _controller!,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }
}
