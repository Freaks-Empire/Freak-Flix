import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/media_item.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/video_player/netflix_video_controls.dart';

class VideoPlayerScreen extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> playlist; // Optional playlist
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.item,
    this.playlist = const [],
    this.initialIndex = 0,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  // State
  bool _showControls = true;
  bool _isObscured = false; // NSFW Curtain
  bool _showSkipIntro = false;
  Timer? _hideTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Default NSFW curtain if adult
    _isObscured = widget.item.isAdult;

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Determine URL. If it's a web/http stream, use it. If local, file.
    String url = widget.item.filePath;
    
    // Handle OneDrive refresh if needed
    if (widget.item.streamUrl != null) {
      if (widget.item.streamUrl!.contains('graph.microsoft.com')) {
         // quick refresh logic or usage of existing valid url
         url = widget.item.streamUrl!;
      } else {
         url = widget.item.streamUrl!;
      }
    }

    await _player.open(Media(url));
    
    // Restore position if any
    if (widget.item.lastPositionSeconds > 0) {
      await _player.seek(Duration(seconds: widget.item.lastPositionSeconds));
    } else {
       // If no saved position, check intro logic immediately
    }

    // Listeners
    _player.stream.position.listen((pos) {
      if (_isDisposed) return;
      _checkSkipIntro(pos);
      _updateProgress(pos);
    });

    _startHideTimer();
  }

  void _checkSkipIntro(Duration pos) {
    if (widget.item.introStart != null && widget.item.introEnd != null) {
      final start = Duration(seconds: widget.item.introStart!);
      final end = Duration(seconds: widget.item.introEnd!);
      
      final shouldShow = pos >= start && pos <= end;
      if (shouldShow != _showSkipIntro && mounted) {
        setState(() => _showSkipIntro = shouldShow);
      }
    }
  }

  void _updateProgress(Duration pos) {
    // Debounce or optimize this in a real app, but for now update provider
    if (pos.inSeconds % 10 == 0) {
       context.read<PlaybackProvider>().updateProgress(widget.item, pos.inSeconds);
    }
  }

  void _skipIntro() {
    if (widget.item.introEnd != null) {
      _player.seek(Duration(seconds: widget.item.introEnd! + 1));
      setState(() => _showSkipIntro = false);
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onPanUpdate() {
    // Reset timer on user interaction
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _toggleObscure() {
    setState(() => _isObscured = !_isObscured);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideTimer?.cancel();
    
    // Save final progress
    final pos = _player.state.position.inSeconds;
    if (pos > 10) {
      context.read<PlaybackProvider>().updateProgress(widget.item, pos);
    }

    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure Black Theme
      body: MouseRegion(
        onHover: (_) => _onPanUpdate(),
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTap: () => _player.playOrPause(),
          onLongPress: _toggleObscure, // Panic Gesture
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Video Layer
              Video(controller: _controller, fit: BoxFit.contain),

              // 2. NSFW Curtain (Blur)
              if (_isObscured)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.eyeOff, color: Colors.white, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            "Content Hidden",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _toggleObscure,
                            child: const Text("Reveal"),
                          )
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Controls Layer
              AnimatedOpacity(
                opacity: _showControls && !_isObscured ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls || _isObscured,
                  child: NetflixControls(
                    player: _player,
                    title: widget.item.title ?? "Unknown Title",
                    episodeTitle: widget.item.episode != null ? "Ep ${widget.item.episode}" : "",
                    onNextEpisode: () {
                       // Implement next episode logic here or emit event
                    },
                    onShowAudioSubs: _showAudioSubsModal,
                  ),
                ),
              ),

              // 4. Skip Intro Button
              if (_showSkipIntro && !_isObscured && _showControls)
                Positioned(
                  bottom: 120,
                  right: 32,
                  child: FilledButton.icon(
                    onPressed: _skipIntro,
                    icon: const Icon(LucideIcons.skipForward),
                    label: const Text("Skip Intro"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      foregroundColor: Colors.black,
                    ),
                  ).animate().fadeIn().slideX(begin: 0.2, end: 0),
                ),
            ],
          ),
        ),
      ),
    );
  }



  void _showAudioSubsModal() {
    // MediaKit exposes tracks in `_player.state.tracks`
    // We map them to generic Lists
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.95), // Glassy dark
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: SizedBox(
            height: 400,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: Colors.redAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Audio'),
                    Tab(text: 'Subtitles'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // AUDIO TRACKS
                      _buildTrackList<AudioTrack>(
                        _player.state.tracks.audio, 
                        _player.state.track.audio,
                        (track) {
                           _player.setAudioTrack(track);
                           Navigator.pop(ctx);
                        }
                      ),
                      // SUBTITLE TRACKS
                      _buildTrackList<SubtitleTrack>(
                        _player.state.tracks.subtitle, 
                        _player.state.track.subtitle,
                        (track) {
                           _player.setSubtitleTrack(track);
                           Navigator.pop(ctx);
                        }
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

   Widget _buildTrackList<T>(List<T> tracks, T current, Function(T) onSelect) {
     return ListView.builder(
       itemCount: tracks.length,
       itemBuilder: (context, index) {
         final track = tracks[index];
         String label = 'Track ${index + 1}';
         
         if (track is AudioTrack) {
           label = track.title ?? track.language ?? track.id;
         } else if (track is SubtitleTrack) {
           label = track.title ?? track.language ?? track.id;
         } else {
            label = track.toString();
         }
         
         final isSelected = track == current;

         return ListTile(
           leading: isSelected ? const Icon(Icons.check, color: Colors.redAccent) : const SizedBox(width: 24),
           title: Text(label, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white)),
           onTap: () => onSelect(track),
         );
       },
     );
  }


}
