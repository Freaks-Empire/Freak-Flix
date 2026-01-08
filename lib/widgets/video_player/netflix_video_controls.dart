import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';

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
  bool _hovering = false;
  bool _playing = false;
  double _volume = 100.0;
  
  // Netflix Red Color
  final Color _netflixRed = const Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    widget.player.stream.playing.listen((e) => setState(() => _playing = e));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        opacity: _hovering ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            // 1. The "Top Shadow" (Title Area)
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 20),
                      if (widget.episodeTitle.isNotEmpty) ...[
                         Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white70, 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const VerticalDivider(color: Colors.white54, indent: 10, endIndent: 10),
                        Text(
                          widget.episodeTitle,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 18,
                            fontWeight: FontWeight.normal
                          ),
                        ),
                      ] else 
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const Spacer(),
                      const Icon(Icons.flag_outlined, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),

            // 2. The "Bottom Shadow" (Controls Area)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 140, // Taller to accommodate hover interactions
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
                    // A. The Scrubber (Red Line)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        height: 20,
                        child: StreamBuilder<Duration>(
                          stream: widget.player.stream.position,
                          builder: (context, snapshot) {
                            final pos = snapshot.data ?? Duration.zero;
                            final total = widget.player.state.duration;
                            return SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3, // Netflix is thin
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: _netflixRed,
                                inactiveTrackColor: Colors.grey.withOpacity(0.5),
                                thumbColor: _netflixRed,
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
                    ),

                    // B. The Buttons Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          // Left Group
                          IconButton(
                            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 32, color: Colors.white),
                            onPressed: widget.player.playOrPause,
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.replay_10, size: 28, color: Colors.white),
                            onPressed: () => widget.player.seek(widget.player.state.position - const Duration(seconds: 10)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10, size: 28, color: Colors.white),
                            onPressed: () => widget.player.seek(widget.player.state.position + const Duration(seconds: 10)),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.volume_up, color: Colors.white, size: 28),
                          
                          const Spacer(),

                          // Right Group
                          Text(
                            "Next Episode",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 28, color: Colors.white),
                            onPressed: widget.onNextEpisode,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                             icon: const Icon(Icons.subtitles, color: Colors.white, size: 28),
                             onPressed: widget.onShowAudioSubs,
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.speed, color: Colors.white, size: 28),
                          const SizedBox(width: 20),
                          const Icon(Icons.fullscreen, color: Colors.white, size: 32),
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
