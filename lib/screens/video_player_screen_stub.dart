/// lib/screens/video_player_screen_stub.dart
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
  String? _errorMessage;
  bool _isLoadingLink = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _currentIndex = widget.playlist.indexWhere((e) => e.id == _currentItem.id);
    if (_currentIndex == -1) _currentIndex = 0;

    player = Player();
    controller = VideoController(player);
    
    // Subscribe to errors
    player.stream.error.listen((event) {
       debugPrint('VideoPlayerScreen Web ERROR: $event');
       setState(() {
          _errorMessage = 'Player Error: $event';
       });
    });

    // Subscribe to logs (warn/error)
    player.stream.log.listen((event) {
       if (event.level == 'error' || event.level == 'warn') {
          debugPrint('VideoPlayerScreen Web LOG [${event.level}]: $event');
       }
    });

    _playCurrent();
  }

  Future<void> _playCurrent() async {
    setState(() => _isLoadingLink = true);
    String path = _currentItem.streamUrl ?? _currentItem.filePath;
    
    debugPrint('VideoPlayerScreen Web: _playCurrent called for item ${_currentItem.id}');
    
    // Check if this is a OneDrive item (needs a network link)
    // IDs start with 'onedrive_' (underscore).
    final isOneDrive = _currentItem.id.startsWith('onedrive_');

    if (isOneDrive) {
       debugPrint('VideoPlayerScreen Web: OneDrive item detected. Attempting refresh/fetch...');
       try {
          if (_currentItem.folderPath.startsWith('onedrive:')) {
             final pathAfterPrefix = _currentItem.folderPath.substring('onedrive:'.length);
             final accountId = pathAfterPrefix.split('/').first;
             
             final idPrefix = 'onedrive_${accountId}_';
             if (_currentItem.id.startsWith(idPrefix)) {
                final realItemId = _currentItem.id.substring(idPrefix.length);
                
                debugPrint('Refreshing OneDrive URL for item $realItemId account $accountId');
                
                // Try HLS first for quality selection
                String? fresh = await GraphAuthService.instance.getHlsUrl(accountId, realItemId);
                if (fresh == null) {
                    debugPrint('VideoPlayerScreen Web: HLS unavailable (returned null), falling back to download URL');
                    fresh = await GraphAuthService.instance.getDownloadUrl(accountId, realItemId);
                } else {
                    debugPrint('VideoPlayerScreen Web: HLS URL obtained successfully: $fresh');
                }

                if (fresh != null) {
                   path = fresh;
                   debugPrint('VideoPlayerScreen Web: Playing with fresh URL: $path');
                } else {
                   debugPrint('VideoPlayerScreen Web: Could not refresh download URL, using original streamUrl');
                }
             }
          }
       } catch (e) {
          debugPrint('VideoPlayerScreen Web: Error refreshing URL: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error refreshing link: $e'), backgroundColor: Colors.red),
            );
          }
       }
    } else {
       debugPrint('VideoPlayerScreen Web: Local/Static item. Skipping OneDrive refresh.');
    }

    setState(() => _isLoadingLink = false);
    
    // Final check: If path is still an internal ID, fail.
    if (path.startsWith('onedrive') && !path.startsWith('http') && !path.contains('/') && !path.contains('\\')) {
       if (path.startsWith('onedrive_')) {
          setState(() {
             _errorMessage = 'Could not resolve playback URL for cloud item.\nPlease try rescanning or check your internet connection.';
          });
          return;
       }
    }

    debugPrint('VideoPlayerScreen Web: Opening player with path: $path');
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
          if (_errorMessage != null)
             Container(
                color: Colors.black87,
                child: Center(
                   child: Padding(
                     padding: const EdgeInsets.all(24.0),
                     child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           const Icon(Icons.error, color: Colors.red, size: 48),
                           const SizedBox(height: 16),
                           Text(
                              'Playback Error',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                           ),
                           const SizedBox(height: 8),
                           Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                           ),
                           const SizedBox(height: 24),
                           ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Go Back'),
                           )
                        ],
                     ),
                   ),
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
