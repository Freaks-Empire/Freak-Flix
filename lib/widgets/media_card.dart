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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final posterHeight = (constraints.maxHeight - 48).clamp(120.0, 200.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: posterHeight,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.posterUrl != null
                          ? Image.network(item.posterUrl!, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade800, child: const Icon(Icons.movie)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.title ?? item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${item.year ?? '--'}', style: Theme.of(context).textTheme.bodySmall),
                if (item.episode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Chip(
                          label: Text('Ep ${item.episode}'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}