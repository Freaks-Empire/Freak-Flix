/// lib/screens/anime_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';

import '../widgets/pagination_controls.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});

  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  int _page = 0;

  int _calculateItemsPerPage(BoxConstraints constraints) {
    // Standard MediaGrid sizing
    final double gridWidth = constraints.maxWidth - 24; 
    const double maxCrossAxisExtent = 250;
    const double childAspectRatio = 2 / 3;
    const double spacing = 12;

    int crossAxisCount = (gridWidth / (maxCrossAxisExtent + spacing)).ceil();
    if (crossAxisCount < 1) crossAxisCount = 1;

    final double itemWidth = (gridWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final double itemHeight = itemWidth / childAspectRatio;

    // Available height calculation
    final double availableHeight = constraints.maxHeight - 160; 
    if (availableHeight <= 0) return 20;

    int rowCount = (availableHeight / (itemHeight + spacing)).floor();
    if (rowCount < 2) rowCount = 2;

    return crossAxisCount * rowCount;
  }

  @override
  Widget build(BuildContext context) {
    final shows = context.watch<LibraryProvider>().groupedAnimeShows;
    if (shows.isEmpty) return const EmptyState(message: 'No anime found.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final int perPage = _calculateItemsPerPage(constraints);

        final totalPages = (shows.length / perPage).ceil();
        if (_page >= totalPages && totalPages > 0) _page = totalPages - 1;
        if (totalPages == 0) _page = 0;

        final start = _page * perPage;
        final end = (start + perPage < shows.length) ? start + perPage : shows.length;
        final pageItems = shows.sublist(start, end);

        // Map to display items
        final displayItems = pageItems.map((show) {
          return show.firstEpisode.copyWith(
            title: show.title,
            posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
            backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
            year: show.year ?? show.firstEpisode.year,
            episode: null,
          );
        }).toList();

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
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