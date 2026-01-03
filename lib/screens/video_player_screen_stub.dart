/// lib/screens/video_player_screen_stub.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      
      // 2. Fetch as Blob (The Anti-IDM Secret Sauce)
      // Note: For long videos, this downloads the WHOLE file to RAM. 
      // Ideally we'd use Range headers & MediaSourceExtensions (MSE), but that's complex.
      // We'll stick to the requested Blob strategy.
      debugPrint('Fetching video blob from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load video: ${response.statusCode}');
      }
      
      final blob = html.Blob([response.bodyBytes], 'video/mp4');
      _blobUrl = html.Url.createObjectUrlFromBlob(blob);
      debugPrint('Blob URL created: $_blobUrl');

      // 3. Create & Register Video Element with Anti-IDM attributes
      _videoElement = html.VideoElement()
        ..src = _blobUrl!
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain' // Handle Fit later
        ..controls = false // Custom controls only
        ..autoplay = true;
        
      // CRITICAL: Anti-IDM Attributes
      _videoElement!.setAttribute('controlsList', 'nodownload');
      _videoElement!.onContextMenu.listen((e) => e.preventDefault());

      // Register View Factory
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _videoElement!);

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
      if (_blobUrl != null) html.Url.revokeObjectUrl(_blobUrl!);
      
      setState(() {
        _currentIndex = index;
        _currentItem = widget.playlist[index];
      });
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null) html.Url.revokeObjectUrl(_blobUrl!);
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
            _WebCinematicControls(
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

class _WebCinematicControls extends StatefulWidget {
  final html.VideoElement video;
  final String title;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback onBack;
  final String? downloadUrl;

  const _WebCinematicControls({
    required this.video, 
    required this.title,
    this.onNext,
    this.onPrev,
    required this.onBack,
    this.downloadUrl,
  });

  @override
  State<_WebCinematicControls> createState() => _WebCinematicControlsState();
}

class _WebCinematicControlsState extends State<_WebCinematicControls> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _duration = 1.0;
  double _volume = 1.0;
  bool _showSettings = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _startHideTimer();
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

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_showSettings) {
         setState(() => _showControls = false);
      }
    });
  }

  void _onInteraction() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  void _togglePlay() {
    if (_isPlaying) widget.video.pause();
    else widget.video.play();
    _onInteraction();
  }
  
  void _seek(double val) {
    widget.video.currentTime = val;
    _onInteraction();
  }
  
  void _setVolume(double val) {
     widget.video.volume = val;
     setState(() => _volume = val);
     _onInteraction();
  }
  
  void _setSpeed(double speed) {
    widget.video.playbackRate = speed;
    setState(() => _showSettings = false);
    _onInteraction();
  }

  void _triggerDownload() {
    if (widget.downloadUrl != null) {
       final anchor = html.AnchorElement(href: widget.downloadUrl)
         ..setAttribute('download', '${widget.title}.mp4')
         ..click();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _onInteraction(),
      child: GestureDetector(
        onTap: _togglePlay, // Tap anywhere to play/pause
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
             // Hover Gradients
             AnimatedOpacity(
               opacity: _showControls ? 1.0 : 0.0,
               duration: const Duration(milliseconds: 300),
               child: Container(
                 decoration: const BoxDecoration(
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                     stops: [0.0, 0.2, 0.7, 1.0],
                   ),
                 ),
               ),
             ),
             
             // Top Bar
             AnimatedPositioned(
               top: _showControls ? 0 : -100,
               left: 0, right: 0,
               duration: const Duration(milliseconds: 300),
               child: Padding(
                 padding: const EdgeInsets.all(24),
                 child: Row(
                   children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                        ),
                      ),
                   ],
                 ),
               ),
             ),

             // Bottom Controls
             AnimatedPositioned(
               bottom: _showControls ? 40 : -150,
               left: 0, right: 0,
               duration: const Duration(milliseconds: 300),
               child: Center(
                 child: _buildGlassCapsule(context),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCapsule(BuildContext context) {
    return Container( // Wrapper for centering constraint
      constraints: const BoxConstraints(maxWidth: 800), // Max width for capsule
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Progress Bar
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: Colors.redAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _progress.clamp(0, _duration),
                      min: 0,
                      max: _duration,
                      onChanged: _seek,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),

                // 2. Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     // Skip Back
                     IconButton(
                       icon: const Icon(Icons.replay_10, color: Colors.white70),
                       onPressed: () => _seek(_progress - 10),
                     ),
                     const SizedBox(width: 16),
                     
                     // Prev
                     if (widget.onPrev != null)
                        IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: widget.onPrev),

                     const SizedBox(width: 16),

                     // Play/Pause
                     GestureDetector(
                       onTap: _togglePlay,
                       child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.black, size: 28,
                          ),
                       ),
                     ),

                     const SizedBox(width: 16),

                     // Next
                     if (widget.onNext != null)
                        IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: widget.onNext),

                     const SizedBox(width: 16),

                     // Skip Fwd
                     IconButton(
                       icon: const Icon(Icons.forward_10, color: Colors.white70),
                       onPressed: () => _seek(_progress + 10),
                     ),
                     
                     // Spacer to Settings
                     const Spacer(),
                     
                     // Volume
                     Icon(Icons.volume_up, color: Colors.white70, size: 20),
                     SizedBox(
                       width: 80,
                       child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)),
                          child: Slider(value: _volume, onChanged: _setVolume),
                       ),
                     ),

                     const SizedBox(width: 16),

                     // Settings
                     Stack(
                       clipBehavior: Clip.none,
                       children: [
                         IconButton(
                           icon: const Icon(Icons.settings, color: Colors.white),
                           onPressed: () => setState(() => _showSettings = !_showSettings),
                         ),
                         if (_showSettings)
                            Positioned(
                              bottom: 50,
                              right: 0,
                              child: _buildSettingsMenu(),
                            ),
                       ],
                     ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Padding(
             padding: EdgeInsets.all(8.0),
             child: Text('Playback Speed', style: TextStyle(color: Colors.white54, fontSize: 12)),
           ),
           Row(
             children: [0.5, 1.0, 1.5, 2.0].map((s) => Expanded(
               child: InkWell(
                 onTap: () => _setSpeed(s),
                 child: Container(
                   alignment: Alignment.center,
                   padding: const EdgeInsets.symmetric(vertical: 6),
                   decoration: BoxDecoration(
                      color: widget.video.playbackRate == s ? Colors.white24 : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                   ),
                   child: Text('${s}x', style: const TextStyle(color: Colors.white)),
                 ),
               ),
             )).toList(),
           ),
           const Divider(color: Colors.white24),
           InkWell(
             onTap: () {
                _triggerDownload();
                setState(() => _showSettings = false);
             },
             child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Row(
                 children: const [
                   Icon(Icons.download, color: Colors.white, size: 16),
                   SizedBox(width: 8),
                   Text('Download Video', style: TextStyle(color: Colors.white)),
                 ],
               ),
             ),
           ),
        ],
      ),
    );
  }
}
