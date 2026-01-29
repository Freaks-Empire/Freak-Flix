/// lib/screens/details/episode_details_screen.dart
import 'package:flutter/material.dart';
import '../../models/tmdb_episode.dart';
import '../../models/media_item.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import '../../utils/logger.dart';

class EpisodeDetailsScreen extends StatelessWidget {
  final TmdbEpisode episode;
  final MediaItem? matchedFile;
  final String showTitle;
  final List<MediaItem>? playlist;

  const EpisodeDetailsScreen({
    super.key,
    required this.episode,
    required this.showTitle,
    this.matchedFile,
    this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background - Episode Still
          Positioned.fill(
            child: episode.stillPath != null
                ? SafeNetworkImage(url: episode.stillPath, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          
          // Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.9],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  
                  // Breadcrumb
                  Text(
                    '$showTitle • Season ${episode.seasonNumber} • Episode ${episode.episodeNumber}',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    episode.name,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Meta
                  Row(
                    children: [
                      if (episode.airDate != null)
                        _MetaTag(text: episode.airDate!, icon: Icons.calendar_today),
                      const SizedBox(width: 16),
                      _MetaTag(text: '${episode.voteAverage.toStringAsFixed(1)}', icon: Icons.star, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Overview
                  Text(
                    episode.overview,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Play Action
                  if (matchedFile != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                         AppLogger.userAction('Play button pressed', tag: 'EpisodeDetailsScreen', params: {'mediaId': matchedFile?.id ?? 'unknown'});
                         Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (_) => VideoPlayerScreen(
                               item: matchedFile!,
                               playlist: playlist ?? [],
                             ),
                           ),
                         );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play Episode'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Icon(Icons.error_outline, color: Colors.white54),
                           SizedBox(width: 12),
                           Text('File not found in library', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 24,
            left: 24,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _MetaTag({required this.text, required this.icon, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
