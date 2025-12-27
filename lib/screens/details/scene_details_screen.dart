import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/media_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import 'actor_details_screen.dart';
import '../../models/cast_member.dart';

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
    
    // Auto-play preview or full video loop if feasible? 
    // Usually local files, so we can't just stream a small preview easily unless we play from start.
    // We'll leave it as backdrop image for now, or play if user wants (handled by "Play" button).
    // Future: Maybe play a snippet?
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
    
    final libraryItem = context.select<LibraryProvider, MediaItem?>((p) => 
        p.items.firstWhereOrNull((i) => i.id == widget.item.id)
    );
    
    if (libraryItem != null && libraryItem != _current) {
      _current = libraryItem;
    }

    final isDesktop = size.width > 900;
    final displayCast = _current.cast;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background
          Positioned.fill(
            child: _current.backdropUrl != null 
                ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover) 
                : (_current.posterUrl != null 
                    ? SafeNetworkImage(url: _current.posterUrl, fit: BoxFit.cover)
                    : Container(color: Colors.black)),
          ),

          // 2. Blur & Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      const Color(0xFF0F0F0F).withOpacity(0.8),
                      const Color(0xFF0F0F0F).withOpacity(0.95),
                      const Color(0xFF0F0F0F),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 64 : 24, 
                size.height * 0.15,
                isDesktop ? 64 : 24, 
                64
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // --- Hero Section ---
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroPoster(context),
                        const SizedBox(width: 48),
                        Expanded(child: _buildHeroDetails(context, library, playback, theme)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _buildHeroPoster(context)),
                        const SizedBox(height: 24),
                        _buildHeroDetails(context, library, playback, theme),
                      ],
                    ),
                  
                  const SizedBox(height: 64),

                  // Performers
                  if (displayCast.isNotEmpty) ...[
                    Text('Performers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayCast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) => _CastCard(actor: displayCast[i]),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // Related Scenes
                  // We can reuse logic or simplify it here.
                  Builder(
                    builder: (context) {
                       final libraryItems = library.items;
                       final currentTags = _current.genres.toSet();
                       
                       List<MediaItem> relatedItems = [];
                       if (currentTags.isNotEmpty) {
                         relatedItems = libraryItems
                             .where((i) => i.id != _current.id && i.isAdult)
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
                             Text('Related Scenes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
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
                           ],
                         );
                       }
                       return const SizedBox.shrink();
                    }
                  ),
                ],
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 24,
            left: 24,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPoster(BuildContext context) {
    // For scenes, maybe Landscape poster? Or standard portrait if we have it?
    // StashDB often gives landscape thumbnails (screenshots).
    // Let's check aspect ratio of posterUrl.
    // Assuming Portrait for uniformity with Movies, but if it's a screenshot it might look cropped.
    // Let's use a flexible container.
    return Container(
      width: 300, 
      height: 450, // Force portrait for consistency? Or 300x200 for landscape?
                   // User said "similar look", usually means vertical poster.
                   // If StashDB provides landscape, we might want to `fit: BoxFit.cover` which crops it centrally.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeNetworkImage(
        url: _current.posterUrl ?? _current.backdropUrl, 
        fit: BoxFit.cover,
        errorBuilder: (_,__,___) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, size: 50, color: Colors.white24)),
      ),
    );
  }

  Widget _buildHeroDetails(BuildContext context, LibraryProvider library, PlaybackProvider playback, ThemeData theme) {
    final year = _current.year?.toString() ?? '';
    final runtime = _current.runtimeMinutes != null ? '${_current.runtimeMinutes}m' : '';
    final rating = _current.rating != null ? '${(_current.rating! * 10).toInt()}%' : '';
    
    // Extract Studio from overview if available (common in StashDB imports)
    String? studio;
    if (_current.overview != null && _current.overview!.startsWith('Studio: ')) {
      final endLine = _current.overview!.indexOf('\n');
      if (endLine != -1) {
        studio = _current.overview!.substring(8, endLine).trim();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _current.title ?? _current.fileName,
          style: theme.textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        if (studio != null) ...[
          Text(
            studio,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            if (year.isNotEmpty) _SimpleTag(text: year),
            if (runtime.isNotEmpty) ...[const SizedBox(width: 12), _SimpleTag(text: runtime)],
            const SizedBox(width: 12), const _SimpleTag(text: '18+', color: Colors.orange), // Explicit tag
            const SizedBox(width: 12),
            Expanded(
               child: Text(
                 _current.genres.join(', '), 
                 style: const TextStyle(color: Colors.white54, fontSize: 13),
                 overflow: TextOverflow.ellipsis,
               ),
             ),
          ],
        ),
        const SizedBox(height: 20),

        if (rating.isNotEmpty) ...[
          Row(
           children: [
             const Icon(Icons.thumb_up, color: Colors.redAccent, size: 20),
             const SizedBox(width: 6),
             Text(rating, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           ],
          ),
          const SizedBox(height: 24),
        ],

         Text(
          _current.overview?.replaceAll(RegExp(r'Studio: .*\n'), '') ?? 'No details available.', // Strip studio if we showed it above
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
            height: 1.6,
            fontSize: 16,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 32),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _current.filePath.isNotEmpty ? () {
                 playback.start(_current);
                 Navigator.of(context).push(
                   MaterialPageRoute(builder: (_) => VideoPlayerScreen(item: _current)),
                 );
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_current.filePath.isNotEmpty ? 'Play Scene' : 'Missing File'),
            ),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                 final updated = _current.copyWith(isWatched: !_current.isWatched);
                 // We don't have local setState for _current inside this method easily unless we recreate layout, 
                 // but LibraryProvider updates usually trigger rebuilds if we listen right.
                 // Actually `_current` is updated in `build` from provider.
                 library.updateItem(updated);
              },
              icon: Icon(_current.isWatched ? Icons.check : Icons.add),
              label: Text(_current.isWatched ? 'Watched' : 'Watchlist'),
            ),
          ],
        ),
      ],
    );
  }
}


class _SimpleTag extends StatelessWidget {
  final String text;
  final Color? color;
  const _SimpleTag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? Colors.white70, 
        fontWeight: FontWeight.w500,
        fontSize: 14
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  final CastMember actor;
  const _CastCard({required this.actor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ActorDetailsScreen(actor: actor)),
      ),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: (actor.profileUrl != null 
                        ? NetworkImage(actor.profileUrl!) 
                        : const AssetImage('assets/placeholder_person.png')) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(actor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final MediaItem item;
  const _SceneCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SceneDetailsScreen(item: item)),
      ),
      child: SizedBox(
        width: 250, // Slightly wider for scenes (landscape thumbs usually)
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16/9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: (item.posterUrl != null || item.backdropUrl != null) 
                        ? NetworkImage(item.posterUrl ?? item.backdropUrl!) 
                        : const AssetImage('assets/placeholder_movie.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Center(child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.5), size: 40)),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.title ?? item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
             Text(item.year?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
