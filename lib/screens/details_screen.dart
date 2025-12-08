import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/playback_provider.dart';
import 'video_player_screen.dart';

class DetailsScreen extends StatelessWidget {
  final MediaItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(item.title ?? item.fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.backdropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(item.backdropUrl!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Text(item.title ?? item.fileName, style: Theme.of(context).textTheme.headlineSmall),
          Text('${item.year ?? ''} • ${item.runtimeMinutes ?? '--'} min • ${item.rating ?? '--'}/10'),
          if (item.genres.isNotEmpty) Text(item.genres.join(', ')),
          const SizedBox(height: 12),
          Text(item.overview ?? 'No overview available.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  playback.start(item);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => VideoPlayerScreen(filePath: item.filePath)),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              OutlinedButton(
                onPressed: () {
                  final updated = item.copyWith(isWatched: !item.isWatched, lastPositionSeconds: 0);
                  playback.library.items[playback.library.items.indexWhere((i) => i.id == item.id)] =
                      updated;
                  playback.library.saveLibrary();
                  Navigator.of(context).pop();
                },
                child: Text(item.isWatched ? 'Mark Unwatched' : 'Mark Watched'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}