/// lib/screens/details/actor_details_screen.dart
import 'dart:math';
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
import '../../widgets/discover_card.dart';
import '../../widgets/safe_network_image.dart';
import '../details_screen.dart';

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
  List<TmdbItem> _tmdbCredits = [];
  List<MediaItem> _localScenes = [];
  List<MediaItem> _remoteScenes = [];

   Widget _buildSceneCard(BuildContext context, MediaItem item, bool isLocal) {
      final imageUrl = item.backdropUrl ?? item.posterUrl;
      
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
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Expanded(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(12),
               child: Stack(
                 children: [
                    if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover, 
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_,__,___) => Container(color: Colors.grey[900]),
                      )
                    else 
                      Container(color: Colors.grey[900]),
                      
                    if (isLocal)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ),
                 ],
               ),
             ),
           ),
           const SizedBox(height: 6),
           Text(
             item.title ?? item.fileName,
             maxLines: 2,
             overflow: TextOverflow.ellipsis,
             style: const TextStyle(color: Colors.white, fontSize: 12),
           ),
         ],
       ),
     );
  }

// ...



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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
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
               // Extract real ID
               final realId = id.replaceFirst('stashdb:', '');
               final fetched = await service.getPerformer(realId, settings.stashApiKey, settings.stashUrl);
               
               if (fetched != null) {
                   _actor = fetched;
               } else {
                   // Failed to fetch, set dummy
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

      if (mounted) {
         setState(() {}); 
      }

      await _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_actor.source == CastSource.tmdb) {
      // TMDB
      if (_tmdbPerson == null) {
          final service = context.read<TmdbService>();
          final details = await service.getPersonDetails(_actor.id);
          if (mounted) {
            setState(() {
              _tmdbPerson = details;
            });
          }
      }
      
      if (mounted && _tmdbPerson != null) {
        setState(() {
            _tmdbCredits = List.from(_tmdbPerson!.knownFor);
            _tmdbCredits.shuffle(Random());
            _isLoading = false;
        });
      } else if (mounted) {
         setState(() => _isLoading = false);
      }
    } else {
      // StashDB
      
      // 1. Load Local Scenes Immediately
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

      // 2. Load First Page of Remote
      await _loadNextPage();
      
      if (mounted) {
        setState(() {
          _isLoading = false; 
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;
    
    // Safety check if actor is loaded
    if (_actor.source != CastSource.stashDb) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final settings = context.read<SettingsProvider>();
      final service = StashDbService();
      
      final scenes = await service.getPerformerScenes(
          _actor.id, 
          settings.stashApiKey, 
          settings.stashUrl,
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
      
      // Filter out scenes that are already in _localScenes to avoid dupes in "Remote" list
      // (Optional, but requested implication of "local vs remote")
      final library = context.read<LibraryProvider>();
      final filtered = <MediaItem>[];
      
      for (final s in scenes) {
         // Check if s.id (stashdb:ID) corresponds to any item in library
         // Library items have stashId property if enriched.
         final rawId = s.id.replaceFirst('stashdb:', '');
         final isLocal = library.items.any((l) => l.stashId == rawId);
         
         if (!isLocal) {
           filtered.add(s);
         }
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
          _hasMore = false; // Stop on error to avoid loop?
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If loading, show spinner (wrapped in Scaffold to handle back button)
    if (_isLoading) {
       return Scaffold(
         backgroundColor: Colors.black,
         appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
         ),
         body: const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
       );
    }

    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final library = context.watch<LibraryProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final name = _tmdbPerson?.name ?? _actor.name;
    final bio = _tmdbPerson?.biography;
    final profileUrl = _tmdbPerson?.profilePath ?? _actor.profileUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  SizedBox(
                    height: 400,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image (Blurred Profile)
                        if (profileUrl != null)
                          Image.network(
                            profileUrl,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.6),
                            colorBlendMode: BlendMode.darken,
                            errorBuilder: (_,__,___) => Container(color: Colors.black),
                          ),
                        // Gradient
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                              stops: [0.6, 1.0],
                            ),
                          ),
                        ),
                        // Content
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Profile Image
                                Container(
                                  width: 120,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black54)],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: profileUrl != null
                                        ? Image.network(
                                            profileUrl, 
                                            fit: BoxFit.cover,
                                            errorBuilder: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.person, size: 64, color: Colors.white54)),
                                          )
                                        : Container(color: Colors.grey[800], child: const Icon(Icons.person, size: 64, color: Colors.white54)),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Text Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.displaySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_tmdbPerson != null) ...[
                                        const SizedBox(height: 8),
                                        if (_tmdbPerson!.birthday != null)
                                          Text(
                                            'Born: ${_tmdbPerson!.birthday}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        if (_tmdbPerson!.placeOfBirth != null)
                                          Text(
                                            'Place: ${_tmdbPerson!.placeOfBirth}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                      ],
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

                  // Biography
                  if (bio != null && bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Biography',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            bio,
                            style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 16),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                  // Known For (Randomized)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      _actor.source == CastSource.stashDb ? '' : 'Known For',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  if (_actor.source == CastSource.tmdb)
                     SizedBox(
                      height: 280,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: _tmdbCredits.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) => DiscoverCard(item: _tmdbCredits[i]),
                      ),
                    )
                  else
                  // SECTION 1: Local Scenes
                  if (_actor.source == CastSource.stashDb && _localScenes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        'In Library',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        childAspectRatio: 16 / 9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _localScenes.length,
                      itemBuilder: (ctx, i) => _buildSceneCard(ctx, _localScenes[i], true),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // SECTION 2: Remote Scenes
                  if (_actor.source == CastSource.stashDb && _remoteScenes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        _localScenes.isEmpty ? 'Scenes' : 'More Scenes',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        childAspectRatio: 16 / 9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _remoteScenes.length,
                      itemBuilder: (ctx, i) => _buildSceneCard(ctx, _remoteScenes[i], false),
                    ),
                  ],
                  
                  if (_tmdbCredits.isEmpty && _localScenes.isEmpty && _remoteScenes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text("No known works found.", style: TextStyle(color: Colors.white30)),
                    ),
                  // Loading More Spinner
                  if (_isLoadingMore)
                     const Padding(
                       padding: EdgeInsets.all(24.0),
                       child: Center(
                         child: SizedBox(
                           width: 24, height: 24, 
                           child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                         ),
                       ),
                     ),
                ],
              ),
            ),
          );
  }
}
