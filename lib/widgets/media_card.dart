import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../screens/details_screen.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  const MediaCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.posterUrl != null
                    ? Image.network(item.posterUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade800, child: const Icon(Icons.movie)),
              ),
            ),
            const SizedBox(height: 6),
            Text(item.title ?? item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${item.year ?? '--'}', style: Theme.of(context).textTheme.bodySmall),
            if (item.episode != null)
              Chip(
                label: Text('Ep ${item.episode}'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}