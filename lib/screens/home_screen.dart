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
    final heroItem = library.items.first;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: HeroBanner(item: heroItem)),
        SliverToBoxAdapter(
          child: MediaCarouselRow(title: 'Continue Watching', items: library.continueWatching),
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