/// lib/widgets/video_player/video_controls.dart
import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/media_item.dart';

class VideoControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final MediaItem item;
  final List<MediaItem> playlist;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final ValueChanged<int>? onJump;

  const VideoControls({
    super.key,
    required this.player,
    required this.controller,
    required this.item,
    required this.playlist,
    required this.onBack,
    this.onNext,
    this.onPrevious,
    this.onJump,
    required this.fit,
    required this.onFitChanged,
  });

  final BoxFit fit;
  final ValueChanged<BoxFit> onFitChanged;

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  // State
  bool _visible = true;
  Timer? _hideTimer;
  bool _isPlaying = true;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double _volume = 100.0;
  
  // UI Interaction State
  bool _isHovering = false;
  bool _isScrubbing = false;

  // Streams
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;
  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<Duration> _bufferSub;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    
    _playingSub = widget.player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    
    _bufferingSub = widget.player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _buffering = buffering);
    });

    _posSub = widget.player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    
    _durSub = widget.player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _bufferSub = widget.player.stream.buffer.listen((buffer) {
      if (mounted) setState(() => _buffer = buffer);
    });
    
    _volume = widget.player.state.volume;
  }

  @override
  void didUpdateWidget(VideoControls oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (oldWidget.item.id != widget.item.id) {
          _onUserInteraction(); 
      }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _playingSub.cancel();
    _bufferingSub.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _bufferSub.cancel();
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
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onBack();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isHovering && !_isScrubbing) {
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

  Future<void> _showTracksDialog() async {
     // TODO: Implement tracks dialog (reused from old impl if needed, but keeping this concise for now)
     // Use a customized glassmorphism dialog for consistency
  }

  @override
  Widget build(BuildContext context) {
    // Determine visibility based on explicit state or hovering
    final showControls = _visible || _isHovering || !_isPlaying || _isScrubbing;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() { _isHovering = true; _visible = true; }),
        onExit: (_) => setState(() { _isHovering = false; _startHideTimer(); }),
        onHover: (_) => _onUserInteraction(),
        child: GestureDetector(
          onTap: _onUserInteraction,
          onDoubleTap: _togglePlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // 1. Hover Gradients (Subtle)
              AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Stack(
                  children: [
                    // Top Gradient
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: 120,
                      child: DecoratedBox(
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
                      bottom: 0, left: 0, right: 0,
                      height: 200,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Top Bar (Back Button & Title)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: showControls ? 0 : -100,
                left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                       // Glass Back Button
                       ClipRRect(
                         borderRadius: BorderRadius.circular(50),
                         child: BackdropFilter(
                           filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                           child: Container(
                             color: Colors.white.withOpacity(0.1),
                             child: IconButton(
                               icon: const Icon(Icons.arrow_back, color: Colors.white),
                               onPressed: widget.onBack,
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 20),
                       // Title Info
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               widget.item.title ?? widget.item.fileName,
                               style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                 color: Colors.white, 
                                 fontWeight: FontWeight.bold,
                                 shadows: [const Shadow(blurRadius: 8, color: Colors.black45)]
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                             if (widget.item.season != null)
                               Text(
                                 'Season ${widget.item.season} • Episode ${widget.item.episode}',
                                 style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5),
                               ),
                           ],
                         ),
                       ),
                       // Top Right Settings
                       IconButton(
                         icon: const Icon(Icons.settings, color: Colors.white70),
                         onPressed: _showTracksDialog,
                       ),
                    ],
                  ),
                ),
              ),

              // 3. Center Buffering Indicator
              if (_buffering)
                const Center(child: CircularProgressIndicator(color: Colors.white)),

              // 4. Bottom Controls Layer
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: showControls ? 0 : -150,
                left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Bar (Interactive)
                      _buildImmersiveProgressBar(context),
                      
                      const SizedBox(height: 16),

                      // Control Row
                      Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            // Left Spacer / Time
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                            ),

                            // Center Capsule
                            _buildGlassCapsule(),

                            // Right Tools (Volume, Fit)
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                     icon: Icon(_volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white70),
                                     onPressed: () {
                                       setState(() => _volume = _volume > 0 ? 0.0 : 100.0);
                                       widget.player.setVolume(_volume);
                                     },
                                  ),
                                  IconButton(
                                     icon: const Icon(Icons.fullscreen, color: Colors.white70),
                                     onPressed: () {
                                        // Toggle fit as pseudo-fullscreen toggle for now
                                        final next = switch(widget.fit) {
                                            BoxFit.contain => BoxFit.cover,
                                            _ => BoxFit.contain,
                                        };
                                        widget.onFitChanged(next);
                                     },
                                  ),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildGlassCapsule() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
               BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Prev
               IconButton(
                 icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                 onPressed: widget.onPrevious,
                 tooltip: 'Previous',
               ),
               const SizedBox(width: 12),
               
               // Play/Pause Main
               GestureDetector(
                 onTap: _togglePlay,
                 child: Container(
                   width: 50, height: 50,
                   decoration: BoxDecoration(
                     color: Colors.white,
                     shape: BoxShape.circle,
                     boxShadow: [
                       BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)
                     ],
                   ),
                   child: Icon(
                     _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                     color: Colors.black,
                     size: 32,
                   ),
                 ),
               ),

               const SizedBox(width: 12),
               
               // Next
               IconButton(
                 icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                 onPressed: widget.onNext,
                 tooltip: 'Next',
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImmersiveProgressBar(BuildContext context) {
     // Custom slider theme for thin line
     return MouseRegion(
       cursor: SystemMouseCursors.click,
       child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2, // Ultra thin
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: Colors.redAccent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.redAccent,
            overlayColor: Colors.redAccent.withOpacity(0.2),
            trackShape: _CustomTrackShape(), // Custom track to ensure full width
          ),
          child: Slider(
            value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
            min: 0,
            max: _duration.inSeconds.toDouble(),
            onChangeStart: (_) => _isScrubbing = true,
            onChangeEnd: (_) => _isScrubbing = false,
            onChanged: (val) {
               _seek(Duration(seconds: val.toInt()));
            },
          ),
       ),
     );
  }
}

class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight!;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
