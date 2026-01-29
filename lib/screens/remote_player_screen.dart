/// lib/screens/remote_player_screen.dart
/// Remote streaming player using Vidking embed.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/vidking_service.dart';

// Conditional imports for web vs native
import 'remote_player_stub.dart'
    if (dart.library.html) 'remote_player_web.dart'
    if (dart.library.io) 'remote_player_native.dart' as platform;

/// Screen for playing remote content via Vidking embed.
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

  @override
  void initState() {
    super.initState();
    _embedUrl = _getEmbedUrl();
    if (_embedUrl == null) {
      _errorMessage = 'Cannot stream: Missing TMDB ID';
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
            
            // Main content area - the embed player
            Expanded(
              child: _errorMessage != null
                  ? _buildErrorView()
                  : _embedUrl != null
                      ? platform.buildEmbedPlayer(_embedUrl!)
                      : _buildLoadingView(),
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
