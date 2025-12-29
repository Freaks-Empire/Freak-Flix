/// lib/widgets/media_grid.dart
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final double childAspectRatio;
  final double maxCrossAxisExtent;

  const MediaGrid({
    super.key,
    required this.items,
    this.childAspectRatio = 2 / 3,
    this.maxCrossAxisExtent = 150,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => MediaCard(
        item: items[i],
        posterAspectRatio: childAspectRatio,
      ),
    );
  }
}