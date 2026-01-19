/// lib/screens/adult_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/library_provider.dart';
import '../models/media_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/safe_network_image.dart';

class AdultScreen extends StatefulWidget {
  const AdultScreen({super.key});

  @override
  State<AdultScreen> createState() => _AdultScreenState();
}

class _AdultScreenState extends State<AdultScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Recently Added', 'Favorites', 'Movies', 'Scenes'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final allItems = library.adult;

    if (allItems.isEmpty) {
      return const EmptyState(message: 'No adult content found.');
    }

    // Filter items based on active filter
    List<MediaItem> filteredItems = allItems;
    switch (_activeFilter) {
      case 'Movies':
        filteredItems = allItems.where((i) => i.type == MediaType.movie).toList();
        break;
      case 'Scenes':
        filteredItems = allItems.where((i) => i.type == MediaType.scene).toList();
        break;
      case 'Favorites':
        filteredItems = allItems.where((i) => i.isWatched).toList();
        break;
      case 'Recently Added':
        filteredItems = List.from(allItems)..sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      default:
        filteredItems = allItems;
    }

    // Featured item (random for variety)
    final featuredItem = allItems.isNotEmpty 
        ? allItems[Random().nextInt(allItems.length)] 
        : null;

    // Recently watched (from history, filter adult only)
    final recentlyWatched = library.historyItems
        .where((i) => i.isAdult)
        .take(10)
        .toList();

    // Recommended (items with same tags/performers as recently watched)
    final recommendedItems = _getRecommended(allItems, recentlyWatched);

    // New additions (sorted by date)
    final newAdditions = List<MediaItem>.from(allItems)
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Spacer for floating dock
          const SliverToBoxAdapter(child: SizedBox(height: 80)),

          // HERO BANNER
          if (featuredItem != null)
            SliverToBoxAdapter(child: _HeroBanner(item: featuredItem)),

          // FILTER CHIPS
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              margin: const EdgeInsets.only(top: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final isActive = _filters[i] == _activeFilter;
                  return ChoiceChip(
                    label: Text(_filters[i]),
                    selected: isActive,
                    onSelected: (_) => setState(() => _activeFilter = _filters[i]),
                    selectedColor: const Color(0xFFD32F2F),
                    backgroundColor: theme.colorScheme.surface,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),
          ),

          // RECENTLY WATCHED SECTION
          if (recentlyWatched.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContentSection(
                title: 'Recently Watched',
                icon: Icons.history,
                items: recentlyWatched,
              ),
            ),

          // RECOMMENDED SECTION
          if (recommendedItems.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContentSection(
                title: 'Recommended For You',
                icon: Icons.thumb_up_alt_outlined,
                items: recommendedItems,
              ),
            ),

          // NEW ADDITIONS SECTION
          if (newAdditions.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContentSection(
                title: 'New Additions',
                icon: Icons.new_releases_outlined,
                items: newAdditions.take(15).toList(),
              ),
            ),

          // MAIN GRID HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _activeFilter == 'All' ? 'All Content' : _activeFilter,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredItems.length} items',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // MAIN GRID
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                childAspectRatio: 16 / 9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SceneCard(item: filteredItems[index]),
                childCount: filteredItems.length,
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<MediaItem> _getRecommended(List<MediaItem> all, List<MediaItem> history) {
    if (history.isEmpty) return [];

    // Collect tags and performers from history
    final historyTags = <String>{};
    final historyPerformers = <String>{};
    for (final item in history) {
      historyTags.addAll(item.genres);
      historyPerformers.addAll(item.cast.map((c) => c.id));
    }

    // Score items by overlap
    final scored = <MapEntry<MediaItem, int>>[];
    for (final item in all) {
      if (history.any((h) => h.id == item.id)) continue;
      int score = 0;
      score += item.genres.where((g) => historyTags.contains(g)).length;
      score += item.cast.where((c) => historyPerformers.contains(c.id)).length * 2;
      if (score > 0) scored.add(MapEntry(item, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(15).map((e) => e.key).toList();
  }
}

// --- Hero Banner Widget ---
class _HeroBanner extends StatelessWidget {
  final MediaItem item;
  const _HeroBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.backdropUrl ?? item.posterUrl;

    return GestureDetector(
      onTap: () => context.push('/media/${item.id}', extra: item),
      child: Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (imageUrl != null)
              SafeNetworkImage(url: imageUrl, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[850]),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title ?? item.fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.year != null || item.runtimeMinutes != null)
                    Text(
                      [
                        if (item.year != null) item.year.toString(),
                        if (item.runtimeMinutes != null) '${item.runtimeMinutes}m',
                      ].join(' • '),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/media/${item.id}', extra: item),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Content Section Widget ---
class _ContentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MediaItem> items;

  const _ContentSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFFD32F2F)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) => _SectionCard(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Section Card (Horizontal Row) ---
class _SectionCard extends StatelessWidget {
  final MediaItem item;
  const _SectionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.backdropUrl ?? item.posterUrl;

    return GestureDetector(
      onTap: () => context.push('/media/${item.id}', extra: item),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              SafeNetworkImage(url: imageUrl, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[850],
                child: const Center(child: Icon(Icons.movie, color: Colors.white24, size: 40)),
              ),
            // Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            // Title
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                item.title ?? item.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Play Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Scene Card (Grid) ---
class _SceneCard extends StatelessWidget {
  final MediaItem item;
  const _SceneCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.backdropUrl ?? item.posterUrl;

    return GestureDetector(
      onTap: () => context.push('/media/${item.id}', extra: item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null)
              SafeNetworkImage(url: imageUrl, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey[850],
                child: const Center(child: Icon(Icons.movie, color: Colors.white24, size: 40)),
              ),

            // Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),

            // Title and Meta
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title ?? item.fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.year != null) item.year.toString(),
                      if (item.runtimeMinutes != null) '${item.runtimeMinutes}m',
                    ].join(' • '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Play Button Overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),

            // Type Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.type == MediaType.movie 
                      ? const Color(0xFFD32F2F) 
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.type == MediaType.movie ? 'MOVIE' : 'SCENE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
