import 'dart:async';
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
  bool _visible = true;
  Timer? _hideTimer;
  bool _isPlaying = true;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double _volume = 100.0;

  // Gestures
  double? _dragStartVolume;
  // Brightness requires native plugin, simplified 'mock' for now or purely internal value
  double _brightness = 1.0; 
  double? _dragStartBrightness;

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
          _onUserInteraction(); // Show controls when video changes
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

  void _handleVerticalDragStart(DragStartDetails details) {
      final width = MediaQuery.of(context).size.width;
      if (details.globalPosition.dx > width / 2) {
          // Right side: Volume
          _dragStartVolume = widget.player.state.volume;
      } else {
          // Left side: Brightness (simulated opacity overlay for now or future plugin)
           _dragStartBrightness = _brightness;
      }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
      final delta = details.primaryDelta ?? 0;
      final width = MediaQuery.of(context).size.width;
      
      // Sensitivity
      const sensitivity = 0.5;

      if (details.globalPosition.dx > width / 2) {
          // Volume
          final current = _dragStartVolume ?? widget.player.state.volume;
          final newVol = (current - (delta * sensitivity)).clamp(0.0, 100.0);
          widget.player.setVolume(newVol);
          _dragStartVolume = newVol;
          setState(() => _volume = newVol);
      } else {
           // Brightness (simulating 0.0 to 1.0)
           final current = _dragStartBrightness ?? _brightness;
           // Invert delta because dragging up (negative) should increase brightness
           final newBright = (current - (delta * 0.01)).clamp(0.0, 1.0);
           setState(() {
             _brightness = newBright;
             _dragStartBrightness = newBright;
           });
           
           // Apply to system or overlay? 
           // Real app would use screen_brightness plugin.
      }
      _onUserInteraction();
  }
  
  void _showEpisodesSheet() {
      _hideTimer?.cancel();
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              builder: (_, scrollParams) => Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                      children: [
                           const SizedBox(height: 8),
                           Container(
                               width: 40, height: 4, 
                               decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                           ),
                           Padding(
                             padding: const EdgeInsets.all(16.0),
                             child: Text('Episodes in Playlist', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                           ),
                           Expanded(
                               child: ListView.builder(
                                   controller: scrollParams,
                                   itemCount: widget.playlist.length,
                                   itemBuilder: (ctx, i) {
                                       final item = widget.playlist[i];
                                       final isSelected = item.id == widget.item.id;
                                       return ListTile(
                                           selected: isSelected,
                                           selectedTileColor: Colors.white10,
                                           leading: item.posterUrl != null 
                                              ? Image.network(item.posterUrl!, width: 50, fit: BoxFit.cover, 
                                                errorBuilder: (_,__,___) => const Icon(Icons.movie, color: Colors.white54))
                                              : const Icon(Icons.movie, color: Colors.white54),
                                           title: Text(
                                               item.title ?? item.fileName, 
                                               style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white)
                                           ),
                                           subtitle: item.season != null 
                                              ? Text('S${item.season} E${item.episode}', style: const TextStyle(color: Colors.white54))
                                              : null,
                                           trailing: isSelected ? const Icon(Icons.play_arrow, color: Colors.redAccent) : null,
                                           onTap: () {
                                               Navigator.pop(ctx);
                                               widget.onJump?.call(i);
                                           },
                                       );
                                   },
                               ),
                           ),
                      ],
                  ),
              ),
          ),
      ).then((_) => _onUserInteraction());
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
          child: SingleChildScrollView(
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
                      if (val != null) widget.player.setAudioTrack(val);
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
                    if (val != null) widget.player.setSubtitleTrack(val);
                    Navigator.pop(ctx);
                  },
                  activeColor: Colors.redAccent,
                )),
              ],
            ),
          ),
        ),
      ),
    );
    _onUserInteraction();
  }

  @override
  Widget build(BuildContext context) {
    // Brightness overlay
    final brightnessOverlay = IgnorePointer(
        child: Container(
            color: Colors.black.withOpacity(1.0 - _brightness),
        ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Brightness Layer
        brightnessOverlay,

        KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            onTap: _onUserInteraction,
            onDoubleTap: _togglePlay, 
            onVerticalDragStart: _handleVerticalDragStart,
            onVerticalDragUpdate: _handleVerticalDragUpdate,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.item.title ?? widget.item.fileName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.item.season != null)
                                      Text(
                                          'S${widget.item.season} E${widget.item.episode} • ${widget.playlist.length} items',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                ],
                              ),
                            ),
                            if (widget.playlist.length > 1)
                                IconButton(
                                    icon: const Icon(Icons.playlist_play, color: Colors.white),
                                    tooltip: 'Episodes',
                                    onPressed: _showEpisodesSheet,
                                ),
                          ],
                        ),
                      ),
                    ),
    
                    // Center Play/Pause & Seek Indicators
                    if (_visible || _buffering)
                      Center(
                        child: _buffering 
                          ? const CircularProgressIndicator(color: Colors.redAccent)
                          : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              // Previous
                              if (widget.onPrevious != null) 
                                IconButton(
                                    iconSize: 48,
                                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                                    onPressed: widget.onPrevious,
                                ),
                              const SizedBox(width: 24),
                              // Play/Pause
                              IconButton(
                                iconSize: 64,
                                icon: Icon(
                                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                onPressed: _togglePlay,
                              ),
                              const SizedBox(width: 24),
                              // Next
                              if (widget.onNext != null)
                                IconButton(
                                    iconSize: 48,
                                    icon: const Icon(Icons.skip_next, color: Colors.white),
                                    onPressed: widget.onNext,
                                ),
                          ],
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
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        LayoutBuilder(
                                          builder: (ctx, constraints) {
                                            final double total = _duration.inMilliseconds.toDouble();
                                            final double buffered = _buffer.inMilliseconds.toDouble();
                                            if (total <= 0) return const SizedBox();
                                            final double width = constraints.maxWidth * (buffered / total).clamp(0.0, 1.0);
                                            return Container(
                                              width: width,
                                              height: 4,
                                              color: Colors.white38,
                                            );
                                          },
                                        ),
                                        Slider(
                                          value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                                          min: 0,
                                          max: _duration.inSeconds.toDouble(),
                                          onChanged: (val) {
                                            _seek(Duration(seconds: val.toInt()));
                                          },
                                        ),
                                      ],
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
                                  icon: Icon(
                                    _volume == 0 ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white
                                  ),
                                  onPressed: () {
                                     final newVol = _volume > 0 ? 0.0 : 100.0;
                                     widget.player.setVolume(newVol);
                                     setState(() => _volume = newVol);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.subtitles, color: Colors.white),
                                  onPressed: _showTracksDialog,
                                ),
                                IconButton(
                                  icon: switch (widget.fit) {
                                    BoxFit.contain => const Icon(Icons.aspect_ratio, color: Colors.white),
                                    BoxFit.cover => const Icon(Icons.crop_free, color: Colors.white),
                                    BoxFit.fill => const Icon(Icons.fit_screen, color: Colors.white),
                                    _ => const Icon(Icons.aspect_ratio, color: Colors.white),
                                  },
                                  tooltip: 'Aspect Ratio: ${widget.fit.name}',
                                  onPressed: () {
                                      final next = switch(widget.fit) {
                                          BoxFit.contain => BoxFit.cover,
                                          BoxFit.cover => BoxFit.fill,
                                          BoxFit.fill => BoxFit.contain,
                                          _ => BoxFit.contain,
                                      };
                                      widget.onFitChanged(next);
                                  },
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
          ),
      ],
    );
  }
}
