import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_carousel_row.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    if (library.isLoading) return const LoadingIndicator(message: 'Scanning library...');
    if (library.items.isEmpty) {
      return const EmptyState(message: 'No media yet. Go to Settings to scan a folder.');
    }
    final heroItem = _pickHero(library);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: HeroBanner(item: heroItem)),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Continue Watching', items: library.continueWatching),
        ),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'TV', items: library.tv),
        ),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Movies', items: library.movies),
        ),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Anime', items: library.anime),
        ),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Recently Added', items: library.recentlyAdded),
        ),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Top Rated', items: library.topRated),
        ),
      ],
    );
  }
}

MediaItem _pickHero(LibraryProvider library) {
  if (library.continueWatching.isNotEmpty) return library.continueWatching.first;
  if (library.topRated.isNotEmpty) return library.topRated.first;
  if (library.recentlyAdded.isNotEmpty) return library.recentlyAdded.first;
  return library.items.first;
}