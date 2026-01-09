/// lib/screens/details/actor_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cast_member.dart';
import 'package:go_router/go_router.dart';
import '../../models/tmdb_person.dart';
import '../../models/tmdb_item.dart';
import '../../models/media_item.dart';
import '../../services/tmdb_service.dart';
import '../../services/stash_db_service.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/metadata_service.dart'; // Import MetadataService
import '../../models/stash_performer.dart';
import '../../widgets/discover_card.dart';
import 'package:url_launcher/url_launcher.dart';

class ActorDetailsScreen extends StatefulWidget {
  final String actorId;
  final CastMember? actor;

  const ActorDetailsScreen({super.key, required this.actorId, this.actor});

  @override
  State<ActorDetailsScreen> createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _perPage = 40;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  late CastMember _actor;
  TmdbPerson? _tmdbPerson;
  StashPerformer? _stashPerformer;
  List<TmdbItem> _tmdbMovies = [];
  List<TmdbItem> _tmdbShows = [];
  List<MediaItem> _localScenes = [];
  List<MediaItem> _remoteScenes = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && 
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadNextPage();
      }
    }
  }

  Future<void> _loadData() async {
      // 1. Resolve Actor
      if (widget.actor != null) {
          _actor = widget.actor!;
      } else {
          // Fetch actor by ID
          final id = widget.actorId;
          if (id.startsWith('stashdb:')) {
              // StashDB
               final settings = context.read<SettingsProvider>();
               final service = StashDbService();
               final realId = id.replaceFirst('stashdb:', '');
               final fetched = await service.getPerformer(realId, settings.stashEndpoints);
               
               if (fetched != null) {
                   _actor = fetched;
               } else {
                   _actor = CastMember(id: id, name: 'Unknown', character: '', source: CastSource.stashDb);
               }
          } else {
              // TMDB 
              final service = context.read<TmdbService>();
              final details = await service.getPersonDetails(id);
              
              if (details != null) {
                  _actor = CastMember(
                      id: id,
                      name: details.name,
                      character: 'Actor',
                      profileUrl: details.profilePath,
                      source: CastSource.tmdb,
                  );
                  _tmdbPerson = details;
              } else {
                  _actor = CastMember(id: id, name: 'Unknown', character: '', source: CastSource.tmdb);
              }
          }
      }

      if (mounted) setState(() {}); 
      if (mounted) setState(() {}); 
      await _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_actor.source == CastSource.tmdb) {
       // ... (TMDB logic unchanged) ...
       if (_tmdbPerson == null) {
          final service = context.read<TmdbService>();
          final details = await service.getPersonDetails(_actor.id);
          if (mounted) {
            setState(() {
              _tmdbPerson = details;
            });
          }
       }
       // ...
       if (mounted && _tmdbPerson != null) {
          final allCredits = List<TmdbItem>.from(_tmdbPerson!.knownFor);
          final movies = allCredits.where((i) => i.type == TmdbMediaType.movie).toList();
          final shows = allCredits.where((i) => i.type == TmdbMediaType.tv).toList();
          
          setState(() {
              _tmdbMovies = movies;
              _tmdbShows = shows;
              _isLoading = false;
          });
       } else if (mounted) {
          setState(() => _isLoading = false);
       }

    } else if (_actor.source == CastSource.aniList) {
        // AniList Logic
        if (_tmdbPerson == null) {
            final service = context.read<MetadataService>().aniListService;
            Map<String, dynamic>? data;
            int rawId = 0;

            if (_actor.id.startsWith('anilist_staff:')) {
               rawId = int.tryParse(_actor.id.replaceFirst('anilist_staff:', '')) ?? 0;
               data = await service.getPersonDetails(rawId);
            } else if (_actor.id.startsWith('anilist_char:')) {
               rawId = int.tryParse(_actor.id.replaceFirst('anilist_char:', '')) ?? 0;
               data = await service.getCharacterDetails(rawId);
            } else if (_actor.id.startsWith('anilist:')) {
               // Legacy fallback
               rawId = int.tryParse(_actor.id.replaceFirst('anilist:', '')) ?? 0;
               data = await service.getPersonDetails(rawId);
            }
            
            if (mounted && data != null) {
                // Map to TmdbPerson-like structure
                final name = data['name']?['full'] as String? ?? _actor.name;
                final image = data['image']?['large'] as String?;
                final bio = data['description'] as String?;
                final dob = data['dateOfBirth'];
                String? birthday;
                if (dob != null && dob['year'] != null) {
                    birthday = '${dob['year']}-${dob['month']}-${dob['day']}';
                }
                
                // Map Credits
                final shows = <TmdbItem>[];
                // characterMedia (Staff) or media (Character) -> nodes
                final nodes = (data['characterMedia']?['nodes'] as List<dynamic>?) 
                           ?? (data['media']?['nodes'] as List<dynamic>?) 
                           ?? [];
                
                for (var node in nodes) {
                    shows.add(TmdbItem(
                        id: node['id'],
                        title: node['title']?['english'] ?? node['title']?['romaji'] ?? '',
                        posterUrl: node['coverImage']?['large'],
                        type: TmdbMediaType.tv,
                        releaseYear: node['startDate']?['year'] as int?,
                    ));
                }

                setState(() {
                    _tmdbPerson = TmdbPerson(
                        id: rawId, // This is AniList ID, potentially conflicting with TMDB ID but scope is separated
                        name: name,
                        biography: bio,
                        birthday: birthday,
                        profilePath: image,
                        knownFor: shows, // Put all in knownFor
                    );
                    _tmdbShows = shows; // Populate Anime as Shows
                    _isLoading = false;
                });
            } else if (mounted) {
                 setState(() => _isLoading = false);
            }
        }
    } else {
      // StashDB
      if (_stashPerformer == null) {
         final settings = context.read<SettingsProvider>();
         final service = StashDbService();
         final rawId = _actor.id;
         final details = await service.getPerformerDetails(rawId, settings.stashEndpoints);
         
         if (mounted && details != null) {
             setState(() {
                _stashPerformer = details;
                // Update basic actor info if missing
                if (_actor.profileUrl == null && details.imageUrl != null) {
                   _actor = CastMember(
                      id: _actor.id, 
                      name: details.name, 
                      character: _actor.character, 
                      profileUrl: details.imageUrl,
                      source: _actor.source
                   );
                }
             });
         }
      }

      if (mounted) {
         final library = context.read<LibraryProvider>();
         final actorId = _actor.id;
         final actorName = _actor.name;

         final local = library.items.where((item) {
             return item.cast.any((c) => c.id == actorId || (c.id.isEmpty && c.name == actorName));
         }).toList();

         local.sort((a,b) => (b.year ?? 0).compareTo(a.year ?? 0));

         setState(() {
           _localScenes = local;
           _isLoading = local.isEmpty; 
         });
      }

      await _loadNextPage();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;
    if (_actor.source != CastSource.stashDb) return;
    
    setState(() => _isLoadingMore = true);

    try {
      final settings = context.read<SettingsProvider>();
      final service = StashDbService();
      
      final scenes = await service.getPerformerScenes(
          _actor.id, 
          settings.stashEndpoints,
          page: _currentPage,
          perPage: _perPage,
      );
      
      if (!mounted) return;

      if (scenes.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      
      final library = context.read<LibraryProvider>();
      final filtered = <MediaItem>[];
      
      for (final s in scenes) {
         final rawId = s.id.replaceFirst('stashdb:', '');
         final isLocal = library.items.any((l) => l.stashId == rawId);
         if (!isLocal) filtered.add(s);
      }

      setState(() {
        _remoteScenes.addAll(filtered);
        _currentPage++;
        if (scenes.length < _perPage) _hasMore = false;
        _isLoadingMore = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(
         backgroundColor: Colors.black,
         body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
       );
    }

    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final headerHeight = isDesktop ? 420.0 : 360.0;
    
    final name = _tmdbPerson?.name ?? _stashPerformer?.name ?? _actor.name;
    final bio = _tmdbPerson?.biography ?? _stashPerformer?.measurements ?? '';
    final profileUrl = _tmdbPerson?.profilePath ?? _stashPerformer?.imageUrl ?? _actor.profileUrl;
    
    String? backdropUrl;
    if (_tmdbMovies.isNotEmpty) backdropUrl = _tmdbMovies.first.backdropUrl;
    else if (_tmdbShows.isNotEmpty) backdropUrl = _tmdbShows.first.backdropUrl;
    else if (_localScenes.isNotEmpty) backdropUrl = _localScenes.first.backdropUrl;
    
    final heroImage = backdropUrl ?? profileUrl;
    final hasCounts = _localScenes.isNotEmpty || _remoteScenes.isNotEmpty || _tmdbMovies.isNotEmpty || _tmdbShows.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: headerHeight,
            pinned: true,
            backgroundColor: const Color(0xFF101010),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (heroImage != null)
                    Image.network(
                      heroImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(color: const Color(0xFF151515)),
                    )
                  else
                    Container(color: const Color(0xFF151515)),
                    
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.6),
                          const Color(0xFF101010),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 64.0 : 24.0, 
                        vertical: 28.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (profileUrl != null)
                             Container(
                               width: 170,
                               height: 240,
                               decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(12),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withOpacity(0.45),
                                     blurRadius: 18,
                                     offset: const Offset(0, 10),
                                   )
                                 ],
                               ),
                               child: ClipRRect(
                                 borderRadius: BorderRadius.circular(12),
                                 child: Image.network(
                                   profileUrl,
                                   fit: BoxFit.cover,
                                   errorBuilder: (_,__,___) => Container(color: Colors.grey[800]),
                                 ),
                               ),
                             ),

                          const SizedBox(width: 28),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                
                                Text(
                                  'Acting',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                if (bio.isNotEmpty)
                                  SizedBox(
                                    height: isDesktop ? null : 72,
                                    child: Text(
                                      bio,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                      maxLines: isDesktop ? 4 : 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                const SizedBox(height: 18),
                                
                                Row(
                                  children: [
                                    if (_tmdbPerson != null) _buildSocialRow(_tmdbPerson!.externalIds),
                                    const Spacer(),
                                    if (_tmdbPerson?.birthday != null) ...[
                                       _buildStatItem('Born', _tmdbPerson!.birthday!),
                                       const SizedBox(width: 20),
                                    ],
                                    if (_tmdbPerson?.deathDay != null) ...[
                                       _buildStatItem('Died', _tmdbPerson!.deathDay!),
                                       const SizedBox(width: 20),
                                    ],
                                  ],
                                ),
                                if (_stashPerformer != null)
                                   Padding(
                                     padding: const EdgeInsets.only(top: 14),
                                     child: _buildStashSocials(_stashPerformer!.urls),
                                   ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (hasCounts) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (_localScenes.isNotEmpty) _buildMetricChip(Icons.cloud_done, 'In Library', _localScenes.length),
                          if (_remoteScenes.isNotEmpty) _buildMetricChip(Icons.history_toggle_off, 'History', _remoteScenes.length),
                          if (_tmdbMovies.isNotEmpty) _buildMetricChip(Icons.movie, 'Movies', _tmdbMovies.length),
                          if (_tmdbShows.isNotEmpty) _buildMetricChip(Icons.tv, 'Shows', _tmdbShows.length),
                        ],
                      ),
                   ],

                   if (_stashPerformer != null) ...[
                      const SizedBox(height: 20),
                      _buildStashStatsCard(context, _stashPerformer!),
                   ],

                  if (_localScenes.isNotEmpty) ...[
                     const SizedBox(height: 44),
                     _buildSectionHeader('In Library', '${_localScenes.length} scenes'),
                     const SizedBox(height: 16),
                     _buildSceneGrid(_localScenes, true),
                  ],
                  
                  if (_remoteScenes.isNotEmpty) ...[
                     const SizedBox(height: 44),
                     _buildSectionHeader('History', 'From StashDB'),
                     const SizedBox(height: 16),
                     _buildSceneGrid(_remoteScenes, false),
                  ],

                  if (_tmdbMovies.isNotEmpty) ...[
                    const SizedBox(height: 44),
                    _buildSectionHeader('Movies', 'Acting'),
                    const SizedBox(height: 14),
                    _buildHorizontalList(_tmdbMovies),
                  ],

                  if (_tmdbShows.isNotEmpty) ...[
                    const SizedBox(height: 44),
                    _buildSectionHeader('Shows', 'Acting'),
                    const SizedBox(height: 14),
                    _buildHorizontalList(_tmdbShows),
                  ],

                  const SizedBox(height: 72),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? badge) {
    return Row(
      children: [
        // Minimize Icon
        if (badge != null && badge == 'Acting')
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.remove, size: 16, color: Colors.white54),
          ),
        Text(
          title, 
          style: const TextStyle(
             color: Colors.white, 
             fontSize: 20, 
             fontWeight: FontWeight.bold
          )
        ),
        if (badge != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
               color: Colors.blueAccent.withOpacity(0.2),
               borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge, 
              style: const TextStyle(
                color: Colors.blueAccent, 
                fontSize: 12, 
                fontWeight: FontWeight.bold
              )
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricChip(IconData icon, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List<TmdbItem> items) {
    // Responsive poster grid using max extent; auto-wraps with 2:3 aspect ratio.
    const targetWidth = 180.0; // poster-ish width
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: targetWidth,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 2 / 3,
      ),
      itemBuilder: (context, i) => DiscoverCard(item: items[i]),
    );
  }

  Widget _buildSceneGrid(List<MediaItem> scenes, bool isLocal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use maxCrossAxisExtent for responsive wrapping based on available width.
        const targetWidth = 260.0; // Acts like “max card width”; more space -> more columns.
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scenes.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: targetWidth,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            // More vertical room to avoid overflow when showing labels/text.
            childAspectRatio: 4 / 3,
          ),
          itemBuilder: (context, i) => _SceneCard(item: scenes[i], isLocal: isLocal),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    // Basic date parsing to prettify if needed, or just show raw
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  Widget _buildSocialRow(Map<String, String> ids) {
    return Row(
      children: [
        if (ids['facebook'] != null)
           _SocialIcon(icon: Icons.facebook, url: 'https://facebook.com/${ids['facebook']}'),
        if (ids['instagram'] != null)
           _SocialIcon(icon: Icons.camera_alt, url: 'https://instagram.com/${ids['instagram']}'),
        if (ids['twitter'] != null)
           _SocialIcon(icon: Icons.alternate_email, url: 'https://twitter.com/${ids['twitter']}'),
        if (ids['imdb'] != null)
           _ImdbIcon(id: ids['imdb']!),
      ],
    );
  }

  Widget _buildStashStatsCard(BuildContext context, StashPerformer p) {
      Widget row(String label, String value) {
         if (value.isEmpty) return const SizedBox.shrink();
         return Padding(
           padding: const EdgeInsets.symmetric(vertical: 4),
           child: Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               SizedBox(
                 width: 140, 
                 child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))
               ),
               Expanded(
                 child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))
               ),
             ],
           ),
         );
      }
      
      String? career;
      if (p.careerStartYear != null) {
          career = 'Active ${p.careerStartYear}';
          if (p.careerEndYear != null) career += '–${p.careerEndYear}';
          else career += '–';
      }

      final ageStr = p.birthdate != null ? '${p.birthdate}' : '';
      
      return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: const Color(0xFF1A1A1A),
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: Colors.white10),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              if (career != null) row('Career', career),
              row('Birthdate', ageStr),
              if (p.heightCm != null) row('Height', '${p.heightCm}cm'),
              if (p.measurements != null) row('Measurements', p.measurements!),
              if (p.breastType != null) row('Breast type', p.breastType!),
              if (p.country != null) row('Nationality', p.country!),
              if (p.ethnicity != null) row('Ethnicity', p.ethnicity!),
              if (p.eyeColor != null) row('Eye color', p.eyeColor!),
              if (p.hairColor != null) row('Hair color', p.hairColor!),
              if (p.tattoos.isNotEmpty) row('Tattoos', p.tattoos.join(', ')),
              if (p.piercings.isNotEmpty) row('Piercings', p.piercings.join(', ')),
              if (p.aliases.isNotEmpty) row('Aliases', p.aliases.join(', ')),
           ],
         ),
      );
  }

  Widget _buildStashSocials(Map<String, String> urls) {
     return Row(
       children: urls.entries.map((e) {
         IconData icon = Icons.link;
         if (e.key == 'twitter') icon = Icons.alternate_email;
         if (e.key == 'instagram') icon = Icons.camera_alt;
         // StashDB can have flexible keys
         return _SocialIcon(icon: icon, url: e.value);
       }).toList(),
     );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final String url;
  const _SocialIcon({required this.icon, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        tooltip: url,
      ),
    );
  }
}

class _ImdbIcon extends StatelessWidget {
  final String id;
  const _ImdbIcon({required this.id});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse('https://www.imdb.com/name/$id'), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF5C518),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('IMDb', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  final MediaItem item;
  final bool isLocal;
  const _SceneCard({required this.item, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         if (item.id.startsWith('stashdb:')) {
            final rawId = item.id.replaceFirst('stashdb:', '');
            context.push('/scene/$rawId', extra: item);
         } else {
            context.push('/media/${item.id}', extra: item);
         }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16/9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.posterUrl != null || item.backdropUrl != null)
                    Image.network(item.posterUrl ?? item.backdropUrl!, fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(color: Colors.grey[900]))
                  else
                    Container(color: Colors.grey[900]),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLocal ? Colors.green.withOpacity(0.85) : Colors.blueAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLocal ? 'In Library' : 'StashDB',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              item.title ?? item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.year?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
