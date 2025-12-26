import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart'; // Ensure player is imported if we use it later
import '../models/media_item.dart';
import 'safe_network_image.dart';

class HeroFeaturedCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onMoreInfo;

  const HeroFeaturedCard({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onMoreInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.65, // Occupy top ~65% of screen
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (item.backdropUrl != null)
            SafeNetworkImage(
              url: item.backdropUrl,
              fit: BoxFit.cover,
            )
          else if (item.posterUrl != null) 
            SafeNetworkImage(
               url: item.posterUrl,
               fit: BoxFit.cover,
            )
          else
            Container(color: Colors.black26),

          // Gradient Overlay (Darken bottom/left for text readability)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black54,
                  Colors.black,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          
          // Horizontal Gradient (Left to Right) for text background
          const DecoratedBox(
             decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                 colors: [
                  Colors.black87,
                  Colors.transparent,
                ],
                stops: [0.0, 0.5],
              )
             )
          ),

          // Content
          Positioned(
            bottom: 48,
            left: 48,
            right: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Genre Chips (Mock logic or use genres list)
                if (item.genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: item.genres.take(3).map((g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        g,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )).toList(),
                  ),
                const SizedBox(height: 16),

                // Title
                Text(
                  item.title ?? item.fileName,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                SizedBox(
                  width: size.width * 0.5,
                  child: Text(
                    item.overview ?? 'No description available.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Meta Row
                Row(
                  children: [
                     if (item.rating != null) ...[
                        const Icon(Icons.star, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 4),
                        Text('${item.rating}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                     ],
                     Text(
                       item.year != null ? '${item.year}' : '',
                        style: const TextStyle(color: Colors.white70),
                     ),
                     if (item.runtimeMinutes != null) ...[
                        const SizedBox(width: 16), 
                        Text(
                          '${item.runtimeMinutes}m',
                          style: const TextStyle(color: Colors.white70),
                        ),
                     ],
                  ],
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.pinkAccent, // Brand color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                      onPressed: onMoreInfo,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('More Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
