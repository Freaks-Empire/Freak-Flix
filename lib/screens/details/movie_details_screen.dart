/// lib/screens/details/movie_details_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/trailer_player.dart';
import '../../models/media_item.dart';
import '../../models/tmdb_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/metadata_service.dart';
import '../../models/tmdb_extended_details.dart';
import '../../widgets/discover_card.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import 'actor_details_screen.dart';
import '../../models/cast_member.dart';
import 'package:go_router/go_router.dart';

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
  bool _muted = true; // Still used for backdrop video if local file plays? Or just remove backdrop video entirely for trailers?
  // Let's keep backdrop video logic ONLY for local files if we ever implement that, but for now we are removing dynamic YouTube backdrop.
  // Actually, the previous code used `Video` widget for backdrop. If we remove YouTube fetch, the backdrop will just be the image.
  // So we don't need _player for trailers anymore.

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    // _player = Player(); // No longer needed for YouTube background
    // _controller = VideoController(_player); 

    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final service = context.read<TmdbService>();
    if (_current.tmdbId != null) {
      final details = await service.getExtendedDetails(_current.tmdbId!, _current.type);
      if (mounted) {
        setState(() => _details = details);
      }
    }
  }

  // _playTrailer removed

  @override
  void dispose() {
    // _player.dispose();
    super.dispose();
  }

  void _toggleMute() {
    // Only relevant if we had a background player. 
    // If we only show image backdrop, this is useless.
    // Removing mute toggle logic for now as we are strictly Image-only backdrop unless playing content.
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('File Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showFileInfo(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.white),
              title: const Text('Identify', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Fix incorrect match', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => _IdentifyDialog(item: _current),
                ).then((_) => _loadDetails()); // Reload details after potential update
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildInfoRow('File Name', _current.fileName),
            _buildInfoRow('Location', _current.filePath),
            _buildInfoRow('Size', _formatBytes(_current.sizeBytes)),
            if (_current.tmdbId != null) _buildInfoRow('TMDB ID', _current.tmdbId.toString()),
            if (_current.stashId != null) _buildInfoRow('Stash ID', _current.stashId!),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
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

    // Determine layout mode
    final isDesktop = size.width > 900;
    
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final mutedTextColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.white54;

    return Scaffold(
      backgroundColor: baseColor, 
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Static Backdrop Image
          Positioned.fill(
             child: _current.backdropUrl != null 
                ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover) 
                : Container(color: baseColor)
          ),

          // 2. Heavy Blur & Gradient Overlay (Glassmorphism Base)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      baseColor.withOpacity(0.2),
                      baseColor.withOpacity(0.8),
                      baseColor.withOpacity(0.95),
                      baseColor,
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Main Content Scrollable
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 64 : 24, 
                  size.height * 0.15, // Top padding to show some backdrop
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
                          Expanded(child: _buildHeroDetails(context, library, playback, textColor, mutedTextColor)),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: _buildHeroPoster(context)),
                          const SizedBox(height: 24),
                          _buildHeroDetails(context, library, playback, textColor, mutedTextColor),
                        ],
                      ),
                    
                    const SizedBox(height: 64),
                    
                    // --- TRAILER SECTION (NEW) ---
                    if (_details?.videos.any((v) => v.site == 'YouTube' && v.type == 'Trailer') == true) ...[
                         Text('Trailer', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         Builder(builder: (context) {
                            final trailer = _details!.videos.firstWhere((v) => v.site == 'YouTube' && v.type == 'Trailer');
                            return ConstrainedBox(
                               constraints: const BoxConstraints(maxWidth: 800),
                               child: TrailerPlayer(videoId: trailer.key),
                            );
                         }),
                         const SizedBox(height: 48),
                    ],

                    // --- Cast Section ---
                    if (_details?.cast.isNotEmpty ?? false) ...[
                    // ... existing cast section ... (omitting strict context match for brevity if needed, but here we replace block)
                    Text('Actors', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140, // Height for Cast Card
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _details!.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) => _CastCard(actor: _details!.cast[i], textColor: textColor, mutedColor: mutedTextColor),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // --- Reviews Section ---
                  if (_details?.reviews.isNotEmpty ?? false) ...[
                     Row(
                       children: [
                         Text('Reviews', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(width: 12),
                         Container(
                           padding: const EdgeInsets.all(6),
                           decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                           child: const Icon(Icons.rate_review, size: 12, color: Colors.white), 
                         ),
                       ],
                     ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _details!.reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) => _ReviewCard(review: _details!.reviews[i], textColor: textColor, mutedColor: mutedTextColor),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // --- Related Movies ---
                  if (_details?.recommendations.isNotEmpty ?? false) ...[
                    Text('Related Movies', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
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
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back, color: textColor), // Adaptive back button color
              style: IconButton.styleFrom(
                backgroundColor: baseColor.withOpacity(0.5), // Semi-transparent based on theme
                foregroundColor: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPoster(BuildContext context) {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeNetworkImage(url: _current.posterUrl, fit: BoxFit.cover),
    );
  }

  Widget _buildHeroDetails(BuildContext context, LibraryProvider library, PlaybackProvider playback, Color textColor, Color mutedColor) {
    final theme = Theme.of(context);
    final imdbId = _details?.externalIds['imdb'];
    final year = _current.year?.toString() ?? '';
    final runtime = _current.runtimeMinutes != null ? '${_current.runtimeMinutes}m' : '';
    final rating = _current.rating != null ? '${(_current.rating! * 10).toInt()}%' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _current.title ?? _current.fileName,
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        
        // Director / Meta
        // Placeholder for Director if not available, usually in credits crew
        Text(
          'Directed by Unknown', // We can fetch crew later if needed
          style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 12),
        
        // Technical Meta Row
        Row(
          children: [
            if (year.isNotEmpty) _SimpleTag(text: year, color: mutedColor),
            if (runtime.isNotEmpty) ...[const SizedBox(width: 12), _SimpleTag(text: runtime, color: mutedColor)],
            if (_current.isAdult) ...[const SizedBox(width: 12), const _SimpleTag(text: 'R', color: Colors.red)],
             // Genres
             const SizedBox(width: 12),
             Expanded(
               child: Text(
                 _current.genres.join(', '), 
                 style: TextStyle(color: mutedColor, fontSize: 13),
                 overflow: TextOverflow.ellipsis,
               ),
             ),
          ],
        ),
        const SizedBox(height: 20),

        // Ratings Row
        Row(
           children: [
             if (rating.isNotEmpty) ...[
               const Icon(Icons.thumb_up, color: Colors.redAccent, size: 20),
               const SizedBox(width: 6),
               Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(width: 8),
               Text('${_current.voteCount ?? "2.3k"} ratings', style: TextStyle(color: mutedColor.withOpacity(0.5), fontSize: 12)),
             ],
             if (imdbId != null) ...[
               const SizedBox(width: 24),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(color: const Color(0xFFF5C518), borderRadius: BorderRadius.circular(4)),
                 child: const Text('IMDb', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
               ),
             ],
           ],
        ),
        const SizedBox(height: 24),

        // Overview
        Text(
          _current.overview ?? 'No synopsis available.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontSize: 16,
            color: textColor.withOpacity(0.8),
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 32),

        // Action Buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), // Netflix/Youtube Red
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _current.filePath.isNotEmpty ? () {
                 debugPrint('MovieDetailsScreen: Play button pressed for ${_current.id}');
                 playback.start(_current);
                 Navigator.of(context).push(
                   MaterialPageRoute(
                     builder: (_) => VideoPlayerScreen(item: _current),
                   ),
                 );
              } : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_current.filePath.isNotEmpty ? 'Play Now' : 'Not Available'),
            ),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: mutedColor.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              icon: Icon(Icons.bookmark_border, color: textColor),
              label: Text('Watchlist', style: TextStyle(color: textColor)),
            ),

            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                fixedSize: const Size(60, 60), 
              ),
              onPressed: _details?.videos.isNotEmpty == true ? () async {
                  // Launch trailer externally or show dialog
                  final t = _details!.videos.firstWhereOrNull((v) => v.site == 'YouTube');
                  if (t != null) {
                    launchUrl(Uri.parse('https://www.youtube.com/watch?v=${t.key}'));
                  }
              } : null,
               icon: const Icon(Icons.smart_display_outlined),
            ),
             IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                fixedSize: const Size(60, 60),
              ),
              onPressed: () => _showMenu(context),
               icon: const Icon(Icons.more_vert),
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
    // Default color logic
    final defaultColor = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.white70;

    return Text(
      text,
      style: TextStyle(
        color: color ?? defaultColor, 
        fontWeight: FontWeight.w500,
        fontSize: 14
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  final CastMember actor;
  final Color textColor;
  final Color mutedColor;
  const _CastCard({required this.actor, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/actor/${actor.id}', extra: actor),
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
            Text(actor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(actor.character, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final TmdbReview review;
  final Color textColor;
  final Color mutedColor;
  const _ReviewCard({required this.review, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: review.avatarPath != null ? NetworkImage(review.avatarPath!) : null,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: review.avatarPath == null ? Text(review.author[0].toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer)) : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(review.author, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), maxLines: 1)),
              if (review.rating != null) ...[
                const Icon(Icons.star, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                Text(review.rating.toString(), style: TextStyle(color: textColor, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              review.content,
              style: TextStyle(color: mutedColor, fontSize: 12, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}





class _IdentifyDialog extends StatefulWidget {
  final MediaItem item;
  const _IdentifyDialog({required this.item});

  @override
  State<_IdentifyDialog> createState() => _IdentifyDialogState();
}

class _IdentifyDialogState extends State<_IdentifyDialog> {
  late TextEditingController _controller;
  List<TmdbItem> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title ?? widget.item.fileName);
    _search();
  }

  Future<void> _search() async {
    if (_controller.text.trim().isEmpty) return;
    
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final tmdb = context.read<TmdbService>();
      final results = await tmdb.searchMulti(_controller.text);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(TmdbItem match) async {
    setState(() => _loading = true);
    
    try {
      final meta = context.read<MetadataService>();
      final lib = context.read<LibraryProvider>();
      
      var updated = widget.item.copyWith(
         tmdbId: match.id,
         type: match.type == TmdbMediaType.movie ? MediaType.movie : MediaType.tv,
         title: match.title,
         overview: match.overview,
         posterUrl: match.posterUrl,
         backdropUrl: match.backdropUrl,
         year: match.releaseYear,
         isAnime: false,
      );
      
      updated = await meta.enrich(updated);
      await lib.updateItem(updated);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to update: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Text('Identify', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for Title...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white70),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null 
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                      : _results.isEmpty 
                          ? const Center(child: Text('No results found', style: TextStyle(color: Colors.white38)))
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                              itemBuilder: (ctx, i) {
                                final r = _results[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: r.posterUrl != null 
                                        ? Image.network(r.posterUrl!, width: 40, height: 60, fit: BoxFit.cover)
                                        : Container(width: 40, height: 60, color: Colors.grey[800]),
                                  ),
                                  title: Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${r.releaseYear ?? "Unknown"} • ${r.type == TmdbMediaType.movie ? "Movie" : "TV"}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  onTap: () => _select(r),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
