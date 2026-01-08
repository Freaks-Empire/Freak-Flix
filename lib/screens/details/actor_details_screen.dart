/// lib/screens/details/actor_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../models/cast_member.dart';
import '../../models/media_item.dart';
import '../../models/stash_performer.dart';
import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/tmdb_service.dart';
import '../../services/stash_db_service.dart';
import '../player/player_screen.dart';
import '../details/details_screen.dart';

class ActorDetailsScreen extends StatefulWidget {
  final CastMember actor;
  final String heroTag;

  const ActorDetailsScreen({
    super.key,
    required this.actor,
    required this.heroTag,
  });

  @override
  State<ActorDetailsScreen> createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen> {
  bool _isLoading = true;
  StashPerformer? _stashDetails;
  Map<String, dynamic>? _tmdbDetails;
  
  // Lists
  List<MediaItem> _libraryItems = []; // Scenes found in local library
  List<MediaItem> _historyItems = []; // Watched items from history
  List<Map<String, dynamic>> _tmdbMovies = [];
  List<Map<String, dynamic>> _tmdbShows = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final settings = context.read<SettingsProvider>();
    final library = context.read<LibraryProvider>();
    final stash = StashDbService();
    final tmdb = TmdbService(settings);

    try {
      // 1. Fetch Details (StashDB or TMDB)
      if (settings.enableAdultContent && settings.stashEndpoints.any((e) => e.enabled)) {
         // Attempt Stash Search by Name first if ID missing or strictly adult context
         // If widget.actor.id is empty or from TMDB, we might need to search Stash by name?
         // StashDbService needs a searchPerformerByName really.
         // For now, assume if source is StashDb, ID is valid.
         if (widget.actor.source == CastSource.stashDb && widget.actor.id.isNotEmpty) {
            _stashDetails = await stash.getPerformerDetails(widget.actor.id, settings.stashEndpoints);
         }
      }

      if (_stashDetails == null && settings.hasTmdbKey) {
         // Fallback to TMDB
         // If we have an ID and it's TMDB source:
         if (widget.actor.source == CastSource.tmdb && widget.actor.id.isNotEmpty) {
             final id = int.tryParse(widget.actor.id);
             if (id != null) {
                _tmdbDetails = await tmdb.getPersonDetails(id);
                if (_tmdbDetails != null) {
                   final combined = await tmdb.getPersonCredits(id);
                   _tmdbMovies = List<Map<String, dynamic>>.from(combined['cast'] ?? [])
                       .where((x) => x['media_type'] == 'movie')
                       .toList();
                   _tmdbShows = List<Map<String, dynamic>>.from(combined['cast'] ?? [])
                       .where((x) => x['media_type'] == 'tv')
                       .toList();
                }
             }
         } else {
             // Search TMDB by name?
             final search = await tmdb.searchPerson(widget.actor.name);
             if (search != null) {
                final id = search['id'] as int;
                _tmdbDetails = await tmdb.getPersonDetails(id);
                 final combined = await tmdb.getPersonCredits(id);
                   _tmdbMovies = List<Map<String, dynamic>>.from(combined['cast'] ?? [])
                       .where((x) => x['media_type'] == 'movie')
                       .toList();
                   _tmdbShows = List<Map<String, dynamic>>.from(combined['cast'] ?? [])
                       .where((x) => x['media_type'] == 'tv')
                       .toList();
             }
         }
      }
      
      // 2. Local Library Matches
      // Match by Name (simple normalization)
      final normName = widget.actor.name.toLowerCase().trim();
      _libraryItems = library.items.where((item) {
          return item.cast.any((c) => c.name.toLowerCase().trim() == normName);
      }).toList();

      // 3. History Matches (from library items that are watched)
      _historyItems = _libraryItems.where((i) => i.isWatched || i.lastPositionSeconds > 0).toList();

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint('Error fetching actor details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use stash details if available, else TMDB, else basic info
    final name = _stashDetails?.name ?? _tmdbDetails?['name'] ?? widget.actor.name;
    final bio = _stashDetails?.details ?? _tmdbDetails?['biography'] ?? '';
    final image = _stashDetails?.imagePath ?? 
                  (_tmdbDetails?['profile_path'] != null 
                      ? 'https://image.tmdb.org/t/p/w500${_tmdbDetails!['profile_path']}' 
                      : widget.actor.profileUrl);
    
    // Stats
    final birth = _stashDetails?.birthdate ?? _tmdbDetails?['birthday'];
    final death = _tmdbDetails?['deathday'];
    final place = _stashDetails?.country ?? _tmdbDetails?['place_of_birth'];
    
    // Stash Specific
    final measurements = _stashDetails?.measurements;
    final cups = _stashDetails?.fakeTits ?? '';
    final career = _stashDetails != null 
        ? '${_stashDetails!.careerStartYear ?? '?'} - ${_stashDetails!.careerEndYear ?? 'Present'}'
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(name, image),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickMetrics(),
                        const SizedBox(height: 16),
                        _buildBio(bio),
                        const SizedBox(height: 16),
                        _buildInfoGrid(birth, death, place, measurements, cups, career),
                        const SizedBox(height: 24),
                        
                        // Sections
                        if (_libraryItems.isNotEmpty) ...[
                          _sectionHeader('In Library', _libraryItems.length),
                          _buildLibraryGrid(_libraryItems),
                          const SizedBox(height: 24),
                        ],

                        if (_historyItems.isNotEmpty) ...[
                          _sectionHeader('History', _historyItems.length),
                          _buildLibraryGrid(_historyItems), // Reuse grid? Or horizontal list? Library Grid is better for scenes.
                          const SizedBox(height: 24),
                        ],

                        if (_tmdbMovies.isNotEmpty) ...[
                          _sectionHeader('Movies', _tmdbMovies.length),
                          _buildHorizontalList(_tmdbMovies, true),
                          const SizedBox(height: 24),
                        ],

                        if (_tmdbShows.isNotEmpty) ...[
                          _sectionHeader('TV Shows', _tmdbShows.length),
                          _buildHorizontalList(_tmdbShows, false),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar(String name, String? imageUrl) {
    return SliverAppBar(
      expandedHeight: 320, // Reduced from typical 400
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 10)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorWidget: (_,__,___) => Container(color: Colors.grey[900]),
              )
            else
              Container(color: Colors.grey[900]),
            
            // Gradient Overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                    Colors.black,
                  ],
                  stops: [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetrics() {
    final stats = [
      if (_libraryItems.isNotEmpty) '${_libraryItems.length} Saved',
      if (_historyItems.isNotEmpty) '${_historyItems.length} Watched',
      if (_tmdbMovies.isNotEmpty) '${_tmdbMovies.length} Movies',
      if (_tmdbShows.isNotEmpty) '${_tmdbShows.length} Shows',
    ];

    if (stats.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.map((s) => Chip(
        label: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900],
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      )).toList(),
    );
  }

  Widget _buildBio(String bio) {
    if (bio.isEmpty) return const SizedBox.shrink();
    return Text(
      bio,
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white70, height: 1.4),
    );
  }

  Widget _buildInfoGrid(String? birth, String? death, String? place, String? measurements, String? cups, String? career) {
    final items = <Widget>[];
    
    if (birth != null) items.add(_infoTile('Born', birth));
    if (death != null) items.add(_infoTile('Died', death));
    if (place != null) items.add(_infoTile('Place', place));
    if (career != null) items.add(_infoTile('Career', career));
    if (measurements != null) items.add(_infoTile('Measurements', measurements));
    
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: items,
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Text('$title ($count)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLibraryGrid(List<MediaItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Tighter responsive sizing
        int crossAxisCount = 2;
        if (width > 600) crossAxisCount = 3;
        if (width > 900) crossAxisCount = 4;
        if (width > 1200) crossAxisCount = 5;

        // Calculate item width based on count and tighter spacing
        final spacing = 10.0;
        final totalSpacing = (crossAxisCount - 1) * spacing;
        final itemWidth = (width - totalSpacing) / crossAxisCount;
        
        // Aspect ratio for scenes is usually wider (16:9) but posters are 2:3
        // If these are scenes, 16:9 is better. If movies, 2:3.
        // Let's assume Scene format (16:9) for library items if they are scenes
        final isScene = items.firstOrNull?.type == MediaType.scene;
        final childAspectRatio = isScene ? (16 / 9) : (2 / 3);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio, // Dynamic ratio
            crossAxisSpacing: spacing,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(item: item))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                     CachedNetworkImage(
                       imageUrl: (isScene ? item.backdropUrl : item.posterUrl) ?? item.posterUrl ?? '',
                       fit: BoxFit.cover,
                       errorWidget: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white54)),
                     ),
                     // Gradient bottom
                     Positioned.fill(
                       child: DecoratedBox(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.topCenter,
                             end: Alignment.bottomCenter,
                             colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                             stops: const [0.6, 1.0],
                           )
                         )
                       ),
                     ),
                     // Text
                     Positioned(
                       bottom: 8, left: 8, right: 8,
                       child: Text(
                         item.title ?? item.fileName,
                         maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                         style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                       ),
                     ),
                     // Source Pill
                     Positioned(
                       top: 6, right: 6,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: Colors.amber.withOpacity(0.9),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: const Text('LIBRARY', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                       ),
                     ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHorizontalList(List<Map<String, dynamic>> items, bool isMovie) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Tighter Grid Logic for TMDB items (Posters 2:3)
        // Option A: 190/170/150 widths logic from prompt
        // Let's use flexible column count for responsive grid instead of horizontal list to match "Tighten Cast Page Grids" request implies Grid?
        // Prompt says "_buildHorizontalList" but plan says "Tighten TMDB grid card sizing". 
        // If it's a section "Movies", usually a horizontal scrolling list is good to save vertical space.
        // But if we want to show ALL, a grid is better. 
        // Let's stick to GridView inside the vertical scroll for dense packing as requested "Tighten Cast Page Grids".
        
        int crossAxisCount = 3; // Mobile default
        if (width > 500) crossAxisCount = 4;
        if (width > 800) crossAxisCount = 5;
        if (width > 1100) crossAxisCount = 6;
        if (width > 1400) crossAxisCount = 7;

        final spacing = 10.0; // Tighter spacing (Option A/B)
        
        // 2:3 Ratio for posters
        const childAspectRatio = 2 / 3.2; // Slightly taller to fit text? Or standard 2/3

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 12, // Tighter run spacing
          ),
          itemCount: items.length > 20 ? 20 : items.length, // Limit to 20 to avoid massive pages?
          itemBuilder: (context, index) {
            final item = items[index];
            final posterPath = item['poster_path'];
            final title = item['title'] ?? item['name'] ?? 'Unknown';
            final date = item['release_date'] ?? item['first_air_date'] ?? '';
            final year = date.length >= 4 ? date.substring(0, 4) : '';

            return InkWell(
              onTap: () {
                 // Nav to details?
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => DetailsScreen(
                     id: item['id'].toString(), 
                     type: isMovie ? MediaType.movie : MediaType.tv,
                     heroTag: 'cast_${item['id']}_$index', // Unique hero
                   ),
                 ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6), // Slightly tighter radius
                      child: posterPath != null 
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w342$posterPath', // w342 is efficient
                            fit: BoxFit.cover,
                            errorWidget: (_,__,___) => Container(color: Colors.grey[800]),
                          )
                        : Container(color: Colors.grey[800], child: const Icon(Icons.movie, color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  if (year.isNotEmpty)
                    Text(
                      year,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
