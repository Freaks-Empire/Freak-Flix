import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final String title;
  final VoidCallback onBack;

  const VideoControls({
    super.key,
    required this.player,
    required this.controller,
    required this.title,
    required this.onBack,
  });

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _isPlaying = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    
    // Request focus for keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    
    _playingSub = widget.player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    _posSub = widget.player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    
    _durSub = widget.player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _playingSub.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _onUserInteraction();

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlay();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seek(_position + const Duration(seconds: 10));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seek(_position - const Duration(seconds: 10));
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _visible = false);
      }
    });
  }
  
  void _onUserInteraction() {
    if (mounted) {
      setState(() => _visible = true);
      _startHideTimer();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
    _onUserInteraction();
  }

  void _seek(Duration pos) {
    widget.player.seek(pos);
    _onUserInteraction();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final hours = d.inHours;
    if (hours > 0) {
      return '$hours:${minutes.remainder(60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTracksDialog() async {
    _hideTimer?.cancel();
    final tracks = widget.player.state.tracks;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Tracks', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tracks.audio.length > 1) ...[
                const Text('Audio', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...tracks.audio.map((t) => RadioListTile<AudioTrack>(
                  title: Text(t.title ?? t.language ?? t.id, style: const TextStyle(color: Colors.white)),
                  value: t,
                  groupValue: widget.player.state.track.audio,
                  onChanged: (val) {
                    widget.player.setAudioTrack(t);
                    Navigator.pop(ctx);
                  },
                  activeColor: Colors.redAccent,
                )),
                const SizedBox(height: 16),
              ],
              
              const Text('Subtitles', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
               RadioListTile<SubtitleTrack>(
                  title: const Text('None', style: TextStyle(color: Colors.white)),
                  value: SubtitleTrack.no(),
                  groupValue: widget.player.state.track.subtitle,
                  onChanged: (val) {
                    widget.player.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.pop(ctx);
                  },
                  activeColor: Colors.redAccent,
                ),
              ...tracks.subtitle.map((t) => RadioListTile<SubtitleTrack>(
                title: Text(t.title ?? t.language ?? t.id, style: const TextStyle(color: Colors.white)),
                value: t,
                groupValue: widget.player.state.track.subtitle,
                onChanged: (val) {
                  widget.player.setSubtitleTrack(t);
                  Navigator.pop(ctx);
                },
                activeColor: Colors.redAccent,
              )),
            ],
          ),
        ),
      ),
    );
    _onUserInteraction();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTap: _onUserInteraction,
        onDoubleTap: _togglePlay, // Simple double tap action
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
          // Visibility Wrapper
          AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                // Top Bar (Back + Title)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: widget.onBack,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Center Play/Pause (Big Icon)
                if (_visible)
                  Center(
                    child: IconButton(
                      iconSize: 64,
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: _togglePlay,
                    ),
                  ),

                // Bottom Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress Bar
                        Row(
                          children: [
                            Text(_formatDuration(_position), style: const TextStyle(color: Colors.white)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: Colors.redAccent,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.redAccent,
                                ),
                                child: Slider(
                                  value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                                  min: 0,
                                  max: _duration.inSeconds.toDouble(),
                                  onChanged: (val) {
                                    _seek(Duration(seconds: val.toInt()));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Action Buttons Row (Tracks, etc.)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.subtitles, color: Colors.white),
                              onPressed: _showTracksDialog,
                            ),
                            IconButton(
                              icon: const Icon(Icons.fullscreen, color: Colors.white), // Placeholder, window handles this mostly
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
