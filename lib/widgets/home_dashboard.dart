import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/library_provider.dart';
import 'segmented_pill_bar.dart';

/// Clone-style home dashboard backed by the real library.
class FreakflixDashboard extends StatelessWidget {
  const FreakflixDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final continueWatching = library.continueWatching;
    final startWatching = [...library.items
        .where((i) => i.type == MediaType.tv && !i.isWatched && i.lastPositionSeconds == 0)]
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    final upcoming = [...library.tv]
      ..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              toolbarHeight: 52,
              backgroundColor: theme.colorScheme.background,
              titleSpacing: 16,
              title: const _TopBar(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    HomeSectionRow(
                      title: 'Continue Watching',
                      items: continueWatching,
                      cardBuilder: (item) => ContinueWatchingCard(item: item),
                    ),
                    const SizedBox(height: 16),
                    HomeSectionRow(
                      title: 'Start Watching',
                      items: startWatching.isNotEmpty
                          ? startWatching.take(15).toList()
                          : library.recentlyAdded,
                      cardBuilder: (item) => PosterCard(item: item),
                    ),
                    const SizedBox(height: 16),
                    HomeSectionRow(
                      title: 'Upcoming Schedule',
                      items: upcoming.take(12).toList(),
                      cardBuilder: (item) => UpcomingCard(item: item),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  int _segIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Library',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedPillBar(
            items: const [
              SegmentedPillItem('Media', Icons.widgets_outlined),
              SegmentedPillItem('Shows', Icons.tv_outlined),
              SegmentedPillItem('Movies', Icons.movie_outlined),
            ],
            selectedIndex: _segIndex,
            onChanged: (i) {
              setState(() => _segIndex = i);
              // TODO: hook into filtering logic when ready
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          onPressed: () {},
        ),
      ],
    );
  }
}

class HomeSectionRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final Widget Function(MediaItem item) cardBuilder;

  const HomeSectionRow({
    required this.title,
    required this.items,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => cardBuilder(items[index]),
          ),
        ),
      ],
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  final MediaItem item;
  const ContinueWatchingCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSeconds = item.totalDurationSeconds ??
      (item.runtimeMinutes != null ? item.runtimeMinutes! * 60 : null);
    final elapsed = item.lastPositionSeconds;
    final int? remaining = totalSeconds != null
      ? ((totalSeconds - elapsed).clamp(0, totalSeconds)).toInt()
      : null;
    final progress = totalSeconds != null && totalSeconds > 0
        ? (elapsed / totalSeconds).clamp(0, 1)
        : 0.0;

    String _formatMins(int seconds) {
      final minutes = (seconds / 60).round();
      return '${minutes}m';
    }

    final sinceAdded = DateTime.now().difference(item.lastModified).inDays;
    final sinceLabel = sinceAdded <= 0 ? 'Today' : '${sinceAdded}d';

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.backdropUrl != null)
                    Image.network(item.backdropUrl!, fit: BoxFit.cover)
                  else if (item.posterUrl != null)
                    Image.network(item.posterUrl!, fit: BoxFit.cover)
                  else
                    Container(color: theme.colorScheme.surfaceVariant),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.more_horiz, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatMins(elapsed),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(remaining != null ? _formatMins(remaining) : '--',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(sinceLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title ?? item.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (item.season != null || item.episode != null)
            Text(
              'S${item.season ?? 1} · E${item.episode ?? 1}',
              style: theme.textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class PosterCard extends StatelessWidget {
  final MediaItem item;
  const PosterCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
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
                    Image.network(item.posterUrl!, fit: BoxFit.cover)
                  else
                    Container(color: theme.colorScheme.surfaceVariant),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.more_horiz, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title ?? item.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            item.year != null ? '${item.year}' : '',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class UpcomingCard extends StatelessWidget {
  final MediaItem item;
  const UpcomingCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysSince = DateTime.now().difference(item.lastModified).inDays;
    final chip = daysSince <= 0
        ? 'Today'
        : daysSince <= 3
            ? 'In ${3 - daysSince} days'
            : 'Soon';

    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.backdropUrl != null)
                    Image.network(item.backdropUrl!, fit: BoxFit.cover)
                  else if (item.posterUrl != null)
                    Image.network(item.posterUrl!, fit: BoxFit.cover)
                  else
                    Container(color: theme.colorScheme.surfaceVariant),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        chip,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.more_horiz, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title ?? item.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            item.year != null ? '${item.year}' : '',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
