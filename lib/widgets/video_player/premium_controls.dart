import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PremiumVideoControls extends StatefulWidget {
  final Player player;
  final String title;
  final String episodeTitle;
  final VoidCallback onNextEpisode;
  final VoidCallback onShowAudioSubs;
  final VoidCallback onBack;
  final VoidCallback onCycleFit;
  
  const PremiumVideoControls({
    super.key,
    required this.player,
    required this.title,
    required this.episodeTitle,
    required this.onNextEpisode,
    required this.onShowAudioSubs,
    required this.onBack,
    required this.onCycleFit,
  });

  @override
  State<PremiumVideoControls> createState() => _PremiumVideoControlsState();
}

class _PremiumVideoControlsState extends State<PremiumVideoControls> {
  // Styles
  final Color _accentColor = const Color(0xFFE50914); // Netflix Red
  final double _barHeight = 4.0;
  
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- TOP BAR ---
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                BackButton(color: Colors.white, onPressed: widget.onBack),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.episodeTitle.isNotEmpty)
                        Text(
                          widget.episodeTitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- BOTTOM BAR ---
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: Colors.black.withOpacity(0.4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress Row
                    Row(
                      children: [
                        // Current Time
                        StreamBuilder<Duration>(
                          stream: widget.player.stream.position,
                          builder: (context, snapshot) {
                            final pos = snapshot.data ?? Duration.zero;
                            return Text(
                              _formatDuration(pos),
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // Slider
                        Expanded(
                          child: StreamBuilder<Duration>(
                            stream: widget.player.stream.position,
                            builder: (context, snapshot) {
                              final pos = snapshot.data ?? Duration.zero;
                              final total = widget.player.state.duration;
                              // Prevent division by zero
                              final max = total.inSeconds > 0 ? total.inSeconds.toDouble() : 1.0;
                              final value = pos.inSeconds.toDouble().clamp(0.0, max);
                              
                              return SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: _barHeight,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: _accentColor,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: _accentColor,
                                  overlayColor: _accentColor.withOpacity(0.2),
                                  trackShape: _CustomTrackShape(),
                                ),
                                child: Slider(
                                  value: value,
                                  min: 0,
                                  max: max,
                                  onChanged: (v) => widget.player.seek(Duration(seconds: v.toInt())),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Total Duration
                        Text(
                          _formatDuration(widget.player.state.duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Volume / Mute
                        StreamBuilder<double>(
                          stream: widget.player.stream.volume,
                          builder: (context, snapshot) {
                            final vol = snapshot.data ?? 100.0;
                            final isMuted = vol == 0;
                            return IconButton(
                              icon: Icon(isMuted ? LucideIcons.volumeX : LucideIcons.volume2, color: Colors.white),
                              onPressed: () => widget.player.setVolume(isMuted ? 100 : 0),
                              tooltip: isMuted ? 'Unmute' : 'Mute',
                            );
                          },
                        ),
                        
                        const Spacer(),
                        
                        // Skip Back 10s
                        IconButton(
                          icon: const Icon(LucideIcons.rotateCcw, color: Colors.white),
                          onPressed: () => widget.player.seek(widget.player.state.position - const Duration(seconds: 10)),
                          tooltip: '-10s (Left Arrow)',
                        ),
                        const SizedBox(width: 16),
                        
                        // Play/Pause (Big)
                        StreamBuilder<bool>(
                          stream: widget.player.stream.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white, 
                                foregroundColor: Colors.black,
                                iconSize: 32,
                              ),
                              icon: Icon(isPlaying ? LucideIcons.pause : LucideIcons.play),
                              onPressed: widget.player.playOrPause,
                              tooltip: 'Play/Pause (Space)',
                            );
                          },
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Skip Fwd 10s
                        IconButton(
                          icon: const Icon(LucideIcons.rotateCw, color: Colors.white),
                          onPressed: () => widget.player.seek(widget.player.state.position + const Duration(seconds: 10)),
                          tooltip: '+10s (Right Arrow)',
                        ),
                        
                        const Spacer(),

                        // Subtitles/Audio
                        IconButton(
                          icon: const Icon(LucideIcons.languages, color: Colors.white),
                          onPressed: widget.onShowAudioSubs,
                          tooltip: 'Audio & Subtitles',
                        ),
                        // Fit Mode
                        // IconButton(
                        //   icon: const Icon(LucideIcons.maximize, color: Colors.white),
                        //   onPressed: widget.onCycleFit,
                        //   tooltip: 'Cycle Fit',
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Slider Shape to remove padding
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
