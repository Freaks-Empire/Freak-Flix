import 'package:flutter/material.dart';

/// Demo item for UI scaffolding. Swap with MediaItem later.
class DemoItem {
  final String title;
  final String subtitle; // e.g. 'S1 • E8 – The Mask'
  final String imageUrl;
  final double progress; // 0.0 – 1.0
  final String timeLabel; // '45m'
  final String remainingLabel; // '93 remaining'
  final String daysLabel; // '2d'

  DemoItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.progress,
    required this.timeLabel,
    required this.remainingLabel,
    required this.daysLabel,
  });

  factory DemoItem.fake(int idx) {
    return DemoItem(
      title: [
        'Gotham',
        'Two and a Half Men',
        'House',
        'Dark',
        'Dune: Prophecy',
      ][idx % 5],
      subtitle: 'S1 • E${(idx % 10) + 1} – Episode ${(idx % 20) + 1}',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/6n8xUAoY5jz11sXkjtEtpFl5T1W.jpg',
      progress: 0.4 + (idx % 3) * 0.15,
      timeLabel: '45m',
      remainingLabel: '${60 + idx * 3} remaining',
      daysLabel: '${(idx % 4) + 1}d',
    );
  }
}

/// Clone-style home dashboard. Swap demo data with real library items later.
class FreakflixDashboard extends StatelessWidget {
  const FreakflixDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  children: const [
                    SizedBox(height: 4),
                    _Section(
                      title: 'Continue Watching',
                      showArrow: true,
                      fakeSeed: 0,
                    ),
                    SizedBox(height: 12),
                    _Section(
                      title: 'Start Watching',
                      showArrow: true,
                      fakeSeed: 10,
                    ),
                    SizedBox(height: 12),
                    _Section(
                      title: 'Upcoming Schedule',
                      showArrow: false,
                      fakeSeed: 20,
                    ),
                    SizedBox(height: 32),
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
  final int fakeSeed;

  const _Section({
    required this.title,
    required this.showArrow,
    required this.fakeSeed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = List.generate(10, (i) => DemoItem.fake(fakeSeed + i));

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
            itemBuilder: (context, index) => _ShowCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ShowCard extends StatelessWidget {
  final DemoItem item;

  const _ShowCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.more_vert,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.black.withOpacity(0.55),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stripText(item.timeLabel),
                        _stripText(item.remainingLabel),
                        _stripText(item.daysLabel),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: item.progress.clamp(0.0, 1.0),
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
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
