/// lib/screens/video_player_screen_stub.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/graph_auth_service.dart';

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
  // We use a static counter to generate unique view IDs if multiple players are opened
  static int _viewIdCounter = 0;
  late String _viewType;
  
  html.VideoElement? _videoElement;
  String? _blobUrl;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Playlist State
  late int _currentIndex;
  late MediaItem _currentItem;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _currentIndex = widget.playlist.indexWhere((e) => e.id == _currentItem.id);
    if (_currentIndex == -1) _currentIndex = 0;

    _viewType = 'cinematic-player-${_viewIdCounter++}';
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Resolve URL (Handle OneDrive / Local)
      String url = _currentItem.streamUrl ?? _currentItem.filePath;
      
      if (_currentItem.id.startsWith('onedrive_')) {
          // OneDrive refresh logic
          final fresh = await _refreshOneDriveUrl(_currentItem);
          if (fresh != null) url = fresh;
      }
      
      // 2. Direct Stream (Avoid Blob/CORS issues)
      // OneDrive 'downloadUrl' is pre-signed and safe for direct playback.
      // Fetching as Blob via XHR triggers CORS and OOM on large files.
      debugPrint('Streaming directly from: $url');
      
      _blobUrl = url; // Reuse variable for download URL

      // 3. Create & Register Video Element with Anti-IDM attributes
      _videoElement = html.VideoElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain' 
        ..controls = false 
        ..autoplay = true;
        
      // CRITICAL: Anti-IDM Attributes
      _videoElement!.setAttribute('controlsList', 'nodownload');
      _videoElement!.onContextMenu.listen((e) => e.preventDefault());

      // Register View Factory
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _videoElement!);

      if (mounted) {
        setState(() => _isLoading = false);
      }
      
    } catch (e) {
      debugPrint('Web Player Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Playback Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _refreshOneDriveUrl(MediaItem item) async {
     // Simplified logic from previous implementation
     try {
       if (item.folderPath.startsWith('onedrive:')) {
           final pathAfterPrefix = item.folderPath.substring('onedrive:'.length);
           final accountId = pathAfterPrefix.split('/').first;
           final idPrefix = 'onedrive_${accountId}_';
           if (item.id.startsWith(idPrefix)) {
              final realId = item.id.substring(idPrefix.length);
              // Try download URL (HLS not supported via simple blob fetch easily without HLS.js)
              return await GraphAuthService.instance.getDownloadUrl(accountId, realId);
           }
       }
     } catch (e) {
       debugPrint('OneDrive refresh failed: $e');
     }
     return null;
  }

  void _playIndex(int index) {
    if (index >= 0 && index < widget.playlist.length) {
      // Clean up previous
      if (_blobUrl != null && _blobUrl!.startsWith('blob:')) {
        html.Url.revokeObjectUrl(_blobUrl!);
      }
      
      setState(() {
        _currentIndex = index;
        _currentItem = widget.playlist[index];
      });
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null && _blobUrl!.startsWith('blob:')) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    _videoElement?.pause();
    _videoElement?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Layer
          if (!_isLoading && _errorMessage == null)
            Positioned.fill(
              child: HtmlElementView(viewType: _viewType),
            ),

          // 2. Loading
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Securing stream...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            
          // 3. Error
          if (_errorMessage != null)
             Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),

          // 4. Controls
          if (!_isLoading && _videoElement != null)
            _WebNetflixControls(
              video: _videoElement!,
              title: _currentItem.title ?? _currentItem.fileName,
              onNext: _currentIndex < widget.playlist.length - 1 ? () => _playIndex(_currentIndex + 1) : null,
              onPrev: _currentIndex > 0 ? () => _playIndex(_currentIndex - 1) : null,
              onBack: () => Navigator.pop(context),
              downloadUrl: _blobUrl, // We control the download
            ),
        ],
      ),
    );
  }
}

class _WebNetflixControls extends StatefulWidget {
  final html.VideoElement video;
  final String title;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback onBack;
  final String? downloadUrl;

  const _WebNetflixControls({
    required this.video, 
    required this.title,
    this.onNext,
    this.onPrev,
    required this.onBack,
    this.downloadUrl,
  });

  @override
  State<_WebNetflixControls> createState() => _WebNetflixControlsState();
}

class _WebNetflixControlsState extends State<_WebNetflixControls> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _duration = 1.0;
  double _volume = 1.0;
  bool _hovering = false;

  
  // Netflix Red Color
  final Color _netflixRed = const Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    widget.video.onPlay.listen((_) => setState(() => _isPlaying = true));
    widget.video.onPause.listen((_) => setState(() => _isPlaying = false));
    widget.video.onTimeUpdate.listen((_) {
       if (widget.video.duration.isFinite) {
         setState(() {
           _progress = widget.video.currentTime.toDouble();
           _duration = widget.video.duration.toDouble();
         });
       }
    });
    // Sync initial state
    _isPlaying = !widget.video.paused;
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.video.pause();
    } else {
      widget.video.play();
    }
  }
  
  void _seek(double val) {
    widget.video.currentTime = val;
  }
  
  void _setVolume() {
     final newVol = _volume > 0 ? 0.0 : 1.0;
     widget.video.volume = newVol;
     setState(() => _volume = newVol);
  }

  void _onEnter() => setState(() => _hovering = true);
  void _onExit() => setState(() => _hovering = false);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: AnimatedOpacity(
        opacity: _hovering ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            // 1. Top Gradient Shadow
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 20),
                      Text(
                         widget.title,
                         style: const TextStyle(
                           color: Colors.white, 
                           fontSize: 18, 
                           fontWeight: FontWeight.bold
                         ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Bottom Gradient Shadow & Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 140, 
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // A. The Scrubber
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        height: 20,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3, 
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: _netflixRed,
                            inactiveTrackColor: Colors.grey.withOpacity(0.5),
                            thumbColor: _netflixRed,
                          ),
                          child: Slider(
                            value: _progress.clamp(0, _duration),
                            max: _duration,
                            onChanged: _seek,
                          ),
                        ),
                      ),
                    ),

                    // B. The Buttons Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 32, color: Colors.white),
                            onPressed: _togglePlay,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.replay_10, size: 28, color: Colors.white),
                            onPressed: () => _seek(_progress - 10),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, size: 28, color: Colors.white),
                            onPressed: () => _seek(_progress + 10),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(_volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 28),
                            onPressed: _setVolume,
                          ),
                          
                          const Spacer(),

                          Text(
                            "Next Episode",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 28, color: Colors.white),
                            onPressed: widget.onNext,
                          ),
                          const SizedBox(width: 20),
                          // Web doesn't typically support multiple tracks easily without MSE logic
                          const Icon(Icons.subtitles, color: Colors.white38, size: 28), 
                          const SizedBox(width: 20),
                          const Icon(Icons.speed, color: Colors.white, size: 28),
                          const SizedBox(width: 20),
                          IconButton(
                             icon: const Icon(Icons.fullscreen, color: Colors.white, size: 32),
                             onPressed: () {
                               if (html.document.fullscreenElement != null) {
                                 html.document.exitFullscreen();
                               } else {
                                 html.document.documentElement?.requestFullscreen();
                               }
                             },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
