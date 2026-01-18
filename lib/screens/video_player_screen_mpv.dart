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
import '../../services/graph_auth_service.dart';

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
  bool _hasMarkedWatched = false; // Prevent spamming provider
  Timer? _hideTimer;
  bool _isDisposed = false;
  int _lastSavedPosition = 0; // Throttle progress persistence

  @override
  void initState() {
    super.initState();
    // Default NSFW curtain if adult
    _isObscured = false; // widget.item.isAdult;

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Determine URL. 
    String url = widget.item.filePath;
    
    // If it's a OneDrive item, we MUST refresh the download URL because it expires.
    if (widget.item.id.startsWith('onedrive_')) {
      final parts = widget.item.id.split('_');
      if (parts.length >= 3) {
        // Format: onedrive_{accountId}_{itemId}
        // Note: itemId might contain underscores? Usually Graph IDs are alphanumeric but let's be safe.
        // Actually, let's parse carefully.
        // The accountId is UUID (36 chars) usually? 
        // Let's rely on split.
        final accountId = parts[1]; 
        final itemId = parts.sublist(2).join('_'); // Join back just in case itemId has underscores
        
        debugPrint('VideoPlayer: Refreshing OneDrive URL for $itemId (Account: $accountId)...');
        final freshUrl = await GraphAuthService().getDownloadUrl(accountId, itemId);
        
        if (freshUrl != null) {
          url = freshUrl;
          debugPrint('VideoPlayer: Got fresh URL');
        } else {
           debugPrint('VideoPlayer: Failed to refresh URL, trying fallback.');
           if (widget.item.streamUrl != null) url = widget.item.streamUrl!;
        }
      }
    } else if (widget.item.streamUrl != null) {
      // Normal fallback for other stream types (web?)
      url = widget.item.streamUrl!;
    }
    
    // Open paused to ensure seek happens before playback starts
    await _player.open(Media(url), play: false);

    // Wait for duration to be valid before seeking
    await _waitForDuration();

    // Restore position: Check ProfileProvider for authoritative state
    int startPos = widget.item.lastPositionSeconds;
    if (mounted) {
      final profileData = context.read<PlaybackProvider>().profileProvider.getDataFor(widget.item.id);
      if (profileData != null && profileData.positionSeconds > 0) {
        startPos = profileData.positionSeconds;
      }
    }

    if (startPos > 0) {
      debugPrint('VideoPlayer: Resuming at $startPos seconds for ${widget.item.id} (Duration: ${_player.state.duration.inSeconds}s)');
      await _player.seek(Duration(seconds: startPos));
    } else {
      debugPrint('VideoPlayer: Starting from beginning (pos: $startPos)');
    }

    await _player.play();

    // Listeners
    _player.stream.position.listen((pos) {
      if (_isDisposed) return;
      _checkSkipIntro(pos);
      _updateProgress(pos);
      _checkCompletion(pos);
    });

    _startHideTimer();
  }

  Future<void> _waitForDuration() async {
    if (_player.state.duration.inSeconds > 0) return;

    final completer = Completer<void>();
    final listener = _player.stream.duration.listen((duration) {
      if (duration.inSeconds > 0 && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      debugPrint('VideoPlayer: Timeout waiting for duration');
    } finally {
      listener.cancel();
    }
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
     final seconds = pos.inSeconds;
     // Save early so "continue watching" appears after only a few seconds
     if (seconds >= 3 && (seconds - _lastSavedPosition >= 5)) {
       _lastSavedPosition = seconds;
       context.read<PlaybackProvider>().updateProgress(widget.item, seconds);
     }
  }

  void _skipIntro() {
    if (widget.item.introEnd != null) {
      _player.seek(Duration(seconds: widget.item.introEnd! + 1));
      setState(() => _showSkipIntro = false);
    }
  }

  void _checkCompletion(Duration pos) {
    if (_hasMarkedWatched) return;

    final duration = _player.state.duration;
    if (duration.inSeconds > 0) {
      final progress = pos.inSeconds / duration.inSeconds;
      // Mark as watched if > 95% complete
      if (progress >= 0.95 && !widget.item.isWatched) {
         context.read<PlaybackProvider>().markWatched();
         _hasMarkedWatched = true;
         // _isDisposed check not needed as we are in listener
      }
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
    
    // Stop playback immediately to be safe
    _player.stop(); 

    try {
      // Save final progress
      final pos = _player.state.position.inSeconds;
      if (pos >= 3) {
        context.read<PlaybackProvider>().updateProgress(widget.item, pos);
      }
    } catch (e) {
      debugPrint('Error saving progress on dispose: $e');
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
              Video(
                controller: _controller, 
                fit: BoxFit.contain,
                controls: NoVideoControls, // Remove native controls (duplicate progress bar)
              ),

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
                  child: Stack( // Wrap in Stack to allow top-left positioning
                    fit: StackFit.expand,
                    children: [
                      // Back Button (Top Left)
                      Positioned(
                        top: 40,
                        left: 20,
                        child: IconButton(
                          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 32),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 24,
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                            hoverColor: Colors.white24,
                          ),
                        ),
                      ),
                      
                      // Bottom Controls
                      NetflixControls(
                        player: _player,
                        title: widget.item.title ?? "Unknown Title",
                        episodeTitle: widget.item.episode != null ? "Ep ${widget.item.episode}" : "",
                        onNextEpisode: () {
                           // Implement next episode logic here or emit event
                        },
                        onShowAudioSubs: _showAudioSubsModal,
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Skip Intro Button (keep outside opacity stack if it has independent logic, or move inside? 
              // Usually independent so it can persist or fade differently. Keeping as is.)
              if (_showSkipIntro && !_isObscured && _showControls)
                Positioned(
                  bottom: 120, // Move up to clear the larger control area
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
