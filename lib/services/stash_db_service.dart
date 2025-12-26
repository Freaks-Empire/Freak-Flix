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

  // --- Public Methods ---

  /// Tests the connection to StashDB using the provided API key.
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    
    try {
      final data = await _executeQuery(
        query: _queryMe,
        operationName: 'Me',
        apiKey: apiKey,
      );
      return data?['me'] != null;
    } catch (e) {
      debugPrint('StashDB: Connection test failed: $e');
      return false;
    }
  }

  /// Searches for a scene by title.
  Future<MediaItem?> searchScene(String title, String apiKey) async {
    if (apiKey.trim().isEmpty) return null;

    // Clean title for better matching
    final cleanTitle = _cleanTitle(title);
    debugPrint('StashDB: Searching for "$cleanTitle" (Original: "$title")');

    try {
      final data = await _executeQuery(
        query: _queryFindScenes,
        operationName: 'FindScenes',
        variables: {'title': cleanTitle},
        apiKey: apiKey,
      );

      final scenes = data?['findScenes']?['scenes'] as List?;
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
  Future<List<MediaItem>> getPerformerScenes(String performerId, String apiKey) async {
    if (apiKey.trim().isEmpty) return [];

    try {
      final data = await _executeQuery(
        query: _queryPerformerScenes,
        operationName: 'PerformerScenes',
        variables: {'performerId': performerId},
        apiKey: apiKey,
      );

      final scenes = data?['findScenes']?['scenes'] as List?;
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
  }) async {
    final uri = Uri.parse(_defaultEndpoint);
    
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
    return title
        .replaceAll(RegExp(r'\.(mp4|mkv|avi|wmv|mov)$', caseSensitive: false), '')
        .replaceAll('.', ' ')
        .trim();
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
    final cast = (scene['performers'] as List?)?.map((p) {
        final perf = p['performer'];
        if (perf == null) return null;
        return CastMember(
          id: perf['id'] as String? ?? '',
          name: perf['name'] as String? ?? 'Unknown',
          character: 'Performer', 
          profileUrl: perf['image_path'] as String?,
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
    
    if (studio != null) {
      overview = 'Studio: $studio\n\n$overview';
    }

    // StashDB dates are YYYY-MM-DD
    final date = DateTime.tryParse(scene['date'] ?? '');

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
      overview: overview.trim(),
      cast: cast,
      genres: tags,
      isAdult: true,
    );
  }
}
