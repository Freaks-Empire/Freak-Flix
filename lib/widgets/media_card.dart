import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../screens/details_screen.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final String? badge;
  const MediaCard({super.key, required this.item, this.badge});

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
            // Reserve vertical space for text/chip to avoid overflow in tight grids.
            final reserved = 60.0; // title + year + chip spacing
            final posterHeight = (constraints.maxHeight - reserved).clamp(110.0, 190.0);
            final chipLabel = badge ?? (item.episode != null ? 'Ep ${item.episode}' : null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: SizedBox(
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
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: Text(
                    item.title ?? item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  height: 16,
                  child: Text(
                    '${item.year ?? '--'}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (chipLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Chip(
                          label: Text(chipLabel),
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