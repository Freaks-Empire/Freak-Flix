/// lib/widgets/video_player/unified_controls.dart
/// 
/// Unified video player controls for all platforms
/// Consolidates duplicate control implementations

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Configuration for unified controls
class UnifiedControlsConfig {
  final String title;
  final String subtitle;
  final bool showAudioSubsButton;
  final bool showFitButton;
  final bool showNextPrevButtons;
  final bool showSkipIntroButton;
  final bool showFullscreenButton;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onShowAudioSubs;
  final VoidCallback? onBack;
  final VoidCallback? onCycleFit;
  final VoidCallback? onToggleFullscreen;
  final Function(double)? onSeek;
  final String? skipIntroText;
  final double? skipIntroPosition;
  final double? skipIntroEnd;

  const UnifiedControlsConfig({
    required this.title,
    this.subtitle = '',
    this.showAudioSubsButton = true,
    this.showFitButton = true,
    this.showNextPrevButtons = true,
    this.showSkipIntroButton = false,
    this.showFullscreenButton = true,
    this.onNextEpisode,
    this.onPrevEpisode,
    this.onShowAudioSubs,
    this.onBack,
    this.onCycleFit,
    this.onToggleFullscreen,
    this.onSeek,
    this.skipIntroText,
    this.skipIntroPosition,
    this.skipIntroEnd,
  });
}

/// Unified video player controls widget
class UnifiedVideoControls extends StatefulWidget {
  final Player player;
  final UnifiedControlsConfig config;
  final bool initiallyVisible;

  const UnifiedVideoControls({
    super.key,
    required this.player,
    required this.config,
    this.initiallyVisible = true,
  });

  @override
  State<UnifiedVideoControls> createState() => _UnifiedVideoControlsState();
}

class _UnifiedVideoControlsState extends State<UnifiedVideoControls> {
  bool _isVisible = true;
  bool _isPlaying = false;
  bool _showAudioSubsModal = false;
  BoxFit _currentFit = BoxFit.contain;

  // Styles
  static const Color _netflixRed = Color(0xFFE50914);
  static const double _controlsOpacity = 0.95;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.initiallyVisible;
    _setupPlayerListeners();
    _startHideTimer();
  }

  void _setupPlayerListeners() {
    widget.player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    widget.player.stream.position.listen((position) {
      if (mounted) {
        _checkSkipIntroVisibility(position);
      }
    });
  }

  void _checkSkipIntroVisibility(Duration position) {
    if (!widget.config.showSkipIntroButton || 
        widget.config.skipIntroPosition == null || 
        widget.config.skipIntroEnd == null) return;

    final shouldShow = position.inSeconds >= widget.config.skipIntroPosition! &&
                     position.inSeconds <= widget.config.skipIntroEnd!;

    if (shouldShow != _showAudioSubsModal && mounted) {
      setState(() => _showAudioSubsModal = shouldShow);
    }
  }

  Timer? _hideTimer;
  DateTime _lastInteraction = DateTime.now();

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        final timeSinceInteraction = DateTime.now().difference(_lastInteraction);
        if (timeSinceInteraction.inSeconds >= 4) {
          setState(() => _isVisible = false);
        }
      }
    });
  }

  void _onUserInteraction() {
    _lastInteraction = DateTime.now();
    if (!_isVisible) setState(() => _isVisible = true);
    _startHideTimer();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  void _seekTo(double position) {
    widget.config.onSeek?.call(position);
  }

  void _skipIntro() {
    if (widget.config.skipIntroEnd != null) {
      widget.player.seek(Duration(seconds: widget.config.skipIntroEnd!.round() + 1));
    }
  }

  void _cycleFit() {
    if (!widget.config.showFitButton) return;
    
    setState(() {
      switch (_currentFit) {
        case BoxFit.contain:
          _currentFit = BoxFit.cover;
          break;
        case BoxFit.cover:
          _currentFit = BoxFit.fill;
          break;
        case BoxFit.fill:
          _currentFit = BoxFit.contain;
          break;
        case BoxFit.fitWidth:
          _currentFit = BoxFit.contain;
          break;
        case BoxFit.fitHeight:
          _currentFit = BoxFit.contain;
          break;
        case BoxFit.scaleDown:
          _currentFit = BoxFit.contain;
          break;
        case BoxFit.none:
          _currentFit = BoxFit.contain;
          break;
      }
    });
    widget.config.onCycleFit?.call();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onUserInteraction(),
      onExit: (_) => _onUserInteraction(),
      onHover: (_) => _onUserInteraction(),
      child: GestureDetector(
        onTap: _onUserInteraction,
        onDoubleTap: _togglePlayPause,
        onPanUpdate: (_) => _onUserInteraction(),
        child: AnimatedOpacity(
          opacity: _isVisible ? _controlsOpacity : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Stack(
            children: [
              _buildTopBar(),
              _buildBottomBar(),
              if (_showAudioSubsModal && widget.config.showSkipIntroButton)
                _buildSkipIntroButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
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
                onPressed: widget.config.onBack,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.config.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.config.subtitle.isNotEmpty)
                      Text(
                        widget.config.subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
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
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
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
            _buildSeekBar(),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    return SizedBox(
      height: 12,
      child: StreamBuilder(
        stream: widget.player.stream.position,
        builder: (context, snapshot) {
          return StreamBuilder(
            stream: widget.player.stream.duration,
            builder: (context, durationSnapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = durationSnapshot.data ?? Duration.zero;
              final progress = duration.inSeconds > 0 
                  ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
                  : 0.0;

              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: _netflixRed,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: _netflixRed,
                ),
                child: Slider(
                  value: progress,
                  onChanged: _seekTo,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play/Pause
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
            color: Colors.white,
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 12),
          // Previous
          if (widget.config.showNextPrevButtons && widget.config.onPrevEpisode != null)
            IconButton(
              icon: const Icon(Icons.replay_10_rounded, size: 28),
              color: Colors.white,
              onPressed: () {
                widget.player.seek(widget.player.state.position - const Duration(seconds: 10));
              },
            ),
          if (widget.config.showNextPrevButtons)
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 28),
              color: Colors.white,
              onPressed: widget.config.onPrevEpisode,
            ),
          // Next
          if (widget.config.showNextPrevButtons)
            IconButton(
              icon: const Icon(Icons.forward_10_rounded, size: 28),
              color: Colors.white,
              onPressed: () {
                widget.player.seek(widget.player.state.position + const Duration(seconds: 10));
              },
            ),
          if (widget.config.showNextPrevButtons && widget.config.onNextEpisode != null)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 28),
              color: Colors.white,
              onPressed: widget.config.onNextEpisode,
            ),

          // Audio/Subs button
          if (widget.config.showAudioSubsButton && widget.config.onShowAudioSubs != null)
            IconButton(
              icon: const Icon(Icons.subtitles_rounded, size: 28),
              color: Colors.white,
              onPressed: widget.config.onShowAudioSubs,
            ),

          // Fit button
          if (widget.config.showFitButton)
            IconButton(
              icon: const Icon(Icons.aspect_ratio_rounded, size: 28),
              color: Colors.white,
              onPressed: _cycleFit,
            ),

          // Fullscreen button
          if (widget.config.showFullscreenButton && widget.config.onToggleFullscreen != null)
            IconButton(
              icon: const Icon(Icons.fullscreen_rounded, size: 28),
              color: Colors.white,
              onPressed: widget.config.onToggleFullscreen,
            ),
        ],
      ),
    );
  }

  Widget _buildSkipIntroButton() {
    return Positioned(
      bottom: 120,
      right: 32,
      child: FilledButton.icon(
        onPressed: _skipIntro,
        icon: const Icon(LucideIcons.skipForward),
        label: Text(widget.config.skipIntroText ?? 'Skip Intro'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.9),
          foregroundColor: Colors.black,
        ),
      ).animate().fadeIn().slideX(begin: 0.2, end: 0),
    );
  }
}