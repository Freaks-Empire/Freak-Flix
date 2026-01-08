/// lib/widgets/home_media_card.dart
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../screens/details_screen.dart';
import 'package:go_router/go_router.dart';
import 'safe_network_image.dart';

class HomeMediaCard extends StatelessWidget {
  final MediaItem item;
  final bool hideEpisodeInfo;

  const HomeMediaCard({
    super.key,
    required this.item,
    this.hideEpisodeInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watchedSeconds = item.lastPositionSeconds;
    final totalSeconds = item.totalDurationSeconds ??
        (item.runtimeMinutes != null ? item.runtimeMinutes! * 60 : 0);
    final progress = _progressValue(watchedSeconds, totalSeconds);

    final watchedLabel = watchedSeconds > 0
        ? _formatDurationShort(Duration(seconds: watchedSeconds))
        : (totalSeconds > 0 ? 'Ready' : 'New');
    final remainingLabel = totalSeconds > 0
        ? '${_formatDurationShort(Duration(seconds: totalSeconds - watchedSeconds).abs())} left'
        : '';
    final subtitle = _buildSubtitle(item, hideEpisodeInfo);

    return GestureDetector(
      onTap: () {
         if (item.isAnime && item.anilistId != null) {
            final slug = _slugify(item.title ?? 'anime');
            context.push('/anime/${item.anilistId}/$slug', extra: item);
         } else if (item.id.startsWith('stashdb:')) {
            final rawId = item.id.replaceFirst('stashdb:', '');
            context.push('/scene/$rawId', extra: item);
         } else {
            context.push('/media/${item.id}', extra: item);
         }
      },
      child: SizedBox(
        width: 200, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: SafeNetworkImage(
                      url: item.posterUrl,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  
                  // Top-Left Badges (Adult / Stash)
                  if (item.isAdult || item.id.startsWith('stashdb:'))
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Wrap(
                        spacing: 4,
                        children: [
                          if (item.isAdult)
                            _buildBadge('Adult', theme.colorScheme.error, context),
                          if (item.id.startsWith('stashdb:'))
                            _buildBadge('Stash', theme.colorScheme.primary, context),
                        ],
                      ),
                    ),

                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.more_vert, size: 16),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      color: Colors.black.withOpacity(0.55),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _pillText(watchedLabel),
                          if (remainingLabel.isNotEmpty)
                            _pillText(remainingLabel),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title ?? item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  static double _progressValue(int watchedSeconds, int totalSeconds) {
    if (totalSeconds <= 0) return 0;
    final ratio = watchedSeconds / totalSeconds;
    if (ratio.isNaN) return 0;
    return ratio.clamp(0.0, 1.0);
  }

  static String _formatDurationShort(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h';
    final minutes = d.inMinutes;
    if (minutes <= 0) return '<1m';
    return '${minutes}m';
  }

  static String _buildSubtitle(MediaItem item, bool hideEpisodeInfo) {
    if (hideEpisodeInfo) {
       return item.year != null ? '${item.year}' : '';
    }

    final season = item.season;
    final episode = item.episode;
    if (season != null && episode != null) {
      return 'S${season} • E${episode}';
    }
    if (item.year != null) return '${item.year}';
    return 'Episode';
  }

  Widget _pillText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // remove non-alphanumeric (keep spaces)
        .trim()
        .replaceAll(RegExp(r'\s+'), '-'); // replace spaces with dashes
  }
}
