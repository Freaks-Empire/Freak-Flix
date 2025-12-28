/// lib/screens/tv_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';

class TvScreen extends StatelessWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shows = context.watch<LibraryProvider>().groupedTvShows;
    if (shows.isEmpty) return const EmptyState(message: 'No TV shows found.');

    // Debugging: ensure grouping works
    // ignore: avoid_print


    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: shows.length,
      itemBuilder: (_, i) {
        final show = shows[i];
        final display = show.firstEpisode.copyWith(
          title: show.title,
          posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
          backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
          year: show.year ?? show.firstEpisode.year,
          episode: null,
        );
        return MediaCard(item: display, badge: '${show.episodeCount} eps');
      },
    );
  }
}