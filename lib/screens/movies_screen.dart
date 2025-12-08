import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';

class MoviesScreen extends StatelessWidget {
  const MoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final movies = context.watch<LibraryProvider>().movies;
    if (movies.isEmpty) return const EmptyState(message: 'No movies found.');
    return MediaGrid(items: movies);
  }
}