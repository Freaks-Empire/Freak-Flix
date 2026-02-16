import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/media_item.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/video_player/premium_controls.dart';
import '../../widgets/video_player/video_keyboard_listener.dart';
import '../../services/graph_auth_service.dart';
import '../../services/sftp_streaming_service.dart';
import '../../utils/url_validator.dart';
import '../utils/secure_logger.dart';
import '../utils/retry_handler.dart';
import '../utils/video_validator.dart';

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
  BoxFit _fit = BoxFit.contain;
  DateTime _lastUserInteraction = DateTime.now();

  // Listener cleanup
  StreamSubscription? _positionSubscription;
  
  // Memory management
  Timer? _memoryCleanupTimer;

  // Configuration
  static const Duration _defaultDurationTimeout = Duration(seconds: 10);
  static const Duration _minDurationTimeout = Duration(seconds: 3);
  static const Duration _maxDurationTimeout = Duration(seconds: 30);

  // SFTP Download State
  bool _isDownloadingSftp = false;
  double _sftpDownloadProgress = 0.0;
  String? _sftpError;

  @override
  void initState() {
    super.initState();
    // Default NSFW curtain if adult
    _isObscured = false; // widget.item.isAdult;
    
    // Hide cursor & Enter fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // On Desktop, windows management is usually separate, ensuring we just hide UI here

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Determine URL. 
    String url = widget.item.filePath;
    
    // SECURITY: Validate URL before processing
    final urlValidation = UrlValidator.validateUrl(url);
    if (!urlValidation.isValid) {
      SecureLogger.error('URL validation failed', urlValidation.message, 'VideoPlayer');
      if (mounted) {
        setState(() {
          _sftpError = 'Security Error: ${urlValidation.message}';
        });
      }
      return;
    }

    // Validate video file format
    final videoValidation = SimpleVideoValidator.validateVideo(url);
    if (!videoValidation['is_supported'] as bool) {
      SecureLogger.warning('Unsupported video format', 'VideoPlayer');
      if (mounted) {
        setState(() {
          _sftpError = 'Unsupported video format: ${videoValidation['file_extension']}';
        });
      }
      return;
    }
    
    // Check if this is an SFTP file
    final sftpParsed = SftpStreamingService.parseSftpPath(widget.item.filePath);
    if (sftpParsed != null) {
      final (accountId, remotePath) = sftpParsed;
      debugPrint('VideoPlayer: Detected SFTP file - Account: $accountId, Path: $remotePath');
      
      if (!mounted) return; // Prevent race condition
      
      setState(() {
        _isDownloadingSftp = true;
        _sftpDownloadProgress = 0.0;
        _sftpError = null;
      });
      
      // Store progress callback with dispose check
      late final ProgressCallback progressCallback;
      progressCallback = (progress) {
        if (mounted && !_isDisposed) {
          setState(() => _sftpDownloadProgress = progress);
        }
      };
      
      final localPath = await SftpStreamingService.instance.getPlayablePath(
        accountId: accountId,
        remotePath: remotePath,
        onProgress: progressCallback,
      );
      
      if (localPath == null) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isDownloadingSftp = false;
            _sftpError = 'Failed to download file from SFTP server';
          });
        }
        return;
      }
      
      url = localPath;
      if (mounted && !_isDisposed) {
        setState(() => _isDownloadingSftp = false);
      }
      debugPrint('VideoPlayer: Using downloaded SFTP file: $url');
    }
    // If it's a OneDrive item, we MUST refresh the download URL because it expires.
    else if (widget.item.id.startsWith('onedrive_')) {
      final parts = widget.item.id.split('_');
      if (parts.length >= 3) {
        // Format: onedrive_{accountId}_{itemId}
        final accountId = parts[1]; 
        final itemId = parts.sublist(2).join('_'); // Join back just in case itemId has underscores
        
        debugPrint('VideoPlayer: Refreshing OneDrive URL for $itemId (Account: $accountId)...');
        final urlResult = await RetryHandler.executeWithRetry<String?>(
          () async => GraphAuthService().getDownloadUrl(accountId, itemId),
          RetryHandler.forNetworkOperations(maxAttempts: 3),
          operationName: 'OneDrive URL refresh',
        );
        
        if (urlResult.success && urlResult.result != null) {
          url = urlResult.result!;
          SecureLogger.debug('Got fresh URL from OneDrive', 'VideoPlayer');
        } else {
          SecureLogger.warning('Failed to refresh OneDrive URL, using fallback', 'VideoPlayer');
          if (widget.item.streamUrl != null) {
            url = widget.item.streamUrl!;
          } else {
            // No valid URL available - show error
            SecureLogger.error('No valid URL for OneDrive item', 'VideoPlayer');
            if (mounted) {
              setState(() {
                _sftpError = 'Unable to play: Could not get OneDrive URL. Please check your connection.';
              });
            }
            return;
          }
        }
      }
    } else if (widget.item.streamUrl != null) {
      // Normal fallback for other stream types (web?)
      url = widget.item.streamUrl!;
      
      // SECURITY: Validate stream URL as well
      final streamValidation = UrlValidator.validateUrl(url);
      if (!streamValidation.isValid) {
        SecureLogger.error('Stream URL validation failed', streamValidation.message, 'VideoPlayer');
        if (mounted) {
          setState(() {
            _sftpError = 'Security Error: Invalid stream URL';
          });
        }
        return;
      }
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

    // Listeners - store subscription for cleanup
    _positionSubscription = _player.stream.position.listen((pos) {
      if (_isDisposed) return;
      _checkSkipIntro(pos);
      _updateProgress(pos);
      _checkCompletion(pos);
    });

    _startHideTimer();
  }

  Future<void> _waitForDuration({Duration? customTimeout}) async {
    if (_player.state.duration.inSeconds > 0) return;

    final timeout = customTimeout ?? _defaultDurationTimeout;
    final completer = Completer<void>();
    late final StreamSubscription listener;

    // Calculate adaptive timeout (conservative approach)
    Duration adaptiveTimeout = timeout;
    // Network conditions may require more time for some formats
    adaptiveTimeout = Duration(
      milliseconds: _calculateAdaptiveTimeout(timeout.inMilliseconds),
    );

    listener = _player.stream.duration.listen((duration) {
      if (duration.inSeconds > 0 && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future.timeout(adaptiveTimeout);
      SecureLogger.debug('Duration loaded successfully', 'VideoPlayer');
    } catch (e) {
      SecureLogger.error('Timeout waiting for duration', e, 'VideoPlayer');
      // Continue anyway - some formats don't report duration immediately
    } finally {
      listener.cancel();
    }
  }

  /// Calculate adaptive timeout based on reasonable limits
  int _calculateAdaptiveTimeout(int baseTimeoutMs) {
    final minMs = _minDurationTimeout.inMilliseconds;
    final maxMs = _maxDurationTimeout.inMilliseconds;
    
    // Simple adaptive logic: allow up to 2x base timeout, within bounds
    final adaptiveMs = (baseTimeoutMs * 2).clamp(minMs, maxMs);
    return adaptiveMs;
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
    _lastUserInteraction = DateTime.now();
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      // Only hide controls if no recent user interaction
      final timeSinceInteraction = DateTime.now().difference(_lastUserInteraction);
      if (mounted && timeSinceInteraction.inSeconds >= 4) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onPanUpdate() {
    // Reset timer on user interaction
    _lastUserInteraction = DateTime.now();
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
    _memoryCleanupTimer?.cancel();
    
    // CRITICAL: Cancel subscriptions to prevent memory leaks
    _positionSubscription?.cancel();
    
    // Stop playback immediately to be safe
    _player.stop(); 

    try {
      // Save final progress
      final pos = _player.state.position.inSeconds;
      if (pos >= 3) {
        context.read<PlaybackProvider>().updateProgress(widget.item, pos);
      }
    } catch (e) {
      SecureLogger.error('Error saving progress on dispose', e, 'VideoPlayer');
    }

    _player.dispose();
    super.dispose();
  }

  /// Monitor memory usage during playback
  void _startMemoryMonitoring() {
    _memoryCleanupTimer?.cancel();
    
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isDisposed || !mounted) return;
      
      // Check memory usage and optimize if needed
      _checkMemoryUsage();
    });
  }

  /// Check memory usage and perform optimizations
  void _checkMemoryUsage() {
    // TODO: Implement actual memory monitoring
    // For now, just log memory state periodically
    SecureLogger.debug('Memory monitoring active', 'VideoPlayer');
  }

  void _toggleFullscreen() {
    // Basic implementation for now, or just rely on OS window controls
  }

  void _cycleFit() {
    setState(() {
      if (_fit == BoxFit.contain) _fit = BoxFit.cover;
      else if (_fit == BoxFit.cover) _fit = BoxFit.fill;
      else _fit = BoxFit.contain;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VideoKeyboardListener(
      player: _player,
      onToggleFullscreen: _toggleFullscreen,
      onBack: () => Navigator.of(context).pop(),
      child: Scaffold(
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
                // 0. SFTP Download Progress Overlay
                if (_isDownloadingSftp)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.download, color: Colors.white, size: 48),
                          const SizedBox(height: 24),
                          const Text(
                            'Preparing video...',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              value: _sftpDownloadProgress,
                              backgroundColor: Colors.white24,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_sftpDownloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // 0b. SFTP Error Overlay
                if (_sftpError != null)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 24),
                          Text(
                            _sftpError!,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(LucideIcons.arrowLeft),
                            label: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 1. Video Layer
                Video(
                  controller: _controller, 
                  fit: _fit,
                  controls: NoVideoControls, // Remove native controls
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
                    child: PremiumVideoControls(
                      player: _player,
                      title: widget.item.title ?? "Unknown Title",
                      episodeTitle: widget.item.episode != null ? "Ep ${widget.item.episode}" : "",
                      onNextEpisode: () {
                         // Implement next episode logic here or emit event
                      },
                      onShowAudioSubs: _showAudioSubsModal,
                      onBack: () => Navigator.of(context).pop(),
                      onCycleFit: _cycleFit,
                    ),
                  ),
                ),

                // 4. Skip Intro Button
                if (_showSkipIntro && !_isObscured && _showControls)
                  Positioned(
                    bottom: 120, // Clear the larger premium control area
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
      ),
    );
  }

  void _showAudioSubsModal() {
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
