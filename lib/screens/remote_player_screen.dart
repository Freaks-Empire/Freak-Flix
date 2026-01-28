/// lib/screens/remote_player_screen.dart
/// Remote streaming player using Vidking embed with pre-roll ads.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/media_item.dart';
import '../services/ad_service.dart';
import '../services/vidking_service.dart';

/// Screen for playing remote content via Vidking with pre-roll ads.
/// 
/// On platforms where Google IMA is not supported (Windows), ads are skipped.
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
  // State
  bool _showingAd = true;
  bool _webViewReady = false;
  String? _errorMessage;
  
  // Controllers
  WebViewController? _webViewController;
  
  // Services
  final AdService _adService = AdService.instance;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  void _initializePlayer() {
    if (_adService.shouldShowAd()) {
      // Show ad placeholder, then load content
      // For now, we skip the ad (IMA requires more complex integration)
      // TODO: Add proper IMA integration in future version
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _skipToContent();
      });
    } else {
      // No ads on this platform (Windows), go straight to content
      _showingAd = false;
      _initWebView();
    }
  }
  
  void _skipToContent() {
    if (mounted) {
      setState(() {
        _showingAd = false;
      });
      _initWebView();
    }
  }
  
  void _initWebView() {
    final embedUrl = _getEmbedUrl();
    if (embedUrl == null) {
      setState(() {
        _errorMessage = 'Cannot stream: Missing TMDB ID';
      });
      return;
    }
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _webViewReady = true);
        },
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse(embedUrl));
      
    if (mounted) setState(() {});
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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content area
          if (_errorMessage != null)
            _buildErrorView()
          else if (_showingAd && _adService.shouldShowAd())
            _buildAdPlaceholder()
          else if (_webViewController != null)
            _buildWebView()
          else
            _buildLoadingView(),
          
          // Back button overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdPlaceholder() {
    // Placeholder for future IMA integration
    // Shows a loading screen that simulates ad loading
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (!_webViewReady)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
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
