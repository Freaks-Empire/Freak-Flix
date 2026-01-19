/// lib/services/stash_db_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';
import '../models/stash_performer.dart';
import '../models/stash_endpoint.dart';

/// A robust service for interacting with the StashDB GraphQL API.
/// 
/// Documentation: https://docs.stashapp.cc/
class StashDbService {
  static const String _defaultEndpoint = 'https://stashdb.org/graphql';

  // Caches performer scene pages within a scan batch to avoid repeated calls.
  final Map<String, Future<List<MediaItem>>> _performerScenesCache = {};

  // --- Queries ---

  static const String _queryMe = r'''
    query Me {
      me {
        name
        email
      }
    }
  ''';

  static const String _queryFindScenes = r'''
    query FindScenes($title: String!) {
      findScenes(scene_filter: {
        title: {
          value: $title
          modifier: INCLUDES
        }
      }) {
        scenes {
          id
          title
          details
          date
          tags {
            name
          }
          images {
            url
          }
          paths {
            screenshot
          }
          files {
            duration
          }
          studio {
            name
          }
          performers {
            performer {
              id
              name
              image_path
            }
          }
        }
      }
    }
  ''';

  static const String _queryPerformerScenes = r'''
    query PerformerScenes($performerId: ID!, $page: Int!, $per_page: Int!) {
      findScenes(scene_filter: {
        performers: {
          value: $performerId
          modifier: EQUALS
        }
      }, filter: {
        page: $page
        per_page: $per_page
      }) {
        scenes {
          id
          title
          details
          date
          tags {
            name
          }
          images {
            url
          }
          paths {
            screenshot
          }
          files {
            duration
          }
          studio {
            name
          }
          performers {
            performer {
              id
              name
              image_path
            }
          }
        }
      }
    }
  ''';

  static const String _queryFindScenesBox = r'''
    query QueryScenes($title: String!) {
      queryScenes(input: {
        text: $title
        per_page: 5
      }) {
        scenes {
          id
          title
          details
          date
          duration
          tags {
            name
          }
          images {
            url
          }
          studio {
            name
          }
          performers {
            performer {
              id
              name
              images {
                url
              }
            }
          }
        }
      }
    }
  ''';

  static const String _queryPerformerScenesBox = r'''
    query PerformerScenesBox($performerId: ID!, $page: Int!, $per_page: Int!) {
      queryScenes(input: {
        performers: {
          value: [$performerId]
          modifier: INCLUDES
        }
        page: $page
        per_page: $per_page
      }) {
        scenes {
          id
          title
          details
          date
          duration
          tags {
            name
          }
          images {
            url
          }
          studio {
            name
          }
          performers {
            performer {
              id
              name
              images {
                url
              }
            }
          }
        }
      }
    }
  ''';

  static const String _querySearchPerformers = r'''
    query SearchPerformers($name: String!) {
      findPerformers(performer_filter: {
        name: { value: $name, modifier: INCLUDES }
      }, filter: { per_page: 5 }) {
        performers { id name }
      }
    }
  ''';

  static const String _querySearchPerformersBox = r'''
    query QueryPerformers($text: String!) {
      queryPerformers(input: { text: $text, per_page: 5 }) {
        performers { id name }
      }
    }
  ''';

  static const String _queryFindPerformer = r'''
    query FindPerformer($id: ID!) {
      findPerformer(id: $id) {
        id
        name
        birthdate
        height_cm
        measurements
        fake_tits
        country
        ethnicity
        eye_color
        hair_color
        career_start_year
        career_end_year
        tattoos {
          location
          description
        }
        piercings {
          location
          description
        }
        aliases
        url
        twitter
        instagram
        details
        image_path
        scene_count
        urls {
            url
            type
        }
      }
    }
  ''';

  static const String _queryPerformerBox = r'''
    query PerformerBox($id: ID!) {
      performer(id: $id) {
        id
        name
        birth_date
        height_cm
        measurements
        fake_tits
        country
        ethnicity
        eye_color
        hair_color
        career_start_year
        career_end_year
        tattoos {
          location
          description
        }
        piercings {
          location
          description
        }
        aliases
        urls {
          url
          type
        }
        twitter
        instagram
        details
        images {
          url
        }
        scene_count
      }
    }
  ''';
  
  static const String _queryFindSceneById = r'''
    query FindScene($id: ID!) {
      findScene(id: $id) {
        id
        title
        details
        date
        tags {
          name
        }
        images {
          url
        }
        paths {
          screenshot
        }
        files {
          duration
        }
        studio {
          name
        }
        performers {
          performer {
            id
            name
            image_path
          }
        }
      }
    }
  ''';

  static const String _queryFindSceneBoxById = r'''
    query FindSceneBox($id: ID!) {
      findScene(id: $id) {
        id
        title
        details
        date
        duration
        tags {
          name
        }
        images {
          url
        }
        studio {
          name
        }
        performers {
          performer {
            id
            name
            images {
              url
            }
          }
        }
      }
    }
  ''';

  static const String _queryFindMovieBox = r'''
    query FindMovieBox($id: ID!) {
      findMovie(id: $id) {
        id
        name
        synopsis
        date
        duration
        front_image {
          url
        }
        back_image {
          url
        }
        studio {
          name
        }
        performers {
          performer {
            id
            name
            images {
              url
            }
          }
        }
      }
    }
  ''';

  static const String _queryQueryMoviesBox = r'''
    query QueryMoviesBox($title: String!) {
      queryMovies(input: {
        name: $title
        per_page: 5
      }) {
        movies {
          id
          name
          synopsis
          date
          duration
          front_image {
            url
          }
          back_image {
            url
          }
          studio {
            name
          }
          performers {
            performer {
              id
              name
              images {
                url
              }
            }
          }
        }
      }
    }
  ''';

  static const String _queryRecentScenes = r'''
    query RecentScenes($limit: Int!) {
      findScenes(
        scene_filter: {}
        filter: {
          sort: "date"
          direction: DESC
          per_page: $limit
          page: 1
        }
      ) {
        scenes {
          id
          title
          details
          date
          tags { name }
          images { url }
          files { duration }
          paths { screenshot }
          studio { name }
        }
      }
    }
  ''';

  // --- Public Methods ---

  /// Fetch recently added scenes (Adult Trending)
  Future<List<MediaItem>> getRecentScenes(List<StashEndpoint> endpoints, {int limit = 10}) async {
    for (final ep in endpoints) {
      if (!ep.enabled) continue;

      try {
        final data = await _executeQuery(
          query: _queryRecentScenes,
          operationName: 'RecentScenes',
          variables: {'limit': limit},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        final scenes = data?['findScenes']?['scenes'] as List?;
        if (scenes != null && scenes.isNotEmpty) {
           return scenes.map((s) => _mapSceneToMediaItem(s, s['title'] ?? 'Unknown', baseUrl: ep.url)).toList();
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Fetch Recent Scenes failed: $e');
      }
    }
    return [];
  }

  /// Tests the connection to StashDB using the provided API key.
  Future<bool> testConnection(String apiKey, String baseUrl) async {
    if (apiKey.trim().isEmpty) return false;
    
    try {
      final data = await _executeQuery(
        query: _queryMe,
        operationName: 'Me',
        apiKey: apiKey,
        baseUrl: baseUrl,
      );
      return data?['me'] != null;
    } catch (e) {
      debugPrint('StashDB: Connection test failed: $e');
      return false;
    }
  }

  /// Gets a specific scene by ID. Tries all provided endpoints.
  Future<MediaItem?> getScene(String id, List<StashEndpoint> endpoints) async {
    for (final ep in endpoints) {
      if (!ep.enabled || ep.apiKey.isEmpty) continue;
      
      try {
         final isStashBox = _isBox(ep.url);
         final query = isStashBox ? _queryFindSceneBoxById : _queryFindSceneById;
         final opName = isStashBox ? 'FindSceneBox' : 'FindScene';

         final data = await _executeQuery(
          query: query,
          operationName: opName,
          variables: {'id': id},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        final sceneData = data?['findScene'];
        if (sceneData != null) {
            return _mapSceneToMediaItem(sceneData, 'Unknown', baseUrl: ep.url);
        } else if (isStashBox) {
          // Fallback: Check if it's a Movie (TPDB often distinguishes strictly)
          debugPrint('StashDB [${ep.name}]: Scene not found, trying Movie...');
          final movieData = await _executeQuery(
            query: _queryFindMovieBox,
            operationName: 'FindMovieBox',
            variables: {'id': id},
            apiKey: ep.apiKey,
            baseUrl: ep.url,
          );
          final movie = movieData?['findMovie'];
          if (movie != null) {
             return _mapSceneToMediaItem(movie, 'Unknown', type: MediaType.movie, baseUrl: ep.url);
          }
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Get scene $id failed: $e');
      }
    }
    return null;
  }

  /// Searches for a scene by title across all endpoints. Returns first match.
  Future<MediaItem?> searchScene(String title, List<StashEndpoint> endpoints) async {
    final results = await searchScenesList(title, endpoints);
    return results.isNotEmpty ? results.first : null;
  }

  /// Searches for scenes by title and returns a list of matches.
  Future<List<MediaItem>> searchScenesList(String title, List<StashEndpoint> endpoints, {bool useRaw = false}) async {
    final cleanTitle = useRaw ? title.trim() : _cleanTitle(title);
    
    for (final ep in endpoints) {
      if (!ep.enabled) continue; 
      
      debugPrint('StashDB [${ep.name}]: Searching List for "$cleanTitle"');
      final isStashBox = _isBox(ep.url);

      // Helper to execute and parse scene search
      Future<List<MediaItem>> trySearch(String query, String opName, bool isBox, {bool isMovie = false}) async {
        try {
           final data = await _executeQuery(
            query: query,
            operationName: opName,
            variables: {'title': cleanTitle},
            apiKey: ep.apiKey,
            baseUrl: ep.url,
          );
          
          List<dynamic>? results;
          if (isMovie && isBox) {
             results = data?['queryMovies']?['movies'] as List?;
          } else if (isBox) {
             results = data?['queryScenes']?['scenes'] as List?;
          } else {
             results = data?['findScenes']?['scenes'] as List?;
          }

          if (results != null && results.isNotEmpty) {
            debugPrint('StashDB [${ep.name}]: Found ${results.length} matches via $opName');
            return results.map((r) => _mapSceneToMediaItem(
                r, 
                title, 
                type: isMovie ? MediaType.movie : MediaType.scene,
                baseUrl: ep.url
            )).toList();
          }
        } catch (e) {
           debugPrint('StashDB [${ep.name}]: Search List error ($opName): $e');
        }
        return [];
      }

      // 1. Try Primary Scene Search
      List<MediaItem> results = [];
      if (isStashBox) {
        results = await trySearch(_queryFindScenesBox, 'QueryScenes', true);
        if (results.isEmpty) results = await trySearch(_queryFindScenes, 'FindScenes', false);
        if (results.isEmpty) results = await trySearch(_queryQueryMoviesBox, 'QueryMoviesBox', true, isMovie: true);
      } else {
        results = await trySearch(_queryFindScenes, 'FindScenes', false);
        if (results.isEmpty) results = await trySearch(_queryFindScenesBox, 'QueryScenes', true);
      }

      if (results.isNotEmpty) return results;
    }

    return [];
  }

  /// Performer-first search: find performer ID by name, then filter that performer's scenes by title.
  Future<MediaItem?> searchSceneByPerformer(
    String title,
    String performerName,
    List<StashEndpoint> endpoints, {
    bool requirePerformerMatch = false,
  }) async {
    final performerId = await _findPerformerIdByName(performerName, endpoints);
    if (performerId == null) return null;

    final scenes = await getPerformerScenes(performerId, endpoints, page: 1, perPage: 50);
    if (scenes.isEmpty) return null;

    final target = _cleanTitle(title).toLowerCase();
    MediaItem? best;
    double bestSimilarity = -1;

    for (final scene in scenes) {
      final cleaned = _cleanTitle(scene.title ?? scene.fileName).toLowerCase();
      final similarity = _titleSimilarity(target, cleaned);

      debugPrint('[stash-match] strategy=performer title="$target" candidate="$cleaned" similarity=${similarity.toStringAsFixed(3)}');

      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        best = scene;
      }
    }

    final meetsThreshold = bestSimilarity >= 0.5 || !requirePerformerMatch;
    debugPrint('[stash-match] strategy=performer result=${best?.id ?? 'none'} similarity=${bestSimilarity.toStringAsFixed(3)} thresholdMet=$meetsThreshold');

    if (!meetsThreshold) return null;
    return best;
  }

  Future<String?> _findPerformerIdByName(String name, List<StashEndpoint> endpoints) async {
    final cleanName = _cleanTitle(name);
    for (final ep in endpoints) {
      if (!ep.enabled) continue;
      final isStashBox = _isBox(ep.url);
      try {
        final data = await _executeQuery(
          query: isStashBox ? _querySearchPerformersBox : _querySearchPerformers,
          operationName: isStashBox ? 'QueryPerformers' : 'SearchPerformers',
          variables: isStashBox ? {'text': cleanName} : {'name': cleanName},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        List<dynamic>? performers;
        if (isStashBox) {
          performers = data?['queryPerformers']?['performers'] as List?;
        } else {
          performers = data?['findPerformers']?['performers'] as List?;
        }

        if (performers != null && performers.isNotEmpty) {
          // Prefer exact/startsWith match
          final lower = cleanName.toLowerCase();
          performers.sort((a, b) {
            final an = (a['name'] as String? ?? '').toLowerCase();
            final bn = (b['name'] as String? ?? '').toLowerCase();
            final aScore = an == lower || an.startsWith(lower) ? 0 : 1;
            final bScore = bn == lower || bn.startsWith(lower) ? 0 : 1;
            return aScore.compareTo(bScore);
          });
          return performers.first['id'] as String?;
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Performer search failed: $e');
      }
    }
    return null;
  }

  /// Gets scenes for a specific performer (paginated, single page).
  /// Aggregates results from all endpoints? Or just tries all until results found?
  /// For pagination consistency, aggregation is hard. We will return results from the first endpoint that has data.
  Future<List<MediaItem>> getPerformerScenes(String performerId, List<StashEndpoint> endpoints, {int page = 1, int perPage = 20}) async {
    final cacheKey = _sceneCacheKey(performerId, page, perPage);
    final cached = _performerScenesCache[cacheKey];
    if (cached != null) return cached;

    final future = _fetchPerformerScenes(performerId, endpoints, page, perPage);
    _performerScenesCache[cacheKey] = future;
    return future;
  }

  Future<List<MediaItem>> _fetchPerformerScenes(String performerId, List<StashEndpoint> endpoints, int page, int perPage) async {
    for (final ep in endpoints) {
      if (!ep.enabled) continue;

      final isStashBox = _isBox(ep.url);

      try {
        debugPrint('StashDB [${ep.name}]: Fetching performer scenes page $page');
        final data = await _executeQuery(
          query: isStashBox ? _queryPerformerScenesBox : _queryPerformerScenes,
          operationName: isStashBox ? 'PerformerScenesBox' : 'PerformerScenes',
          variables: {
            'performerId': performerId,
            'page': page,
            'per_page': perPage,
          },
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        List<dynamic>? scenes;
        if (isStashBox) {
          scenes = data?['queryScenes']?['scenes'] as List?;
        } else {
          scenes = data?['findScenes']?['scenes'] as List?;
        }

        if (scenes != null && scenes.isNotEmpty) {
          debugPrint('[stash-fetch] performer=$performerId endpoint=${ep.name} page=$page perPage=$perPage count=${scenes.length}');
          return scenes
            .map((s) => _mapSceneToMediaItem(s, s['title'] ?? 'Unknown', baseUrl: ep.url))
            .toList();
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Fetch performer scenes failed: $e');
      }
    }

    return [];
  }

  String _sceneCacheKey(String performerId, int page, int perPage) => '$performerId:$page:$perPage';

  double _titleSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final setA = a.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    final setB = b.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0 : intersection / union;
  }

  Future<StashPerformer?> getPerformerDetails(String id, List<StashEndpoint> endpoints) async {
    for (final ep in endpoints) {
      if (!ep.enabled) continue;
      
      final isStashBox = _isBox(ep.url);
      
      try {
        final data = await _executeQuery(
          query: isStashBox ? _queryPerformerBox : _queryFindPerformer,
          operationName: isStashBox ? 'PerformerBox' : 'FindPerformer',
          variables: {'id': id},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        Map<String, dynamic>? p;
        if (isStashBox) {
          p = data?['performer'] as Map<String, dynamic>?;
        } else {
          p = data?['findPerformer'] as Map<String, dynamic>?;
        }
        if (p != null) {
          return StashPerformer.fromJson(p);
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Get Performer Details failed: $e');
      }
    }
    return null;
  }
  
  /// Gets performer details by ID (Legacy simplified).
  Future<CastMember?> getPerformer(String id, List<StashEndpoint> endpoints) async {
    for (final ep in endpoints) {
      if (!ep.enabled) continue;
      
      final isStashBox = _isBox(ep.url);
      
      try {
        final data = await _executeQuery(
          query: isStashBox ? _queryPerformerBox : _queryFindPerformer,
          operationName: isStashBox ? 'PerformerBox' : 'FindPerformer',
          variables: {'id': id},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        
        Map<String, dynamic>? p;
        if (isStashBox) {
           p = data?['performer'];
        } else {
           p = data?['findPerformer'];
        }
        if (p != null) {
            String? profileUrl;
            if (p['image_path'] != null) {
              profileUrl = p['image_path'];
            } else if (p['images'] != null && (p['images'] as List).isNotEmpty) {
              profileUrl = p['images'][0]['url'];
            }
            
            return CastMember(
              id: p['id'],
              name: p['name'] ?? 'Unknown',
              character: 'Performer',
              profileUrl: profileUrl,
              source: CastSource.stashDb,
            );
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Get Performer failed: $e');
      }
    }
    return null;
  }

  // --- Helper Methods ---

  /// Executes a GraphQL query and returns the 'data' field.
  /// Throws exceptions on HTTP errors or GraphQL errors.
  Future<Map<String, dynamic>?> _executeQuery({
    required String query,
    required String operationName,
    Map<String, dynamic>? variables,
    required String apiKey,
    required String baseUrl,
  }) async {
    final uri = Uri.parse(baseUrl.isEmpty ? _defaultEndpoint : baseUrl);
    
    // StashDB typically uses 'ApiKey' header
    final headers = {
      'Content-Type': 'application/json',
      'ApiKey': apiKey.trim(),
    };

    final body = jsonEncode({
      'query': query,
      'operationName': operationName,
      if (variables != null) 'variables': variables,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body);

    if (json['errors'] != null) {
      final errors = json['errors'] as List;
      final msgs = errors.map((e) => e['message']).join(', ');
      throw Exception('GraphQL Errors: $msgs');
    }

    return json['data'] as Map<String, dynamic>?;
  }

  String _cleanTitle(String title) {
    // 1. Remove extension
    var cleaned = title.replaceAll(RegExp(r'\.(mp4|mkv|avi|wmv|mov|webm)$', caseSensitive: false), '');
    
    // 2. Remove dots, underscores, hyphens
    cleaned = cleaned.replaceAll(RegExp(r'[._-]'), ' ');

    // 3. Remove common release junk (Case insensitive)
    // "XXX", "P2P", "PRT" (Private?), "SD", "HD", "4K", "1080p", etc.
    final junkPattern = RegExp(
      r'\b(xxx|p2p|prt|sd|hd|720p|1080p|2160p|4k|mp4|full|uhd|hevc|x264|x265|aac|webdl|web-dl|webrip|bluray|blueray|bdrip|dvdrip|hdtv)\b',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(junkPattern, ' ');

    // 4. Remove trailing numbers (years, dates, or random digits at the end)
    // First collapse/trim spaces so we don't fail on "Title 29 "
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Now strip numeric suffix
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), ''); 
    
    return cleaned;
  }

  MediaItem _mapSceneToMediaItem(dynamic sceneData, String originalFileName, {MediaType type = MediaType.scene, String? baseUrl}) {
    final scene = sceneData as Map<String, dynamic>;
    
    // Helper to fix URLs
    String? fixUrl(String? u) {
      if (u == null) return null;
      if (u.startsWith('http')) return u;
      if (baseUrl != null) {
        // Handle Stash relative paths
         return baseUrl.endsWith('/') 
           ? '$baseUrl${u.startsWith('/') ? u.substring(1) : u}' 
           : '$baseUrl${u.startsWith('/') ? u : '/$u'}';
      }
      return u;
    }

    // Extract Poster
    String? poster;
    final images = scene['images'] as List?;
    if (images != null && images.isNotEmpty) {
      poster = images.first['url'];
    } else if (scene['front_image'] != null) {
      poster = scene['front_image']['url'];
    }

    // Fix poster URL
    poster = fixUrl(poster);

    // Extract Cast
    final rawPerformers = scene['performers'] as List?;    
    final cast = rawPerformers?.map((p) {
        final perf = p['performer'];
        if (perf == null) return null;
        
        String? profileUrl;
        if (perf['image_path'] != null) {
          profileUrl = perf['image_path'];
        } else if (perf['images'] != null && (perf['images'] as List).isNotEmpty) {
          profileUrl = perf['images'][0]['url'];
        }

        return CastMember(
          id: perf['id'] as String? ?? '',
          name: perf['name'] as String? ?? 'Unknown',
          character: 'Performer', 
          profileUrl: fixUrl(profileUrl),
          source: CastSource.stashDb,
        );
    }).whereType<CastMember>().toList() ?? [];

    // Extract Tags/Genres
    final tags = (scene['tags'] as List?)
        ?.map((t) => t['name'] as String?)
        .whereType<String>()
        .toList() ?? [];

    // Construct Overview
    String overview = scene['details'] ?? '';
    final studio = scene['studio']?['name'];
    if (studio != null) overview = 'Studio: $studio\n\n$overview';
    
    final date = DateTime.tryParse(scene['date'] ?? '');

    // Extract Backdrop (Priority: paths.screenshot -> paths.preview -> poster)
    String? backdrop;
    final paths = scene['paths'] as Map<String, dynamic>?;
    if (paths != null && paths['screenshot'] != null) {
         backdrop = paths['screenshot'];
    } else if (scene['back_image'] != null) {
       backdrop = scene['back_image']['url'];
    }
    
    backdrop = fixUrl(backdrop);
    
    // Fallback logic
    backdrop ??= poster;
    poster ??= backdrop; // Use screenshot as poster if no cover

    // Extract Duration
    int? durationSeconds;
    if (scene['duration'] != null) {
       final d = scene['duration'];
       if (d is num) durationSeconds = d.toInt();
       else if (d is String) durationSeconds = int.tryParse(d);
    }
    if (durationSeconds == null || durationSeconds == 0) {
       final files = scene['files'] as List?;
       if (files != null && files.isNotEmpty) {
          final f = files.first;
          final d = f['duration'];
          if (d is num) durationSeconds = d.toInt();
          else if (d is String) durationSeconds = int.tryParse(d);
       }
    }

    return MediaItem(
      id: "stashdb:${scene['id']}",
      stashId: scene['id'] as String?,
      title: scene['title'] ?? originalFileName,
      fileName: originalFileName,
      filePath: '', 
      folderPath: '', 
      sizeBytes: 0, 
      lastModified: date ?? DateTime.now(),
      year: date?.year,
      type: type, 
      posterUrl: poster,
      backdropUrl: backdrop,
      runtimeMinutes: (durationSeconds != null) ? (durationSeconds / 60).round() : null,
      overview: overview.trim(),
      cast: cast,
      genres: tags,
      isAdult: true,
    );
  }
  bool _isBox(String url) {
    return url.contains('stashdb.org') || url.contains('theporndb.net');
  }
}
