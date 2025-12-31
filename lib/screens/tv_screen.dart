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
  static const int _perPage = 50;

  @override
  Widget build(BuildContext context) {
    final allShows = context.watch<LibraryProvider>().groupedTvShows;
    if (allShows.isEmpty) return const EmptyState(message: 'No TV shows found.');

    final totalPages = (allShows.length / _perPage).ceil();
    if (_page >= totalPages && totalPages > 0) _page = totalPages - 1;
    if (totalPages == 0) _page = 0;

    final start = _page * _perPage;
    final end = (start + _perPage < allShows.length) ? start + _perPage : allShows.length;
    final pageItems = allShows.sublist(start, end);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: pageItems.length,
              itemBuilder: (_, i) {
                final show = pageItems[i];
                final display = show.firstEpisode.copyWith(
                  title: show.title,
                  posterUrl: show.posterUrl ?? show.firstEpisode.posterUrl,
                  backdropUrl: show.backdropUrl ?? show.firstEpisode.backdropUrl,
                  year: show.year ?? show.firstEpisode.year,
                  episode: null,
                );
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
}