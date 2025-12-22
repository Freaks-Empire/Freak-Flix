import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/media_grid.dart';
import '../widgets/empty_state.dart';

class AdultScreen extends StatelessWidget {
  const AdultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adultItems = context.watch<LibraryProvider>().adult;
    if (adultItems.isEmpty) return const EmptyState(message: 'No adult content found.');
    return MediaGrid(items: adultItems);
  }
}
