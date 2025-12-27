/// lib/screens/details/movie_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/media_item.dart';
import '../../models/tmdb_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../services/tmdb_service.dart';
import '../../models/tmdb_extended_details.dart';
import '../../widgets/discover_card.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import 'actor_details_screen.dart';
import '../../models/cast_member.dart';

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
      await _player.setVolume(0); 
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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_muted ? 'Muted' : 'Unmuted'),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          // 1. Trailer / Backdrop Background
          Positioned.fill(
            child: _trailerLoading || _player.state.width == null
                ? (_current.backdropUrl != null 
                    ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover) 
                    : Container(color: baseColor))
                : Video(controller: _controller, fit: BoxFit.cover, controls: NoVideoControls),
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
                  
                  // --- Cast Section ---
                  if (_details?.cast.isNotEmpty ?? false) ...[
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

                  // --- Extras (Trailers) Section ---
                  if (_details?.videos.isNotEmpty ?? false) ...[
                     Text('Extras', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 16),
                     SizedBox(
                       height: 140,
                       child: ListView.separated(
                         scrollDirection: Axis.horizontal,
                         itemCount: _details!.videos.where((v) => v.site == 'YouTube').length,
                         separatorBuilder: (_, __) => const SizedBox(width: 16),
                         itemBuilder: (ctx, i) {
                           final vid = _details!.videos.where((v) => v.site == 'YouTube').elementAt(i);
                           return _TrailerCard(video: vid, textColor: textColor);
                         }
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

          // Mute Toggle (Top Right)
          if (!_trailerLoading)
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(
                onPressed: _toggleMute,
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: textColor),
                 style: IconButton.styleFrom(
                  backgroundColor: baseColor.withOpacity(0.5),
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
              onPressed: () {
                // More options
              },
               icon: const Icon(Icons.more_vert),
            ),
          ],
        ),

        // Sentiment / Quote / Tagline
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF651F1F).withOpacity(0.3), // Dark red tint
            border: Border(left: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sentiment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      'Engaging soundtrack and score. Vivid visuals and atmosphere.', // Static placeholder
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _TrailerCard extends StatelessWidget {
  final TmdbVideo video;
  final Color textColor;
  const _TrailerCard({required this.video, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=${video.key}')),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SafeNetworkImage(
                      url: 'https://img.youtube.com/vi/${video.key}/hqdefault.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 12)),
            const Text('YouTube', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
