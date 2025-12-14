import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;

import '../../models/media_item.dart';
import '../../models/tmdb_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../services/tmdb_service.dart';
import '../../models/tmdb_extended_details.dart';
import '../../widgets/discover_card.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final MediaItem item;
  const MovieDetailsScreen({super.key, required this.item});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late MediaItem _current;
  late final Player _player;
  late final VideoController _controller;
  
  TmdbExtendedDetails? _details;
  bool _trailerLoading = true;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _player = Player();
    _controller = VideoController(_player, configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true));
    
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final service = context.read<TmdbService>();
    if (_current.tmdbId != null) {
      final details = await service.getExtendedDetails(_current.tmdbId!, _current.type);
      if (mounted) {
        setState(() => _details = details);
        _playTrailer();
      }
    }
  }

  Future<void> _playTrailer() async {
    if (_details?.videos.isEmpty ?? true) {
      setState(() => _trailerLoading = false);
      return;
    }

    // Find Youtube Trailer
    final trailer = _details!.videos.firstWhere(
      (v) => v.site == 'YouTube' && v.type == 'Trailer',
      orElse: () => _details!.videos.firstWhere((v) => v.site == 'YouTube', orElse: () => const TmdbVideo(key: '', site: '', type: '', name: '')),
    );

    if (trailer.key.isEmpty) {
      setState(() => _trailerLoading = false);
      return;
    }

    try {
      final yt = YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(trailer.key);
      final streamInfo = manifest.muxed.withHighestBitrate();
      yt.close();

      await _player.open(Media(streamInfo.url.toString()), play: true);
      await _player.setVolume(0); // Muted by default
      await _player.setPlaylistMode(PlaylistMode.loop);
      
      if (mounted) setState(() => _trailerLoading = false);
    } catch (e) {
      debugPrint('Error playing trailer: $e');
      if (mounted) setState(() => _trailerLoading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : 70);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final playback = context.read<PlaybackProvider>();
    final library = context.read<LibraryProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer
          Positioned.fill(
            child: _trailerLoading || _player.state.width == null
                ? (_current.backdropUrl != null 
                    ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover) 
                    : Container(color: Colors.black))
                : Video(controller: _controller, fit: BoxFit.cover, controls: NoVideoControls),
          ),
          
          // Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.9],
                ),
              ),
            ),
          ),

          // Content Layer
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.45), // Push content down
                  
                  // Logo/Title
                  Text(
                    _current.title ?? _current.fileName,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Meta Row
                  Row(
                    children: [
                      _MetaTag(text: '${_current.year ?? ""}', icon: Icons.calendar_today),
                      const SizedBox(width: 12),
                      _MetaTag(text: '${_current.runtimeMinutes ?? "??"}m', icon: Icons.timer),
                      const SizedBox(width: 12),
                      _MetaTag(text: '${_current.rating ?? ""}', icon: Icons.star, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Genres
                  Wrap(
                    spacing: 8,
                    children: _current.genres.map((g) => Chip(
                      label: Text(g, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white12,
                      labelPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Overview
                  SizedBox(
                    width: size.width * 0.6,
                    child: Text(
                      _current.overview ?? '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Actions through library/playback
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: _current.filePath.isNotEmpty ? () {
                           playback.start(_current);
                           Navigator.of(context).push(
                             MaterialPageRoute(
                               builder: (_) => VideoPlayerScreen(
                                   filePath: _current.streamUrl ?? _current.filePath,
                                   title: _current.title ?? _current.fileName,
                               ),
                             ),
                           );
                        } : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_current.filePath.isNotEmpty ? 'Play' : 'Not Available'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                           foregroundColor: Colors.white,
                           side: const BorderSide(color: Colors.white54),
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: _current.filePath.isNotEmpty ? () {
                            final updated = _current.copyWith(isWatched: !_current.isWatched);
                            setState(() => _current = updated);
                            library.updateItem(updated);
                        } : null,
                        icon: Icon(_current.isWatched ? Icons.check : Icons.add),
                        label: Text(_current.isWatched ? 'Watched' : 'Watchlist'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 64),
                  
                  // Actors Section
                  if (_details?.cast.isNotEmpty ?? false) ...[
                    _SectionHeader(title: 'Actors'),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _details!.cast.length,
                        itemBuilder: (ctx, i) {
                          final actor = _details!.cast[i];
                          return Container(
                            width: 240,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: actor.profileUrl != null
                                     ? Image.network(actor.profileUrl!, width: 60, height: 90, fit: BoxFit.cover)
                                     : Container(width: 60, height: 90, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(actor.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 2),
                                      const SizedBox(height: 4),
                                      Text(actor.character, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // Recommendations
                  if (_details?.recommendations.isNotEmpty ?? false) ...[
                    _SectionHeader(title: 'You may like'),
                    SizedBox(
                      height: 280,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _details!.recommendations.length,
                        separatorBuilder: (_,__) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) => DiscoverCard(item: _details!.recommendations[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 24,
            left: 24,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Mute Button (if video playing)
          // Top Right Actions
          Positioned(
            top: 24,
            right: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Rescan Library',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rescanning ${widget.item.folderPath.isNotEmpty ? widget.item.folderPath : widget.item.title}...')),
                    );
                    context.read<LibraryProvider>().rescanItem(widget.item);
                  },
                ),
                if (!_trailerLoading) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                    onPressed: _toggleMute,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _MetaTag({required this.text, required this.icon, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Colors.red, width: 4)),
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
