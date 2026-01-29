/// lib/widgets/hero_banner.dart
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../screens/details_screen.dart';
import 'package:go_router/go_router.dart';
import 'safe_network_image.dart';

class HeroBanner extends StatelessWidget {
  final MediaItem item;
  const HeroBanner({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         if (item.isAnime && item.anilistId != null) {
            final slug = _slugify(item.title ?? 'anime');
            context.push('/anime/${item.anilistId}/$slug', extra: item);
         } else if (item.id.startsWith('stashdb:')) {
            final rawId = item.id.replaceFirst('stashdb:', '');
            context.push('/scene/$rawId', extra: item);
         } else {
            context.push('/media/${Uri.encodeComponent(item.id)}', extra: item);
         }
      },
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 6,
            child: SafeNetworkImage(
              url: item.backdropUrl,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title ?? item.fileName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 480,
                  child: Text(
                    item.overview ?? 'No overview yet. Tap to view details.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                     if (item.isAnime && item.anilistId != null) {
                        final slug = _slugify(item.title ?? 'anime');
                        context.push('/anime/${item.anilistId}/$slug', extra: item);
                     } else if (item.id.startsWith('stashdb:')) {
                        final rawId = item.id.replaceFirst('stashdb:', '');
                        context.push('/scene/$rawId', extra: item);
                     } else {
                        context.push('/media/${Uri.encodeComponent(item.id)}', extra: item);
                     }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') 
        .trim()
        .replaceAll(RegExp(r'\s+'), '-'); 
  }
}
