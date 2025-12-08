import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';

class TvScreen extends StatelessWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shows = context.watch<LibraryProvider>().tv;
    if (shows.isEmpty) return const EmptyState(message: 'No TV shows found.');
    return MediaGrid(items: shows);
  }
}