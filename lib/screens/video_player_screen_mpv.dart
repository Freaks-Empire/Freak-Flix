import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';
import '../widgets/video_player/video_controls.dart';
import '../services/graph_auth_service.dart';
import 'package:flutter/foundation.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> playlist;

  VideoPlayerScreen({
    required this.item,
    List<MediaItem>? playlist,
    super.key,
  }) : playlist = playlist ?? [item];

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  
  late MediaItem _currentItem;
  late int _currentIndex;
  BoxFit _fit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _currentIndex = widget.playlist.indexWhere((e) => e.id == _currentItem.id);
    if (_currentIndex == -1) _currentIndex = 0;

    player = Player();
    controller = VideoController(player);
    
    _playCurrent();
  }

  bool _isLoadingLink = false;

  Future<void> _playCurrent() async {
    setState(() => _isLoadingLink = true);
    String path = _currentItem.streamUrl ?? _currentItem.filePath;
    
    // Check if this is a OneDrive item that needs a fresh link
    if (_currentItem.streamUrl != null && _currentItem.id.startsWith('onedrive:')) {
       try {
          if (_currentItem.folderPath.startsWith('onedrive:')) {
             final pathAfterPrefix = _currentItem.folderPath.substring('onedrive:'.length);
             final accountId = pathAfterPrefix.split('/').first;
             
             final idPrefix = 'onedrive_${accountId}_';
             if (_currentItem.id.startsWith(idPrefix)) {
                final realItemId = _currentItem.id.substring(idPrefix.length);
                
                debugPrint('Refreshing OneDrive URL for item $realItemId account $accountId');
                final fresh = await GraphAuthService.instance.getDownloadUrl(accountId, realItemId);
                if (fresh != null) {
                   path = fresh;
                   debugPrint('Got fresh URL: $fresh');
                } else {
                   throw Exception('Could not refresh download URL');
                }
             }
          }
       } catch (e) {
          debugPrint('Error refreshing URL: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error refreshing link: $e'), backgroundColor: Colors.red),
            );
          }
       }
    }

    setState(() => _isLoadingLink = false);
    await player.open(Media(path));
  }
  
  void _playIndex(int index) {
    if (index >= 0 && index < widget.playlist.length) {
      if (mounted) {
        setState(() {
            _currentIndex = index;
            _currentItem = widget.playlist[index];
        });
        _playCurrent();
      }
    }
  }

  void _next() {
      if (_currentIndex < widget.playlist.length - 1) {
          _playIndex(_currentIndex + 1);
      }
  }

  void _previous() {
      if (_currentIndex > 0) {
          _playIndex(_currentIndex - 1);
      }
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
              fit: _fit,
            ),
          ),
          VideoControls(
            player: player,
            controller: controller,
            item: _currentItem,
            playlist: widget.playlist,
            onBack: () => Navigator.pop(context),
            onNext: (_currentIndex < widget.playlist.length - 1) ? _next : null,
            onPrevious: (_currentIndex > 0) ? _previous : null,
            onJump: _playIndex,
            fit: _fit,
            onFitChanged: (v) => setState(() => _fit = v),
          ),
          if (_isLoadingLink)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Refreshing link...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
