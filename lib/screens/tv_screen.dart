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
  @override
  Widget build(BuildContext context) {
    final allShows = context.watch<LibraryProvider>().groupedTvShows;
    if (allShows.isEmpty) return const EmptyState(message: 'No TV shows found.');

    // Map TvShows to MediaItems for MediaGrid
    final displayItems = allShows.map((show) {
      return show.firstEpisode.copyWith(
        title: show.title,
        posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
        backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
        year: show.year ?? show.firstEpisode.year,
        episode: null,
      );
    }).toList();

    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
        // Use same responsive delegate as MediaGrid
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: allShows.length,
        itemBuilder: (_, i) {
          final show = allShows[i];
          final display = displayItems[i];
          return MediaCard(item: display, badge: '${show.episodeCount} eps');
        },
      ),
    );
  }
}