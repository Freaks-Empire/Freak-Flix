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
  static const int _perPage = 50;

  @override
  Widget build(BuildContext context) {
    final allMovies = context.watch<LibraryProvider>().movies;
    if (allMovies.isEmpty) return const EmptyState(message: 'No movies found.');

    final totalPages = (allMovies.length / _perPage).ceil();
    // Safety check if page is out of bounds (e.g. after filter change)
    if (_page >= totalPages && totalPages > 0) _page = totalPages - 1;
    if (totalPages == 0) _page = 0;

    final start = _page * _perPage;
    final end = (start + _perPage < allMovies.length) ? start + _perPage : allMovies.length;
    final pageItems = allMovies.sublist(start, end);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: MediaGrid(items: pageItems),
          ),
          // Pagination Bar (pinned to bottom if we want, or scrollable? 
          // MediaGrid is a ScrollView. Pagination should probably be part of the scroll view 
          // OR fixed at bottom. Fixed at bottom makes sense for "app-like" feel.
          // But MediaGrid has built-in padding. Let's put it in a column and make MediaGrid expand.
          PaginationControls(
            currentPage: _page, 
            totalPages: totalPages, 
            onPageChanged: (p) {
               setState(() => _page = p);
               // Optional: Scroll to top?
               // Since MediaGrid preserves scroll position if keys don't change, we might want to force scroll top.
               // But for now, simple state change.
            }
          ),
        ],
      ),
    );
  }
}