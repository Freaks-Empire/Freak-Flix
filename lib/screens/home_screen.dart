import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:freak_flix/models/media_item.dart';
import '../providers/library_provider.dart';
import '../widgets/home_media_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    if (library.isLoading && library.items.isEmpty) {
      return const LoadingIndicator(message: 'Scanning library...');
    }
    if (library.items.isEmpty) {
      return const EmptyState(
          message: 'No media yet. Go to Settings to scan a folder.');
    }

    final sections = <_HomeSectionData>[
      _HomeSectionData(
        title: 'Continue Watching',
        showArrow: true,
        items: library.continueWatching,
      ),
      _HomeSectionData(
        title: 'Start Watching',
        showArrow: true,
        items: library.recentlyAdded.isNotEmpty
            ? library.recentlyAdded
            : library.items,
      ),
      _HomeSectionData(
        title: 'Upcoming Schedule',
        showArrow: false,
        items: library.tv,
      ),
    ].where((s) => s.items.isNotEmpty).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: theme.colorScheme.background,
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                Text(
                  'Freak Flix',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const _ModeToggle(),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  for (final section in sections)
                    _HomeSection(
                      title: section.title,
                      showArrow: section.showArrow,
                      items: section.items,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionData {
  final String title;
  final bool showArrow;
  final List<MediaItem> items;
  const _HomeSectionData({
    required this.title,
    required this.showArrow,
    required this.items,
  });
}

class _HomeSection extends StatelessWidget {
  final String title;
  final bool showArrow;
  final List<MediaItem> items;
  const _HomeSection({
    required this.title,
    required this.showArrow,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
              padding: const EdgeInsets.only(right: 16),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return HomeMediaCard(item: items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.movie_outlined,
              size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            'Media',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
