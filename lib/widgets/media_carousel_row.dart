import 'package:flutter/material.dart';
import '../models/media_item.dart';
import 'media_card.dart';
import 'section_header.dart';

class MediaCarouselRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  const MediaCarouselRow({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, i) => MediaCard(item: items[i]),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}