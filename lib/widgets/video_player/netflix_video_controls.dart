import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class NetflixControls extends StatefulWidget {
  final Player player;
  final String title;
  final String episodeTitle;
  final VoidCallback onNextEpisode;
  final VoidCallback onShowAudioSubs;

  const NetflixControls({
    super.key,
    required this.player,
    required this.title,
    required this.episodeTitle,
    required this.onNextEpisode,
    required this.onShowAudioSubs,
  });

  @override
  State<NetflixControls> createState() => _NetflixControlsState();
}

class _NetflixControlsState extends State<NetflixControls> {
  // Use a transparent-to-black gradient for the bottom area
  final Color _netflixRed = const Color(0xFFE50914);

  void _onFullscreen() {
    // Basic toggle - implementation depends on window manager but we can try generic logic
    // or just leave it as a visual placeholder if no global handler is passed
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 120, // Tall enough for gradient fade
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.8], // Accelerate opacity at the bottom
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. The Ultra-Thin Seek Bar
            // It sits flush on top of the buttons
            SizedBox(
              height: 12, // Minimal hit area
              child: StreamBuilder<Duration>(
                stream: widget.player.stream.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final total = widget.player.state.duration;
                  return SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2, // Matches the reference image's thinness
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0), // Hidden thumb normally
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: _netflixRed,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: _netflixRed,
                      trackShape: _CustomTrackShape(), // Removes default padding
                    ),
                    child: Slider(
                      value: pos.inSeconds.toDouble().clamp(0, total.inSeconds.toDouble()),
                      max: total.inSeconds.toDouble(),
                      onChanged: (v) => widget.player.seek(Duration(seconds: v.toInt())),
                    ),
                  );
                },
              ),
            ),

            // 2. The Control Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- LEFT GROUP ---
                  // Play/Pause
                  StreamBuilder<bool>(
                    stream: widget.player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                        color: Colors.white,
                        onPressed: widget.player.playOrPause,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Rewind 10 (Circular arrow style)
                  _ControlIcon(
                    icon: Icons.replay_10_rounded, 
                    onTap: () => widget.player.seek(widget.player.state.position - const Duration(seconds: 10))
                  ),
                  // Forward 10
                  _ControlIcon(
                    icon: Icons.forward_10_rounded, 
                    onTap: () => widget.player.seek(widget.player.state.position + const Duration(seconds: 10))
                  ),
                  const SizedBox(width: 8),
                  // Volume
                  _ControlIcon(icon: Icons.volume_up_rounded, onTap: () {}),

                  // --- CENTER GROUP ---
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.episodeTitle.isNotEmpty ? "${widget.title} - ${widget.episodeTitle}" : widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  ),

                  // --- RIGHT GROUP ---
                  // Next Episode (Skip style icon)
                  _ControlIcon(icon: Icons.skip_next_rounded, onTap: widget.onNextEpisode),
                  const SizedBox(width: 8),
                  // Episodes List (Box stack icon)
                  _ControlIcon(icon: Icons.layers_outlined, onTap: () {}),
                   const SizedBox(width: 8),
                  // Audio/Subtitles (Bubble icon)
                  _ControlIcon(icon: Icons.cloud_queue, onTap: widget.onShowAudioSubs), // Using cloud as rough match for that "server" icon
                  const SizedBox(width: 8),
                  // Settings (Gear)
                  _ControlIcon(icon: Icons.settings_outlined, onTap: () {}),
                  const SizedBox(width: 8),
                  // Fullscreen (Corners icon)
                  _ControlIcon(icon: Icons.fullscreen_rounded, onTap: _onFullscreen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper for standard white icons
class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ControlIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 28),
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}

// Removes the default padding at the ends of the slider
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
