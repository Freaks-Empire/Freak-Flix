import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';

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
    query PerformerScenes($performerId: ID!) {
      findScenes(scene_filter: {
        performers: {
          value: $performerId
          modifier: EQUALS
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
    query PerformerScenesBox($performerId: ID!) {
      queryScenes(input: {
        performers: {
          value: [$performerId]
          modifier: INCLUDES
        }
        per_page: 20
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

  /// Searches for a scene by title.
  Future<MediaItem?> searchScene(String title, String apiKey, String baseUrl) async {
    if (apiKey.trim().isEmpty) return null;

    // Clean title for better matching
    final cleanTitle = _cleanTitle(title);
    debugPrint('StashDB: Searching for "$cleanTitle" (Original: "$title") at $baseUrl');

    final isStashBox = baseUrl.contains('stashdb.org');

    try {
      final data = await _executeQuery(
        query: isStashBox ? _queryFindScenesBox : _queryFindScenes,
        operationName: isStashBox ? 'QueryScenes' : 'FindScenes',
        variables: {'title': cleanTitle},
        apiKey: apiKey,
        baseUrl: baseUrl,
      );

      List<dynamic>? scenes;
      if (isStashBox) {
        scenes = data?['queryScenes']?['scenes'] as List?;
      } else {
        scenes = data?['findScenes']?['scenes'] as List?;
      }

      if (scenes != null && scenes.isNotEmpty) {
        debugPrint('StashDB: Found ${scenes.length} matches for "$title"');
        return _mapSceneToMediaItem(scenes.first, title);
      } else {
        debugPrint('StashDB: No matches found for "$title"');
      }
    } catch (e) {
      debugPrint('StashDB: Search failed: $e');
    }

    return null;
  }

  /// Gets scenes for a specific performer.
  Future<List<MediaItem>> getPerformerScenes(String performerId, String apiKey, String baseUrl) async {
    if (apiKey.trim().isEmpty) return [];

    final isStashBox = baseUrl.contains('stashdb.org');

    try {
      final data = await _executeQuery(
        query: isStashBox ? _queryPerformerScenesBox : _queryPerformerScenes,
        operationName: isStashBox ? 'PerformerScenesBox' : 'PerformerScenes',
        variables: {'performerId': performerId},
        apiKey: apiKey,
        baseUrl: baseUrl,
      );

      List<dynamic>? scenes;
      if (isStashBox) {
        scenes = data?['queryScenes']?['scenes'] as List?;
      } else {
        scenes = data?['findScenes']?['scenes'] as List?;
      }

      if (scenes != null) {
        return scenes
          .map((s) => _mapSceneToMediaItem(s, s['title'] ?? 'Unknown'))
          .toList();
      }
    } catch (e) {
      debugPrint('StashDB: Fetch performer scenes failed: $e');
    }

    return [];
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
    // User request: "dont add numbers at the las most of the time its just the release date"
    // We'll strip standalone digits at the end of the string.
    var prev = cleaned;
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), ''); 
    
    // Also handle dates like 22.05.15 if they survived step 2 (step 2 replaced dots with space)
    // So "22 05 15" -> might be "22 05 15" at end.
    // Let's loop a bit or use a stronger regex if needed, but strict trailing digits is a good start.
    // If we have "Title 2022", it becomes "Title".
    // If we have "Title 01", it becomes "Title".
    
    // 5. Trim and collapse spaces
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
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
}
