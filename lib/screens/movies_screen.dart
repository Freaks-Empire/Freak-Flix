import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';
import '../widgets/pagination_controls.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  int _page = 0;
  
  // Calculate items per page dynamically
  int _calculateItemsPerPage(BoxConstraints constraints) {
    // MediaGrid uses SliverGridDelegateWithMaxCrossAxisExtent with maxCrossAxisExtent = 150
    // and aspect ratio 2/3.
    // Let's emulate that logic to find how many columns fit.
    
    // We want to fill the available height (minus padding/pagination controls)
    // Vertical padding is approx 112 (100 top + 12 bottom)
    // Pagination controls height: approx 60-80? Let's assume some saved space.
    
    final double gridWidth = constraints.maxWidth - 24; // 12 padding each side
    const double maxCrossAxisExtent = 150;
    const double childAspectRatio = 2 / 3;
    const double spacing = 12;

    int crossAxisCount = (gridWidth / (maxCrossAxisExtent + spacing)).ceil();
    // Ensure at least 1 column
    if (crossAxisCount < 1) crossAxisCount = 1;

    // Approximate item height
    // Width of one item approx:
    final double itemWidth = (gridWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final double itemHeight = itemWidth / childAspectRatio;

    final double availableHeight = constraints.maxHeight - 160; // Approximate padding + pagination
    if (availableHeight <= 0) return 20; // Fallback

    int rowCount = (availableHeight / (itemHeight + spacing)).floor();
    if (rowCount < 2) rowCount = 2; // Minimum rows

    return crossAxisCount * rowCount;
  }

  @override
  Widget build(BuildContext context) {
    final allMovies = context.watch<LibraryProvider>().movies;
    if (allMovies.isEmpty) return const EmptyState(message: 'No movies found.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final int perPage = _calculateItemsPerPage(constraints);
        
        final totalPages = (allMovies.length / perPage).ceil();
        // Safety check if page is out of bounds
        if (_page >= totalPages && totalPages > 0) _page = totalPages - 1;
        if (totalPages == 0) _page = 0;

        final start = _page * perPage;
        final end = (start + perPage < allMovies.length) ? start + perPage : allMovies.length;
        final pageItems = allMovies.sublist(start, end);

        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MediaGrid(items: pageItems),
              ),
              PaginationControls(
                currentPage: _page, 
                totalPages: totalPages, 
                onPageChanged: (p) {
                   setState(() => _page = p);
                }
              ),
            ],
          ),
        );
      },
    );
  }
}