import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/tmdb_item.dart';
import '../../models/tmdb_episode.dart';
import '../../providers/library_provider.dart';
import '../../providers/playback_provider.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/safe_network_image.dart';
import '../video_player_screen.dart';
import 'episode_details_screen.dart';
import '../../services/metadata_service.dart';
import '../../models/tmdb_extended_details.dart';

class TvDetailsScreen extends StatefulWidget {
  final MediaItem item;
  const TvDetailsScreen({super.key, required this.item});

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen> {
  late MediaItem _current;
  TmdbExtendedDetails? _details;
  List<TmdbEpisode> _episodes = [];
  List<MediaItem> _localEpisodes = [];
  int _selectedSeason = 1;
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _loadDetails();
    _loadEpisodes(_selectedSeason);
  }

  Future<void> _loadDetails() async {
    final meta = context.read<MetadataService>();
    final tmdb = context.read<TmdbService>();

    TmdbExtendedDetails? details;

    if (_current.isAnime && _current.anilistId != null) {
       details = await meta.aniListService.getDetails(_current.anilistId!);
    }
    
    // Fallback to TMDB if AniList failed or not applicable
    if (details == null && _current.tmdbId != null) {
       details = await tmdb.getExtendedDetails(_current.tmdbId!, _current.type);
    }
    
    if (mounted) setState(() => _details = details);
  }

  Future<void> _loadEpisodes(int season) async {
    // Need at least one ID
    if (_current.tmdbId == null && _current.anilistId == null) return;
    
    setState(() {
      _loadingEpisodes = true;
      _selectedSeason = season;
    });

    final meta = context.read<MetadataService>();
    final tmdb = context.read<TmdbService>();
    
    List<TmdbEpisode> eps = [];
    
    // Prefer AniList if available and it's Anime
    if (_current.isAnime && _current.anilistId != null) {
       eps = await meta.aniListService.getEpisodes(_current.anilistId!);
    }
    
    if (eps.isEmpty && _current.tmdbId != null) {
       eps = await tmdb.getSeasonEpisodes(_current.tmdbId!, season);
    }

    // Filter to only show locally available episodes
    final library = context.read<LibraryProvider>();
    final localItems = library.items.where((i) {
       // For anime, match by anilistId if available
       if (_current.isAnime && _current.anilistId != null && i.anilistId != null) {
         return i.anilistId == _current.anilistId;
       }
       return i.tmdbId == _current.tmdbId;
    }).toList();

    final availableEps = eps.where((tmdbEp) {
      return localItems.any((localEp) => 
        localEp.season == tmdbEp.seasonNumber && 
        localEp.episode == tmdbEp.episodeNumber
      );
    }).toList();

    if (mounted) {
      setState(() {
        _episodes = availableEps;
        _localEpisodes = localItems;
        _loadingEpisodes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Backdrop
          Positioned.fill(
            child: _current.backdropUrl != null 
                ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover) 
                : Container(color: Colors.black),
          ),
          
          // Heavy Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
            ),
          ),

          // Content
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                // AppBar Back Button Area
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
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
                    const SizedBox(width: 8),
                  ],
                  expandedHeight: size.height * 0.4,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(color: Colors.transparent), // Shows backdrop through
                  ),
                ),

                // Title and Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _current.title ?? _current.fileName,
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                             _MetaTag(text: '${_current.year ?? ""}', icon: Icons.calendar_today),
                             const SizedBox(width: 12),
                             _MetaTag(text: '${_current.rating ?? ""}', icon: Icons.star, color: Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Overview
                        Text(
                          _current.overview ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Season Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seasons', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _details?.seasons.length ?? 0, 
                            separatorBuilder: (_,__) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final season = _details!.seasons[i];
                              final isSelected = season.seasonNumber == _selectedSeason;
                              return ChoiceChip(
                                label: Text(season.name.isNotEmpty ? season.name : 'Season ${season.seasonNumber}'),
                                selected: isSelected,
                                onSelected: (_) => _loadEpisodes(season.seasonNumber),
                                selectedColor: theme.colorScheme.primary,
                                labelStyle: TextStyle(color: isSelected ? theme.colorScheme.onPrimary : Colors.white),
                                backgroundColor: Colors.white12,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                showCheckmark: false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Episode Grid Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Episodes', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                        Text('${_episodes.length} Episodes • Season $_selectedSeason', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),

                // Episodes Grid
                if (_loadingEpisodes)
                  const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_episodes.isEmpty)
                  const SliverToBoxAdapter(
                     child: Padding(
                       padding: EdgeInsets.all(48),
                       child: Text('No episodes found.', style: TextStyle(color: Colors.white54)),
                     ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 350,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 16/9, // Card Aspect Ratio
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final ep = _episodes[i];
                          // Check availability
                          final isAvailable = _current.episodes.any(
                            (e) => e.season == ep.seasonNumber && e.episode == ep.episodeNumber
                          );
                          
                          return _EpisodeCard(
                            episode: ep,
                            isAvailable: isAvailable,
                            onTap: () => _playEpisode(ep),
                          );
                        },
                        childCount: _episodes.length,
                      ),
                    ),
                  ),
                  
                const SliverPadding(padding: EdgeInsets.only(bottom: 64)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _playEpisode(TmdbEpisode ep) {
    MediaItem? match;
    try {
      match = _localEpisodes.firstWhere(
        (e) => e.season == ep.seasonNumber && e.episode == ep.episodeNumber,
      );
    } catch (_) {
      // No match found
    }

    // Create a temporary MediaItem to pass if matched
    MediaItem? mediaMatch = match;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpisodeDetailsScreen(
          episode: ep,
          showTitle: _current.title ?? _current.fileName,
          matchedFile: mediaMatch,
          playlist: _localEpisodes, // Pass context for later
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final TmdbEpisode episode;
  final bool isAvailable;
  final VoidCallback onTap;
  
  const _EpisodeCard({
    required this.episode,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Thumbnail
            Positioned.fill(
              child: episode.stillPath != null
                  ? SafeNetworkImage(url: episode.stillPath, fit: BoxFit.cover)
                  : Container(color: Colors.black26, child: const Icon(Icons.tv, color: Colors.white12, size: 48)),
            ),
            
            // Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Hover/Play Hint
            Positioned.fill(
              child: Center(
                child: Icon(
                  isAvailable ? Icons.play_circle_outline : Icons.cancel_outlined,
                  color: Colors.white.withOpacity(0.5), 
                  size: 48
                ),
              ),
            ),

            // Unavailable Overlay
            if (!isAvailable)
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Colors.redAccent),
                  ),
                ),
              ),

            // Text Info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${episode.episodeNumber}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          episode.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (episode.overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.overview,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
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
