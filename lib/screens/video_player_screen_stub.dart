import 'package:flutter/material.dart';
import '../models/media_item.dart';

class VideoPlayerScreen extends StatelessWidget {
  final MediaItem item;
  final List<MediaItem>? playlist;
  
  const VideoPlayerScreen({
    required this.item,
    this.playlist,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Center(
            child: Text(
              'Playback not supported on Web with current MPV backend.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
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
