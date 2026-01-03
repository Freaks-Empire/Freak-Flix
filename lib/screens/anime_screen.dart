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
  @override
  Widget build(BuildContext context) {
    final shows = context.watch<LibraryProvider>().groupedAnimeShows;
    if (shows.isEmpty) return const EmptyState(message: 'No anime found.');

    // Map to display items
    final displayItems = shows.map((show) {
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
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: shows.length,
        itemBuilder: (_, i) {
          final show = shows[i];
          final display = displayItems[i];
          return MediaCard(item: display, badge: '${show.episodeCount} eps');
        },
      ),
    );
  }
}