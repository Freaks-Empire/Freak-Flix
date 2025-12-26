import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/discover_card.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import 'actor_details_screen.dart';

class SceneDetailsScreen extends StatefulWidget {
  final MediaItem item;
  const SceneDetailsScreen({super.key, required this.item});

  @override
  State<SceneDetailsScreen> createState() => _SceneDetailsScreenState();
}

class _SceneDetailsScreenState extends State<SceneDetailsScreen> {
  late MediaItem _current;
  late final Player _player;
  late final VideoController _controller;
  
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _player = Player();
    _controller = VideoController(_player, configuration: const VideoControllerConfiguration(enableHardwareAcceleration: true));
    
    // Auto-play preview if we had one? StashDB scenes usually return screenshot as backdrop.
    // Future expansion: Play preview clip if available.
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
    
    // Watch for updates to this specific item in the library
    final libraryItem = context.select<LibraryProvider, MediaItem?>((p) => 
        p.items.firstWhereOrNull((i) => i.id == widget.item.id)
    );
    
    if (libraryItem != null && libraryItem != _current) {
      _current = libraryItem;
    }

    // Cast Selection Legacy (Use standard current.cast for StashDB)
    final displayCast = _current.cast;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer
          Positioned.fill(
            child: _player.state.width == null
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
                      // StashDB often uses stars or 1-10 rating? We have 1-10 in model.
                      _MetaTag(text: '${_current.rating ?? ""}', icon: Icons.star, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Genres / Tags
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
                  // StashDB overview might include Studio.
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
                                   item: _current,
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
                  
                  const SizedBox(height: 32), // spacer

                  // 1. Actors Section (Performers)
                  if (displayCast.isNotEmpty) ...[
                    _SectionHeader(title: 'Performers'),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayCast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) {
                          final actor = displayCast[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ActorDetailsScreen(actor: actor)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
                                    ],
                                    image: DecorationImage(
                                      image: (actor.profileUrl != null 
                                          ? NetworkImage(actor.profileUrl!) 
                                          : const AssetImage('assets/placeholder_person.png')) as ImageProvider,
                                      fit: BoxFit.cover,
                                      onError: (_, __) {}, 
                                    ),
                                    color: Colors.grey[800],
                                  ),
                                  child: actor.profileUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    actor.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 2. Related Scenes (Tag-based)
                  Builder(
                    builder: (context) {
                      final libraryItems = library.items;
                      final currentTags = _current.genres.toSet();
                      
                      List<MediaItem> relatedItems = [];
                      if (currentTags.isNotEmpty) {
                        relatedItems = libraryItems
                            .where((i) => i.id != _current.id && i.isAdult) // Only matches other adult content? or just by tag?
                            // Let's match any type if tags match, but user said "Related Scenes" which implies "Scenes".
                            // StashDB items are usually marked isAdult=true.
                            .map((item) {
                              int score = item.genres.where((g) => currentTags.contains(g)).length;
                              return MapEntry(item, score);
                            })
                            .where((e) => e.value > 0)
                            .sorted((a, b) => b.value.compareTo(a.value))
                            .map((e) => e.key)
                            .take(15)
                            .toList();
                      }

                      if (relatedItems.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: 'Related Scenes'),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 220,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: relatedItems.length,
                                separatorBuilder: (_,__) => const SizedBox(width: 12),
                                itemBuilder: (ctx, i) => _SceneCard(item: relatedItems[i]),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  ),

                  // 3. Details (Collapsible)
                  _DetailsSection(item: _current),
                  
                  const SizedBox(height: 100), // Bottom padding
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

class _SceneCard extends StatelessWidget {
  final MediaItem item;
  const _SceneCard({required this.item});

  @override
  Widget build(BuildContext context) {
      final theme = Theme.of(context);
      return GestureDetector(
        onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => SceneDetailsScreen(item: item),
              ),
            );
        },
        child: SizedBox(
          width: 200, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Expanded(
                 child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item.posterUrl ?? item.backdropUrl ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.movie, size: 40),
                        ),
                      ),
                      if (item.runtimeMinutes != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(item.runtimeMinutes!),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                 ),
               ),
               const SizedBox(height: 8),
               Text(
                 item.title ?? item.fileName,
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
                 style: theme.textTheme.labelLarge,
               ),
            ],
          ),
        ),
      );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _DetailsSection extends StatelessWidget {
  final MediaItem item;
  const _DetailsSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text(
          'Details',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        tilePadding: EdgeInsets.zero,
        children: [
          _buildGrid(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final data = <String, String>{};
    
    if (item.year != null) data['Date'] = item.lastModified.toString().split(' ')[0]; // Use Release Date or similar
    if (item.runtimeMinutes != null) data['Runtime'] = '${item.runtimeMinutes}m';
    if (item.genres.isNotEmpty) data['Tags'] = item.genres.take(3).join(', '); // Show top tags
    
    // Parse Studio
    if (item.overview != null && item.overview!.startsWith('Studio: ')) {
      final endLine = item.overview!.indexOf('\n');
      if (endLine != -1) {
        data['Studio'] = item.overview!.substring(8, endLine).trim();
      }
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 3.5,
      physics: const NeverScrollableScrollPhysics(),
      children: data.entries.map((e) => _DetailItem(label: e.key, value: e.value)).toList(),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
