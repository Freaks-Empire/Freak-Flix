import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/media_item.dart';
import '../../providers/playback_provider.dart';
import '../../services/graph_auth_service.dart';

class AdvancedVideoPlayerScreen extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> playlist; // Optional playlist
  final int initialIndex;

  const AdvancedVideoPlayerScreen({
    super.key,
    required this.item,
    this.playlist = const [],
    this.initialIndex = 0,
  });

  @override
  State<AdvancedVideoPlayerScreen> createState() => _AdvancedVideoPlayerScreenState();
}

class _AdvancedVideoPlayerScreenState extends State<AdvancedVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  // State
  bool _showControls = true;
  bool _isObscured = false; // NSFW Curtain
  bool _showSkipIntro = false;
  Timer? _hideTimer;
  bool _isDisposed = false;

  // Dragging
  bool _isDragging = false;
  double _dragValue = 0.0;

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
      if (mounted && !_isDragging) setState(() => _showControls = false);
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
                  child: _buildControlsUI(context),
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

  Widget _buildControlsUI(BuildContext context) {
    return Stack(
      children: [
        // Top Gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
          ),
        ),
        
        // Bottom Gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.9), Colors.transparent],
              ),
            ),
          ),
        ),

        // Top Bar
        Positioned(
          top: 24,
          left: 16,
          right: 16,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.title ?? "Unknown Title",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Panic Button
              IconButton(
                icon: const Icon(LucideIcons.eyeOff, color: Colors.white70),
                tooltip: "Obscure Screen (Panic)",
                onPressed: _toggleObscure,
              ),
              // Audio/Sub Switcher
              IconButton(
                icon: const Icon(LucideIcons.languages, color: Colors.white),
                onPressed: _showAudioSubsModal,
              ),
            ],
          ),
        ),

        // Center Play Button
        Center(
          child: StreamBuilder<bool>(
            stream: _player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return GestureDetector(
                onTap: _player.playOrPause,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ).animate(target: isPlaying ? 0 : 1).fade(),
              );
            },
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 32,
          left: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seek Bar & Time
              StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final duration = _player.state.duration;
                  
                  // Use dragging value if user is scrubbing
                  final displaySeconds = _isDragging ? _dragValue : pos.inSeconds.toDouble();
                  final maxSeconds = duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0;

                  return Row(
                    children: [
                      Text(
                        _formatDuration(Duration(seconds: displaySeconds.toInt())),
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 2, // Ultra thin
                            activeTrackColor: Colors.redAccent, // Netflix Red
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.redAccent,
                            overlayColor: Colors.redAccent.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: displaySeconds.clamp(0, maxSeconds),
                            min: 0,
                            max: maxSeconds,
                            onChangeStart: (_) {
                              setState(() => _isDragging = true);
                            },
                            onChanged: (val) {
                              setState(() => _dragValue = val);
                            },
                            onChangeEnd: (val) {
                              _player.seek(Duration(seconds: val.toInt()));
                              setState(() => _isDragging = false);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                       Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Bottom Action Row (Play/Skip/Volume)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.rewind, color: Colors.white),
                    onPressed: () => _player.seek(_player.state.position - const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 24),
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return IconButton(
                        iconSize: 42,
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
                        onPressed: _player.playOrPause,
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(LucideIcons.fastForward, color: Colors.white),
                    onPressed: () => _player.seek(_player.state.position + const Duration(seconds: 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}
