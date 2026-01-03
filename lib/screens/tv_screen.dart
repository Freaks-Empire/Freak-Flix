import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';
import '../widgets/pagination_controls.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  int _page = 0;

  int _calculateItemsPerPage(BoxConstraints constraints) {
    // Similar logic to MoviesScreen / MediaGrid
    final double gridWidth = constraints.maxWidth - 24; 
    const double maxCrossAxisExtent = 150;
    const double childAspectRatio = 2 / 3;
    const double spacing = 12;

    int crossAxisCount = (gridWidth / (maxCrossAxisExtent + spacing)).ceil();
    if (crossAxisCount < 1) crossAxisCount = 1;

    final double itemWidth = (gridWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final double itemHeight = itemWidth / childAspectRatio;

    final double availableHeight = constraints.maxHeight - 160; 
    if (availableHeight <= 0) return 20;

    int rowCount = (availableHeight / (itemHeight + spacing)).floor();
    if (rowCount < 2) rowCount = 2;

    return crossAxisCount * rowCount;
  }

  @override
  Widget build(BuildContext context) {
    final allShows = context.watch<LibraryProvider>().groupedTvShows;
    if (allShows.isEmpty) return const EmptyState(message: 'No TV shows found.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final int perPage = _calculateItemsPerPage(constraints);

        final totalPages = (allShows.length / perPage).ceil();
        if (_page >= totalPages && totalPages > 0) _page = totalPages - 1;
        if (totalPages == 0) _page = 0;

        final start = _page * perPage;
        final end = (start + perPage < allShows.length) ? start + perPage : allShows.length;
        final pageItems = allShows.sublist(start, end);

        // Map TvShows to MediaItems for MediaGrid
        final displayItems = pageItems.map((show) {
          return show.firstEpisode.copyWith(
            title: show.title,
            posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
            backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
            year: show.year ?? show.firstEpisode.year,
            episode: null,
            // Pass episodeCount as custom data or handle in MediaGrid? 
            // TvScreen passed 'badge' manually. MediaGrid assumes item. 
            // MediaCard handles badge if passed? MediaGrid uses MediaCard(item: item). 
            // MediaCard doesn't rely on external badge param unless explicitly passed.
            // Wait, MediaGrid calls: `MediaCard(item: items[i], posterAspectRatio: ...)`
            // It does NOT pass 'badge'.
            // TvScreen previously passed `badge: '${show.episodeCount} eps'`.
            // To preserve this, I might need to keep using custom GridView or update MediaGrid/MediaItem logic.
            // Or I can just manually build GridView using SliverGridDelegateWithMaxCrossAxisExtent to match MediaGrid behavior.
            // Let's stick to GridView.builder with consistent delegate to keep the badge custom logic.
          );
        }).toList();

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
                  // Use same responsive delegate as MediaGrid
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (_, i) {
                    final show = pageItems[i];
                    final display = displayItems[i];
                    return MediaCard(item: display, badge: '${show.episodeCount} eps');
                  },
                ),
              ),
              PaginationControls(
                currentPage: _page, 
                totalPages: totalPages, 
                onPageChanged: (p) => setState(() => _page = p),
              ),
            ],
          ),
        );
      }
    );
  }
}