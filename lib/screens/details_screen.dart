import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
import '../widgets/safe_network_image.dart';
import 'video_player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late MediaItem _current;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackProvider>();
    final library = context.watch<LibraryProvider>();

    // Build an episode list from the library using the same showKey/folder grouping.
    List<MediaItem> episodes =
        library.items.where((m) => m.type == MediaType.tv).where((m) {
      final key = m.showKey;
      if (key != null && key.isNotEmpty && _current.showKey != null) {
        return key == _current.showKey;
      }
      return m.folderPath.toLowerCase() == _current.folderPath.toLowerCase();
    }).toList();

    if (episodes.isEmpty) {
      episodes = [_current];
    } else {
      episodes.sort((a, b) {
        final sa = a.season ?? 0;
        final sb = b.season ?? 0;
        final ea = a.episode ?? 0;
        final eb = b.episode ?? 0;
        return sa != sb ? sa.compareTo(sb) : ea.compareTo(eb);
      });
    }

    final hasEpisodes = episodes.length > 1;
    return Scaffold(
      appBar: AppBar(title: Text(_current.title ?? _current.fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_current.backdropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SafeNetworkImage(
                url: _current.backdropUrl,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          const SizedBox(height: 12),
          Text(_current.title ?? _current.fileName,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(
              '${_current.year ?? ''} • ${_current.runtimeMinutes ?? '--'} min • ${_current.rating ?? '--'}/10'),
          if (_current.genres.isNotEmpty) Text(_current.genres.join(', ')),
          const SizedBox(height: 12),
          Text(_current.overview ?? 'No overview available.'),
          if (hasEpisodes) ...[
            const SizedBox(height: 16),
            Text('Episodes (${episodes.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final ep = episodes[index];
                  final label =
                      'S${(ep.season ?? 1).toString().padLeft(2, '0')}E${(ep.episode ?? (index + 1)).toString().padLeft(2, '0')}';
                  final isSelected = ep.id == _current.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)
                            : null,
                      ),
                      onPressed: () {
                        setState(() => _current = ep);
                        playback.start(ep);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(
                                filePath: ep.streamUrl ?? ep.filePath),
                          ),
                        );
                      },
                      child: Text(label),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Type:'),
              const SizedBox(width: 12),
              DropdownButton<MediaType>(
                value: _current.type,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _current = _current.copyWith(type: value);
                  });
                  library.updateItem(_current);
                },
                items: const [
                  DropdownMenuItem(
                      value: MediaType.unknown, child: Text('Auto')),
                  DropdownMenuItem(
                      value: MediaType.movie, child: Text('Movie')),
                  DropdownMenuItem(value: MediaType.tv, child: Text('TV')),
                ],
              ),
            ],
          ),
          SwitchListTile(
            value: _current.isAnime,
            title: const Text('Anime'),
            onChanged: (val) {
              final nextType = val && _current.type == MediaType.unknown
                  ? MediaType.tv
                  : _current.type;
              final updated = _current.copyWith(isAnime: val, type: nextType);
              setState(() => _current = updated);
              library.updateItem(updated);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  playback.start(_current);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                          filePath: _current.streamUrl ?? _current.filePath),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              OutlinedButton(
                onPressed: () {
                  final updated = _current.copyWith(
                      isWatched: !_current.isWatched, lastPositionSeconds: 0);
                  setState(() => _current = updated);
                  library.updateItem(updated);
                  Navigator.of(context).pop();
                },
                child: Text(
                    _current.isWatched ? 'Mark Unwatched' : 'Mark Watched'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
