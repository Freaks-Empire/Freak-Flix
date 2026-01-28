/// lib/services/vidking_service.dart
/// Service for generating Vidking Player embed URLs for remote streaming.

/// Configuration options for Vidking Player embeds.
class VidkingConfig {
  /// Primary accent color (hex without #)
  final String? primaryColor;
  
  /// Secondary color (hex without #)
  final String? secondaryColor;
  
  /// Auto-start playback
  final bool autoplay;
  
  /// Start muted (required for browser autoplay)
  final bool muted;
  
  /// Show episode selector for TV shows
  final bool showEpisodeSelector;
  
  /// Show next episode button
  final bool showNextButton;
  
  /// Enable keyboard controls
  final bool keyboardControls;

  const VidkingConfig({
    this.primaryColor,
    this.secondaryColor,
    this.autoplay = true,
    this.muted = true, // Required for browser autoplay
    this.showEpisodeSelector = true,
    this.showNextButton = true,
    this.keyboardControls = true,
  });

  /// Convert config to URL query parameters
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (primaryColor != null) params['color'] = primaryColor!;
    if (secondaryColor != null) params['secondary'] = secondaryColor!;
    if (autoplay) params['autoplay'] = '1';
    if (muted) params['muted'] = '1';
    if (showEpisodeSelector) params['episodes'] = '1';
    if (showNextButton) params['next'] = '1';
    if (keyboardControls) params['keyboard'] = '1';
    return params;
  }
}

/// Service to generate Vidking Player embed URLs.
class VidkingService {
  static const String baseUrl = 'https://www.vidking.net';
  
  /// Default config with Freak-Flix accent colors
  static const VidkingConfig defaultConfig = VidkingConfig(
    primaryColor: 'E50914', // Netflix-style red
    autoplay: true,
    showEpisodeSelector: true,
    showNextButton: true,
    keyboardControls: true,
  );
  
  /// Generate embed URL for a movie.
  /// 
  /// [tmdbId] - The Movie Database ID for the movie.
  /// [config] - Optional player configuration.
  static String getMovieEmbedUrl(int tmdbId, {VidkingConfig? config}) {
    final cfg = config ?? defaultConfig;
    final queryParams = cfg.toQueryParams();
    final queryString = queryParams.isNotEmpty 
        ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    return '$baseUrl/embed/movie/$tmdbId$queryString';
  }
  
  /// Generate embed URL for a TV episode.
  /// 
  /// [tmdbId] - The Movie Database ID for the TV show.
  /// [season] - Season number (1-indexed).
  /// [episode] - Episode number (1-indexed).
  /// [config] - Optional player configuration.
  static String getTvEmbedUrl(
    int tmdbId, 
    int season, 
    int episode, 
    {VidkingConfig? config}
  ) {
    final cfg = config ?? defaultConfig;
    final queryParams = cfg.toQueryParams();
    final queryString = queryParams.isNotEmpty 
        ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    return '$baseUrl/embed/tv/$tmdbId/$season/$episode$queryString';
  }
  
  /// Check if a TMDB ID is likely available on Vidking.
  /// 
  /// Note: This is a best-effort check. Actual availability
  /// depends on Vidking's content library.
  static bool isContentLikelyAvailable(int? tmdbId) {
    // Vidking requires a valid TMDB ID
    return tmdbId != null && tmdbId > 0;
  }
}
