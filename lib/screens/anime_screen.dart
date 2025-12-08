import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';

class AnimeScreen extends StatelessWidget {
  const AnimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shows = context.watch<LibraryProvider>().anime;
    if (shows.isEmpty) return const EmptyState(message: 'No anime found.');
    return MediaGrid(items: shows);
  }
}