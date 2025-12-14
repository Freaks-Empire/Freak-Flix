import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'media_card.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  const MediaGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 100, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => MediaCard(item: items[i]),
    );
  }
}