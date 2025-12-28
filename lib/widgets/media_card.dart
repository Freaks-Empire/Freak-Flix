/// lib/widgets/media_card.dart
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../screens/details_screen.dart';
import '../providers/library_provider.dart';
import 'package:provider/provider.dart';
import 'safe_network_image.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final String? badge;
  const MediaCard({super.key, required this.item, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailsScreen(itemId: item.id, item: item)),
      ),
      child: SizedBox(
        width: 140,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reserve vertical space for text/chip to avoid overflow in tight grids.
            const reserved = 60.0; // title + year + chip spacing
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SafeNetworkImage(
                            url: item.posterUrl,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(8),
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          // Availability Indicator
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Consumer<LibraryProvider>(
                              builder: (context, library, _) {
                                // If it has a filePath, it's local.
                                // If it has a tmdbId, check if it exists in library.
                                bool isLocal = item.filePath.isNotEmpty;
                                
                                if (!isLocal && item.tmdbId != null) {
                                  final match = library.findByTmdbId(item.tmdbId!);
                                  if (match != null) {
                                    // Make sure TV shows actually have episodes
                                    if (match.type == MediaType.movie) {
                                      isLocal = true;
                                    } else {
                                      isLocal = match.episodes.isNotEmpty;
                                    }
                                  }
                                }
                                    
                                if (isLocal) return const SizedBox.shrink(); // Don't show anything if available (or show check if desired)
                                
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close, size: 16, color: Colors.redAccent),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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