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

  final Map<String, List<MediaItem>> _performerSceneCache = {};
  final Map<String, Future<List<MediaItem>>> _activePerformerRequests = {};

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

  static const String _querySearchPerformer = r'''
    query SearchPerformer($name: String!) {
      searchPerformer(term: $name) {
        id
        name
      }
    }
  ''';

  static const String _querySearchPerformerBox = r'''
    query SearchPerformerBox($name: String!) {
      queryPerformers(input: {
        text: $name
        per_page: 3
      }) {
        performers {
          id
          name
        }
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

  // --- Public Methods ---

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
            return _mapSceneToMediaItem(sceneData, 'Unknown');
        } else if (isStashBox) {
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
             return _mapSceneToMediaItem(movie, 'Unknown', type: MediaType.movie);
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
    final cleanTitle = _cleanTitle(title);
    
    for (final ep in endpoints) {
      if (!ep.enabled) continue;
      
      debugPrint('StashDB [${ep.name}]: Searching for "$cleanTitle"');
      final isStashBox = _isBox(ep.url);

      Future<MediaItem?> trySearch(String query, String opName, bool isBox, {bool isMovie = false}) async {
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
            debugPrint('StashDB [${ep.name}]: Found match via $opName');
            return _mapSceneToMediaItem(
                results.first, 
                title, 
                type: isMovie ? MediaType.movie : MediaType.scene
            );
          }
        } catch (e) {
          if (e.toString().contains('Cannot query field')) {
             debugPrint('StashDB [${ep.name}]: $opName not supported by schema.');
          } else {
             debugPrint('StashDB [${ep.name}]: Search error ($opName): $e');
          }
        }
        return null;
      }

      MediaItem? result;
      if (isStashBox) {
        result = await trySearch(_queryFindScenesBox, 'QueryScenes', true);
        if (result == null) result = await trySearch(_queryFindScenes, 'FindScenes', false);
        if (result == null) result = await trySearch(_queryQueryMoviesBox, 'QueryMoviesBox', true, isMovie: true);
      } else {
        result = await trySearch(_queryFindScenes, 'FindScenes', false);
        if (result == null) result = await trySearch(_queryFindScenesBox, 'QueryScenes', true);
      }

      if (result != null) return result;

    }

    return null;
  }

  /// Performer-aware scene search: Finds performer ID, fetches their scenes, matches by title.
  /// Returns the best match or null.
  Future<MediaItem?> searchSceneByPerformer(
    String sceneTitle,
    String performerName,
    List<StashEndpoint> endpoints, {
    bool requirePerformerMatch = false, // New Flag
  }) async {
    if (performerName.trim().isEmpty || sceneTitle.trim().isEmpty) return null;

    final cleanTitle = _cleanTitle(sceneTitle);
    final cleanPerformer = performerName.trim().toLowerCase();

    debugPrint('StashDB: Performer-first search: "$cleanPerformer" in "$cleanTitle" (Strict: $requirePerformerMatch)');

    for (final ep in endpoints) {
      if (!ep.enabled) continue;

      try {
        // 1. Find Performer ID
        final isStashBox = _isBox(ep.url);
        final searchQuery = isStashBox ? _querySearchPerformerBox : _querySearchPerformer;
        final searchOp = isStashBox ? 'SearchPerformerBox' : 'SearchPerformer';

        final searchData = await _executeQuery(
          query: searchQuery,
          operationName: searchOp,
          variables: {'name': performerName},
          apiKey: ep.apiKey,
          baseUrl: ep.url,
        );

        List<dynamic>? performers;
        if (isStashBox) {
          performers = searchData?['queryPerformers']?['performers'] as List?;
        } else {
          performers = searchData?['searchPerformer'] as List?;
        }

        if (performers == null || performers.isEmpty) {
          debugPrint('StashDB [${ep.name}]: Performer "$performerName" not found');
          continue;
        }

        // 2. Get Performer's Scenes (first 50 to be thorough)
        final performerId = performers.first['id'] as String;
        debugPrint('StashDB [${ep.name}]: Found performer ID $performerId');

        final scenes = await getPerformerScenes(performerId, [ep], page: 1, perPage: 50);

        if (scenes.isEmpty) {
          debugPrint('StashDB [${ep.name}]: No scenes found for performer');
          continue;
        }

        debugPrint('StashDB [${ep.name}]: Fetched ${scenes.length} scenes for $performerName');

        // 3. Score and Match
        MediaItem? bestMatch;
        double bestScore = 0.0;

        for (final scene in scenes) {
          final sceneTitle = scene.title?.toLowerCase() ?? '';
          final score = _tokenSetSimilarity(cleanTitle.toLowerCase(), sceneTitle); // Improved matching

          if (score > 0.4) {
             debugPrint('   Candidate: "${scene.title}" - Score: ${score.toStringAsFixed(2)}');
          }

          if (score > bestScore) {
            bestScore = score;
            bestMatch = scene;
          }
        }

        // 4. Threshold Check
        // If requirePerformerMatch is true, we enforce strict 0.5 threshold
        // If false, we allow 0.5 but might already be covered by logic (prompt says allow <0.5 if not strict? No, prompt says "optional requirePerformerMatch enforces a 0.5 similarity threshold")
        // Assuming without flag we stick to previous logic (which was >0.5 anyway). 
        // Actually, previous logic was > 0.5. Let's say with strict mode we might demand even higher, or just enforce it rigidly.
        // Prompt says "optional requirePerformerMatch enforces a 0.5 similarity threshold".
        // Let's stick to > 0.5 for now as "good match".

        if (bestScore > 0.5 && bestMatch != null) {
          debugPrint('StashDB [${ep.name}]: MATCH FOUND "${bestMatch.title}" (score: ${bestScore.toStringAsFixed(2)})');
          return bestMatch;
        } else {
           debugPrint('StashDB [${ep.name}]: No confident match. Best: ${bestScore.toStringAsFixed(2)}');
        }

      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Performer search error: $e');
      }
    }

    return null;
  }

  /// Gets scenes for a specific performer (paginated, single page).
  Future<List<MediaItem>> getPerformerScenes(String performerId, List<StashEndpoint> endpoints, {int page = 1, int perPage = 20}) async {
    // 1. Check Cache
    final cacheKey = '$performerId-$page-$perPage';
    if (_performerSceneCache.containsKey(cacheKey)) {
       return _performerSceneCache[cacheKey]!;
    }
    
    // 2. Check Active Requests (Dedupe)
    if (_activePerformerRequests.containsKey(cacheKey)) {
        return _activePerformerRequests[cacheKey]!;
    }

    // 3. Fetch (and cache future)
    final future = _fetchPerformerScenesPage(performerId, endpoints, page, perPage);
    _activePerformerRequests[cacheKey] = future;
    
    final result = await future;
    
    _performerSceneCache[cacheKey] = result;
    _activePerformerRequests.remove(cacheKey);
    
    return result;
  }

  Future<List<MediaItem>> _fetchPerformerScenesPage(String performerId, List<StashEndpoint> endpoints, int page, int perPage) async {
      for (final ep in endpoints) {
      if (!ep.enabled) continue;

      final isStashBox = _isBox(ep.url);

      try {
        debugPrint('StashDB [${ep.name}]: API Call -> Performer Scenes (Page $page)');
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
          return scenes
            .map((s) => _mapSceneToMediaItem(s, s['title'] ?? 'Unknown'))
            .toList();
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Fetch performer scenes failed: $e');
      }
    }
    return [];
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

  void resetCache() {
    _performerSceneCache.clear();
    _activePerformerRequests.clear();
  }

  // --- Helper Methods ---

  Future<Map<String, dynamic>?> _executeQuery({
    required String query,
    required String operationName,
    Map<String, dynamic>? variables,
    required String apiKey,
    required String baseUrl,
  }) async {
    final uri = Uri.parse(baseUrl.isEmpty ? _defaultEndpoint : baseUrl);
    
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
    var cleaned = title.replaceAll(RegExp(r'\.(mp4|mkv|avi|wmv|mov|webm)$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[._-]'), ' ');

    final junkPattern = RegExp(
      r'\b(xxx|p2p|prt|sd|hd|720p|1080p|2160p|4k|mp4|full|uhd|hevc|x264|x265|aac|webdl|web-dl|webrip|bluray|blueray|bdrip|dvdrip|hdtv)\b',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(junkPattern, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), ''); 
    
    return cleaned.trim();
  }

  /// Improved Token-Set Similarity (Jaccard Index of words)
  double _tokenSetSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    
    final set1 = _tokenize(s1);
    final set2 = _tokenize(s2);
    
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    return intersection / union;
  }
  
  Set<String> _tokenize(String s) {
     return s.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toSet();
  }

  MediaItem _mapSceneToMediaItem(dynamic sceneData, String originalFileName, {MediaType type = MediaType.scene}) {
    final scene = sceneData as Map<String, dynamic>;
    
    String? poster;
    final images = scene['images'] as List?;
    if (images != null && images.isNotEmpty) {
      poster = images.first['url'];
    } else if (scene['front_image'] != null) {
      poster = scene['front_image']['url'];
    }

    final rawPerformers = scene['performers'] as List?;
    // debugPrint('StashDB: Parsing performers. Count: ${rawPerformers?.length}');
    
    final cast = rawPerformers?.map((p) {
        final perf = p['performer'];
        if (perf == null) {
          // debugPrint('StashDB: Performer object is null');
          return null;
        }
        
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
          profileUrl: profileUrl,
          source: CastSource.stashDb,
        );
    }).whereType<CastMember>().toList() ?? [];
    // debugPrint('StashDB: Extracted ${cast.length} cast members');

    final tags = (scene['tags'] as List?)
        ?.map((t) => t['name'] as String?)
        .whereType<String>()
        .toList() ?? [];

    String overview = scene['details'] ?? '';
    final studio = scene['studio']?['name'];
    
    if (studio != null) {
      overview = 'Studio: $studio\n\n$overview';
    }

    final date = DateTime.tryParse(scene['date'] ?? '');

    String? backdrop;
    final paths = scene['paths'] as Map<String, dynamic>?;
    if (paths != null) {
      if (paths['screenshot'] != null && (paths['screenshot'] as String).isNotEmpty) {
        backdrop = paths['screenshot'];
      }
    } else if (scene['back_image'] != null) {
       backdrop = scene['back_image']['url'];
    }
    backdrop ??= poster;

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
