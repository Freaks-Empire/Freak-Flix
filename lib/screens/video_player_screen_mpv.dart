import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../widgets/video_player/video_controls.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String? title;
  const VideoPlayerScreen({required this.filePath, this.title, super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    player.open(Media(widget.filePath));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Video(
              controller: controller,
              controls: NoVideoControls, // Disable default controls
            ),
          ),
          VideoControls(
            player: player,
            controller: controller,
            title: widget.title ?? 'Video',
            onBack: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
