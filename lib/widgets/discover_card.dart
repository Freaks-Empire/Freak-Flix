import 'package:flutter/material.dart';
import '../models/tmdb_item.dart';

class DiscoverCard extends StatelessWidget {
  final TmdbItem item;
  const DiscoverCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterUrl != null)
                    Image.network(
                      item.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PosterFallback(type: item.type),
                    )
                  else
                    _PosterFallback(type: item.type),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.36),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_horiz, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                          ],
                        ),
                      ),
                      child: _MetaRow(item: item),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final TmdbMediaType type;
  const _PosterFallback({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          type == TmdbMediaType.tv ? Icons.tv : Icons.movie,
          color: theme.colorScheme.onSurfaceVariant,
          size: 32,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final TmdbItem item;
  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watchers = item.popularity?.round();
    final rating = item.voteAverage != null ? (item.voteAverage! / 2).toStringAsFixed(1) : null;
    final year = item.releaseYear;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MetaChip(
          icon: Icons.visibility_outlined,
          label: watchers != null ? '${_formatCompact(watchers)}' : '--',
        ),
        _MetaChip(
          icon: Icons.star,
          label: rating ?? '--',
        ),
        _MetaChip(
          icon: Icons.calendar_today,
          label: year != null ? '$year' : '--',
        ),
      ],
    );
  }

  String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
