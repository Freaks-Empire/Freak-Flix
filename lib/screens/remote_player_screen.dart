/// lib/screens/remote_player_screen.dart
/// Remote streaming player using Vidking embed with pre-roll ads.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/vidking_service.dart';

// Conditional imports for web vs native
import 'remote_player_stub.dart'
    if (dart.library.html) 'remote_player_web.dart'
    if (dart.library.io) 'remote_player_native.dart' as platform;

/// Screen for playing remote content via Vidking embed with pre-roll ads.
class RemotePlayerScreen extends StatefulWidget {
  /// The media item to play.
  final MediaItem item;
  
  /// Season number for TV content (optional).
  final int? season;
  
  /// Episode number for TV content (optional).
  final int? episode;

  const RemotePlayerScreen({
    super.key,
    required this.item,
    this.season,
    this.episode,
  });

  @override
  State<RemotePlayerScreen> createState() => _RemotePlayerScreenState();
}

class _RemotePlayerScreenState extends State<RemotePlayerScreen> {
  String? _errorMessage;
  String? _embedUrl;
  
  // Ad states
  bool _showingAd = true;
  bool _adFinished = false;
  int _adCountdown = 5; // 5 second countdown for test ad simulation

  @override
  void initState() {
    super.initState();
    _embedUrl = _getEmbedUrl();
    if (_embedUrl == null) {
      _errorMessage = 'Cannot stream: Missing TMDB ID';
      _showingAd = false;
    } else {
      _startAdSimulation();
    }
  }
  
  /// Simulates a pre-roll ad with countdown
  /// In production, replace with actual IMA ad loading
  void _startAdSimulation() {
    Future.delayed(const Duration(seconds: 1), _countdown);
  }
  
  void _countdown() {
    if (!mounted) return;
    if (_adCountdown > 0) {
      setState(() => _adCountdown--);
      Future.delayed(const Duration(seconds: 1), _countdown);
    } else {
      _skipToContent();
    }
  }
  
  void _skipToContent() {
    if (mounted) {
      setState(() {
        _showingAd = false;
        _adFinished = true;
      });
    }
  }
  
  String? _getEmbedUrl() {
    final tmdbId = widget.item.tmdbId;
    if (tmdbId == null) return null;
    
    if (widget.item.type == MediaType.movie) {
      return VidkingService.getMovieEmbedUrl(tmdbId);
    } else {
      // TV content
      final season = widget.season ?? widget.item.season ?? 1;
      final episode = widget.episode ?? widget.item.episode ?? 1;
      return VidkingService.getTvEmbedUrl(tmdbId, season, episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.title ?? 'Streaming',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content area
            Expanded(
              child: _errorMessage != null
                  ? _buildErrorView()
                  : _showingAd
                      ? _buildAdView()
                      : _embedUrl != null
                          ? platform.buildEmbedPlayer(_embedUrl!)
                          : _buildLoadingView(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ad label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Ad placeholder
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Video Ad',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '(Test Ad - Replace with IMA)',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Countdown
            Text(
              'Content starts in $_adCountdown...',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Skip button (appears after 2 seconds)
            if (_adCountdown <= 3)
              TextButton.icon(
                onPressed: _skipToContent,
                icon: const Icon(Icons.skip_next, color: Colors.white),
                label: const Text('Skip Ad', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
