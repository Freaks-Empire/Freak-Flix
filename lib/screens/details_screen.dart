import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/library_provider.dart';
import '../providers/playback_provider.dart';
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
    final library = context.read<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_current.title ?? _current.fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_current.backdropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(_current.backdropUrl!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          Text(_current.title ?? _current.fileName, style: Theme.of(context).textTheme.headlineSmall),
          Text('${_current.year ?? ''} • ${_current.runtimeMinutes ?? '--'} min • ${_current.rating ?? '--'}/10'),
          if (_current.genres.isNotEmpty) Text(_current.genres.join(', ')),
          const SizedBox(height: 12),
          Text(_current.overview ?? 'No overview available.'),
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
                  DropdownMenuItem(value: MediaType.unknown, child: Text('Auto')),
                  DropdownMenuItem(value: MediaType.movie, child: Text('Movie')),
                  DropdownMenuItem(value: MediaType.tv, child: Text('TV')),
                ],
              ),
            ],
          ),
          SwitchListTile(
            value: _current.isAnime,
            title: const Text('Anime'),
            onChanged: (val) {
              final nextType = val && _current.type == MediaType.unknown ? MediaType.tv : _current.type;
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
                    MaterialPageRoute(builder: (_) => VideoPlayerScreen(filePath: _current.filePath)),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              OutlinedButton(
                onPressed: () {
                  final updated =
                      _current.copyWith(isWatched: !_current.isWatched, lastPositionSeconds: 0);
                  setState(() => _current = updated);
                  library.updateItem(updated);
                  Navigator.of(context).pop();
                },
                child: Text(_current.isWatched ? 'Mark Unwatched' : 'Mark Watched'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}