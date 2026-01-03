import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/tmdb_episode.dart';
import '../../models/tmdb_extended_details.dart';
import '../../providers/library_provider.dart';
import '../../services/metadata_service.dart';
import '../../services/tmdb_service.dart';
import '../../widgets/safe_network_image.dart';
import 'episode_details_screen.dart';

class AnimeDetailsScreen extends StatefulWidget {
  final MediaItem item;
  const AnimeDetailsScreen({super.key, required this.item});

  @override
  State<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends State<AnimeDetailsScreen> with SingleTickerProviderStateMixin {
  late MediaItem _current;
  TmdbExtendedDetails? _details;
  
  // Data
  List<TmdbEpisode> _episodes = [];
  List<MediaItem> _localEpisodes = [];
  
  // State
  bool _loadingEpisodes = false;
  int _selectedSeason = 1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _tabController = TabController(length: 4, vsync: this);
    _loadDetails();
    _loadEpisodes(_selectedSeason); // Initial load
  }

  @override 
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final meta = context.read<MetadataService>();
    final tmdb = context.read<TmdbService>();

    TmdbExtendedDetails? details;

    // 1. Try AniList
    if (_current.anilistId != null) {
       details = await meta.aniListService.getDetails(_current.anilistId!);
    }
    
    // 2. Fallback TMDB
    if (details == null && _current.tmdbId != null) {
       details = await tmdb.getExtendedDetails(_current.tmdbId!, _current.type);
    }
    
    if (mounted) setState(() => _details = details);
  }

  Future<void> _loadEpisodes(int season) async {
    if (_current.tmdbId == null && _current.anilistId == null) return;
    
    setState(() {
      _loadingEpisodes = true;
      _selectedSeason = season;
    });

    final meta = context.read<MetadataService>();
    final tmdb = context.read<TmdbService>();
    
    List<TmdbEpisode> eps = [];
    
    // 1. Try AniList
    if (_current.isAnime && _current.anilistId != null) {
       eps = await meta.aniListService.getEpisodes(_current.anilistId!);
       // AniList usually returns ALL episodes flattened. We might need to filter manually if they have season metadata,
       // BUT usually AniList treats each Season as a separate Media ID. 
       // If this is a "Series" entry mapping to multiple TMDB seasons, we rely on the TMDB logic mainly for multi-season consistency
       // unless AniList structure changes.
       
       // For now, if we get episodes from AniList, we might assume they occupy "Season 1" relative to THAT ID, 
       // or we just trust the provider implementation.
    }
    
    // 2. Fallback TMDB (Standard Multi-Season)
    if (eps.isEmpty && _current.tmdbId != null) {
       eps = await tmdb.getSeasonEpisodes(_current.tmdbId!, season);
    }

    // 3. Match with Local Files
    final library = context.read<LibraryProvider>();
    final localItems = library.items.where((i) {
       if (_current.isAnime && _current.anilistId != null && i.anilistId != null) {
         return i.anilistId == _current.anilistId;
       }
       if (i.type != MediaType.tv && !i.isAnime) return false;
       return i.tmdbId == _current.tmdbId;
    }).toList();

    // Filter available
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

  void _playEpisode(TmdbEpisode ep) {
    MediaItem? matchedFile;
    try {
      matchedFile = _localEpisodes.firstWhere(
        (e) => e.season == ep.seasonNumber && e.episode == ep.episodeNumber,
      );
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EpisodeDetailsScreen(
          episode: ep,
          showTitle: _current.title ?? _current.fileName,
          matchedFile: matchedFile,
          playlist: _localEpisodes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1622), // Deep dark blue/black like AniList dark mode
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Hero Banner
          Positioned(
            top: 0, left: 0, right: 0,
            height: 380,
            child: _current.backdropUrl != null 
                ? SafeNetworkImage(url: _current.backdropUrl, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          
          // 2. Gradient Overlay (Top & Bottom of Hero)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    const Color(0xFF0B1622), // Fade to bg
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main Scrollable Content
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                // Nav Bar Placeholder (Back Button)
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent, // Let content scroll behind, or glassmorphism?
                  shadowColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  expandedHeight: 0, // Just a toolbar
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.black.withOpacity(0.2)),
                    ),
                  ),
                ),

                // Content Body
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48.0 : 16.0,
                    ),
                    child: isDesktop 
                        ? _buildDesktopLayout(theme) 
                        : _buildMobileLayout(theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      margin: const EdgeInsets.only(top: 200), // Push down to reveal banner
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LEFT SIDEBAR ---
          SizedBox(
            width: 260,
            child: Column(
              children: [
                // Poster
                Container(
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _current.posterUrl != null 
                    ? SafeNetworkImage(url: _current.posterUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey[900], child: const Icon(Icons.movie, size: 50, color: Colors.white24)),
                ),
                const SizedBox(height: 24),
                
                // Actions
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      // Resume logic: Find first unwatched or S1E1
                      if (_episodes.isNotEmpty) {
                        _playEpisode(_episodes.first); 
                      }
                    }, 
                    child: const Text('Resume S1 E1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      // Play S1E1 specific
                       if (_episodes.isNotEmpty) {
                        _playEpisode(_episodes.first); 
                      }
                    },
                    child: const Text('Start Watching'),
                  ),
                ),

                const SizedBox(height: 32),
                
                // Stats List
                _buildStatRow('Format', _current.type == MediaType.tv ? 'TV Show' : 'Movie'),
                _buildStatRow('Episodes', '${_details?.numberOfEpisodes ?? "?"}'),
                _buildStatRow('Status', _details?.status ?? "Unknown"),
                _buildStatRow('Season', 'Spring ${_current.year ?? 2024}'),
                _buildStatRow('Average Score', '${((_current.rating ?? 0) * 10).round()}%'),
              ],
            ),
          ),
          
          const SizedBox(width: 48),

          // --- RIGHT MAIN CONTENT ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Text(
                  _current.title ?? _current.fileName,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    if (_current.year != null) 
                      Text('${_current.year}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                     Text('•', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16)),
                    if (_details?.genres.isNotEmpty ?? false)
                       Text(_details!.genres.take(3).map((g) => g.name).join(', '), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                
                const SizedBox(height: 32),

                // Tabs
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  dividerColor: Colors.transparent,
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Watch'),
                    Tab(text: 'Characters'),
                    Tab(text: 'Staff'),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Tab Views (Using SizedBox to constrain height? No, inside Column we need standard widgets)
                // We'll just show content based on index or use a customized builder since we are in a sliver? 
                // Since tab view usually wants expanded height, we can simulate it with AnimatedBuilder or just simple conditional since it's desktop
                
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (ctx, _) {
                     switch(_tabController.index) {
                       case 0: return _buildOverviewTab(theme);
                       case 1: return _buildWatchTab(theme);
                       case 2: return _buildCharactersTab(theme);
                       default: return _buildOverviewTab(theme);
                     }
                  }
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    // Simplified Stack for Mobile
    return Column(
      children: [
        // Content pushed down by header
        const SizedBox(height: 280), 
        
        // Poster & Title Block
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 120, height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
              ),
              clipBehavior: Clip.antiAlias,
              child: _current.posterUrl != null 
                  ? SafeNetworkImage(url: _current.posterUrl, fit: BoxFit.cover)
                  : Container(color: Colors.grey[800]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    _current.title ?? _current.fileName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () { 
                      if (_episodes.isNotEmpty) _playEpisode(_episodes.first); 
                    }, 
                    icon: const Icon(Icons.play_arrow, size: 18), 
                    label: const Text('Play')
                  )
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Tab Bar
        TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Watch'), Tab(text: 'Char.')],
        ),
        
         const SizedBox(height: 16),

         AnimatedBuilder(
            animation: _tabController,
            builder: (ctx, _) {
               switch(_tabController.index) {
                 case 0: return _buildOverviewTab(theme);
                 case 1: return _buildWatchTab(theme);
                 case 2: return _buildCharactersTab(theme);
                 default: return _buildOverviewTab(theme);
               }
            }
         ),
         
         const SizedBox(height: 64),
      ],
    );
  }

  // --- TAB CONTENT ---

  Widget _buildOverviewTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        Text(
          (_current.overview ?? "")
            .replaceAll(RegExp(r'<[^>]*>'), ''), // Strip HTML
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF9FADBD), // AniList text color
            height: 1.6,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Relations (Seasons)
        if (_details?.seasons.isNotEmpty ?? false) ...[
          Text('Relations', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _details!.seasons.length,
              separatorBuilder: (_,__) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                 final s = _details!.seasons[i];
                 if (s.seasonNumber == 0) return const SizedBox.shrink(); // Skip specials usually?
                 return Container(
                   width: 85,
                   decoration: BoxDecoration(color: const Color(0xFF151F2E), borderRadius: BorderRadius.circular(4)), // AniList card bg
                   child: Column(
                     children: [
                       Expanded(
                         child: s.posterPath != null 
                             ? SafeNetworkImage(url: "https://image.tmdb.org/t/p/w200${s.posterPath}", fit: BoxFit.cover)
                             : Container(color: Colors.white10),
                       ),
                       Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Text("Season ${s.seasonNumber}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                       )
                     ],
                   ),
                 );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWatchTab(ThemeData theme) {
    final seasons = _details?.seasons.where((s) => s.seasonNumber > 0).toList() ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season Selector (Pills)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: seasons.map((s) {
              final isSelected = s.seasonNumber == _selectedSeason;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  label: Text('Season ${s.seasonNumber}'),
                  selected: isSelected,
                  onSelected: (_) => _loadEpisodes(s.seasonNumber),
                  backgroundColor: const Color(0xFF151F2E),
                  selectedColor: theme.colorScheme.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF9FADBD),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 24),

        // Episodes Grid
        if (_loadingEpisodes)
          const Center(child: CircularProgressIndicator())
        else if (_episodes.isEmpty)
           const Text('No episodes available for this season.', style: TextStyle(color: Colors.white54))
        else
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 1 : 4,
                  childAspectRatio: 16/9,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _episodes.length,
                itemBuilder: (ctx, i) {
                  final ep = _episodes[i];
                  return _buildAnimeEpisodeCard(ep);
                },
              );
            }
          ),
      ],
    );
  }

  Widget _buildCharactersTab(ThemeData theme) {
     final cast = (_details?.cast ?? _current.cast).take(12).toList();
     if (cast.isEmpty) return const Text('No cast info.', style: TextStyle(color: Colors.white54));
     
     return GridView.builder(
       shrinkWrap: true,
       physics: const NeverScrollableScrollPhysics(),
       gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent: 400, // Wider for split view
         childAspectRatio: 3, 
         crossAxisSpacing: 16,
         mainAxisSpacing: 16,
       ),
       itemCount: cast.length,
       itemBuilder: (ctx, i) {
         final actor = cast[i];
         // Split Card Design
         // Left: Character Image + Name/Role
         // Right: Actor Name/Lang + Actor Image
         
         return Container(
           decoration: BoxDecoration(
             color: const Color(0xFF151F2E),
             borderRadius: BorderRadius.circular(4),
           ),
           clipBehavior: Clip.antiAlias,
           child: Row(
             children: [
               // --- LEFT: CHARACTER ---
               if (actor.characterImageUrl != null)
                 Image.network(actor.characterImageUrl!, width: 60, height: double.infinity, fit: BoxFit.cover)
               else
                 Container(width: 60, color: Colors.white10),
                 
               const SizedBox(width: 12),
               
               Expanded(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(actor.character, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                     Text(actor.role ?? 'Main', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                   ],
                 ),
               ),
               
               const SizedBox(width: 8),
               
               // --- RIGHT: ACTOR ---
               Expanded(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text(actor.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                     const Text('Japanese', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.right),
                   ],
                 ),
               ),
               
               const SizedBox(width: 12),
               
               if (actor.profileUrl != null)
                 Image.network(actor.profileUrl!, width: 60, height: double.infinity, fit: BoxFit.cover)
               else
                 Container(width: 60, color: Colors.white10),
             ],
           ),
         );
       },
     );
  }
  
  Widget _buildAnimeEpisodeCard(TmdbEpisode ep) {
    final isAvailable = _localEpisodes.any(
      (e) => e.season == ep.seasonNumber && e.episode == ep.episodeNumber
    );
    
    return InkWell(
      onTap: () => _playEpisode(ep),
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumb
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ep.stillPath != null 
                ? SafeNetworkImage(url: "https://image.tmdb.org/t/p/w400${ep.stillPath}", fit: BoxFit.cover)
                : Container(color: Colors.white10, child: const Icon(Icons.image, color: Colors.white24)),
          ),
          
          // Hover Overlay (Always visible gradient for readability)
          Container(
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(8),
               gradient: const LinearGradient(
                 colors: [Colors.transparent, Colors.black87],
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
               ),
             ),
          ),
          
          // Info
          Positioned(
            left: 12, bottom: 12, right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ep ${ep.episodeNumber}", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
                Text(
                  ep.name, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)
                ),
              ],
            ),
          ),
          
          // Status Indicator
          if (!isAvailable)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off, size: 14, color: Colors.white54),
              ),
            ),
            
          // Hover Play Icon (Simulated active)
          Center(
             child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w500)),
           Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
