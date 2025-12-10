import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../providers/library_provider.dart';
import 'home_media_card.dart';

/// Clone-style home dashboard backed by the real library.
class FreakflixDashboard extends StatelessWidget {
  const FreakflixDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();

    // Real data sources
    final continueWatching = library.continueWatching;
    final recentlyAdded = library.recentlyAdded;
    final topRated = library.topRated;

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
              title: Row(
                children: [
                  Text(
                    'Library',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _ModePill(),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    _Section(
                      title: 'Continue Watching',
                      showArrow: true,
                      items: continueWatching,
                    ),
                    if (continueWatching.isNotEmpty) const SizedBox(height: 12),
                    _Section(
                      title: 'Recently Added',
                      showArrow: true,
                      items: recentlyAdded,
                    ),
                    if (recentlyAdded.isNotEmpty) const SizedBox(height: 12),
                    _Section(
                      title: 'Top Rated',
                      showArrow: true,
                      items: topRated,
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

class _ModePill extends StatelessWidget {
  const _ModePill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Media',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final bool showArrow;
  final List<MediaItem> items;

  const _Section({
    required this.title,
    required this.showArrow,
    required this.items,
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
            if (showArrow) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => HomeMediaCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}
