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
             return _mapSceneToMediaItem(movie, 'Unknown');
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
      if (!ep.enabled) continue; // Allow empty API key (local stash often no auth)
      
      debugPrint('StashDB [${ep.name}]: Searching for "$cleanTitle"');
      final isStashBox = _isBox(ep.url);

      try {
        final data = await _executeQuery(
          query: isStashBox ? _queryFindScenesBox : _queryFindScenes,
          operationName: isStashBox ? 'QueryScenes' : 'FindScenes',
          variables: {'title': cleanTitle},
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
          debugPrint('StashDB [${ep.name}]: Found ${scenes.length} matches');
          return _mapSceneToMediaItem(scenes.first, title);
        }
      } catch (e) {
        debugPrint('StashDB [${ep.name}]: Search failed: $e');
      }
    }

    return null;
  }

  /// Gets scenes for a specific performer (paginated, single page).
  /// Aggregates results from all endpoints? Or just tries all until results found?
  /// For pagination consistency, aggregation is hard. We will return results from the first endpoint that has data.
  Future<List<MediaItem>> getPerformerScenes(String performerId, List<StashEndpoint> endpoints, {int page = 1, int perPage = 20}) async {
    
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
          return StashPerformer.fromJson(p as Map<String, dynamic>);
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

  MediaItem _mapSceneToMediaItem(dynamic sceneData, String originalFileName) {
    final scene = sceneData as Map<String, dynamic>;
    
    // Extract Poster
    String? poster;
    final images = scene['images'] as List?;
    if (images != null && images.isNotEmpty) {
      poster = images.first['url'];
    }

    // Extract Cast
    final rawPerformers = scene['performers'] as List?;
    debugPrint('StashDB: Parsing performers. Count: ${rawPerformers?.length}');
    
    final cast = rawPerformers?.map((p) {
        final perf = p['performer'];
        if (perf == null) {
          debugPrint('StashDB: Performer object is null');
          return null;
        }
        
        // Handle both Stash App (image_path) and Stash Box (images list)
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
    debugPrint('StashDB: Extracted ${cast.length} cast members');

    // Extract Tags/Genres
    final tags = (scene['tags'] as List?)
        ?.map((t) => t['name'] as String?)
        .whereType<String>()
        .toList() ?? [];

    // Construct Overview
    String overview = scene['details'] ?? '';
    final studio = scene['studio']?['name'];
    
    if (studio != null) {
      overview = 'Studio: $studio\n\n$overview';
    }

    // StashDB dates are YYYY-MM-DD
    final date = DateTime.tryParse(scene['date'] ?? '');

    // Extract Backdrop (Priority: paths.screenshot -> paths.preview -> poster)
    String? backdrop;
    final paths = scene['paths'] as Map<String, dynamic>?;
    if (paths != null) {
      if (paths['screenshot'] != null && (paths['screenshot'] as String).isNotEmpty) {
        backdrop = paths['screenshot'];
      }
    }
    // Fallback to primary poster if no specific backdrop for now
    backdrop ??= poster;

    // Extract Duration
    int? durationSeconds;
    // 1. Scene direct duration (Box)
    if (scene['duration'] != null) {
       final d = scene['duration'];
       if (d is num) durationSeconds = d.toInt();
       else if (d is String) durationSeconds = int.tryParse(d);
    }
    // 2. File duration (Stash App)
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
      filePath: '', // Populated by LibraryProvider
      folderPath: '', // Populated by LibraryProvider
      sizeBytes: 0, 
      lastModified: date ?? DateTime.now(),
      year: date?.year,
      type: MediaType.movie, 
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
