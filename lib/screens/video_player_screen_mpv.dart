import 'package:flutter/material.dart';
import 'package:flutter_mpv/flutter_mpv.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  const VideoPlayerScreen({required this.filePath, super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late MpvController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MpvController();
    _controller.initialize();
    _controller.open([widget.filePath]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: MpvView(controller: _controller)),
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
