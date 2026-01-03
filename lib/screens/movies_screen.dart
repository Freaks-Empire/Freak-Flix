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
  @override
  Widget build(BuildContext context) {
    final allMovies = context.watch<LibraryProvider>().movies;
    if (allMovies.isEmpty) return const EmptyState(message: 'No movies found.');

    return Scaffold(
      body: MediaGrid(
        items: allMovies,
        maxCrossAxisExtent: 250,
      ),
    );
  }
}