import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/cast_member.dart';

class StashDbService {
  static const String _endpoint = 'https://stashdb.org/graphql';

  Future<bool> testConnection(String apiKey) async {
    if (apiKey.isEmpty) return false;
    try {
      // Simple introspection or lightweight query to test auth
      const query = '''
        query Me {
          me {
            name
            email
          }
        }
      ''';
      
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'ApiKey': apiKey,
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data']?['me'] != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<MediaItem?> searchScene(String title, String apiKey) async {
    if (apiKey.isEmpty) return null;

    // Remove file extension and clean up title for better search
    final cleanTitle = title
        .replaceAll(RegExp(r'\.(mp4|mkv|avi|wmv|mov)$', caseSensitive: false), '')
        .replaceAll('.', ' ')
        .trim();

    // Query to find scene by title
    // Using a broad search first
    if (cleanTitle.isEmpty) {
      print('[StashDB] Skipped search: Empty title after cleaning "$title"');
      return null;
    }

    const query = '''
      query SearchScenes(\$term: String!) {
        searchScene(input: {
          term: \$term,
          limit: 1
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

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'ApiKey': apiKey,
        },
        body: jsonEncode({
          'query': query,
          'variables': {'term': cleanTitle},
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['errors'] != null) {
          print('[StashDB] GraphQL Errors: ${body['errors']}');
          return null;
        }
        final scenes = body['data']?['searchScene']?['scenes'] as List?;
        
        if (scenes != null && scenes.isNotEmpty) {
          final scene = scenes.first;
          return _mapSceneToMediaItem(scene, title); // Pass original title/filename
        }
      } else {
        print('[StashDB] Search Failed: ${response.statusCode}');
        print('[StashDB] Body: ${response.body}');
      }
    } catch (e) {
      print('[StashDB] Exception: $e');
    }
    return null;
  }

  MediaItem _mapSceneToMediaItem(Map<String, dynamic> scene, String originalFileName) {
    // Extract poster
    String? poster;
    final images = scene['images'] as List?;
    if (images != null && images.isNotEmpty) {
      poster = images.first['url'];
    }

    // Extract Performers
    final performers = (scene['performers'] as List?)
        ?.map((p) => p['performer']?['name'] as String?)
        .where((n) => n != null)
        .join(', ');
        
    final cast = (scene['performers'] as List?)?.map((p) {
        final perf = p['performer'];
        if (perf == null) return null;
        return CastMember(
          id: perf['id'] as String? ?? '',
          name: perf['name'] as String? ?? 'Unknown',
          character: 'Performer', // Stash doesn't really have characters usually
          profileUrl: perf['image_path'] as String?,
          source: CastSource.stashDb,
        );
    }).whereType<CastMember>().toList() ?? [];

    // Extract Studio
    final studio = scene['studio']?['name'];

    // Extract Tags
    final tags = (scene['tags'] as List?)
        ?.map((t) => t['name'] as String?)
        .whereType<String>()
        .toList() ?? [];

    // Construct Overview
    String overview = scene['details'] ?? '';
    if (performers != null && performers.isNotEmpty) {
      overview = 'Performers: $performers\n\n$overview';
    }
    if (studio != null) {
      overview = 'Studio: $studio\n\n$overview';
    }

    final date = DateTime.tryParse(scene['date'] ?? '');
    
    return MediaItem(
      id: "stashdb:${scene['id']}",
      title: scene['title'] ?? originalFileName,
      fileName: originalFileName,
      filePath: '', // Will be filled by LibraryProvider
      folderPath: '', // Will be filled by LibraryProvider
      sizeBytes: 0, // Will be filled by LibraryProvider
      lastModified: date ?? DateTime.now(),
      year: date?.year,
      type: MediaType.movie, // Treat as movie
      posterUrl: poster,
      overview: overview.trim(),
      cast: cast,
      genres: tags,
      isAdult: true,
    );
  }

  Future<List<MediaItem>> getPerformerScenes(String performerId, String apiKey) async {
    if (apiKey.isEmpty) return [];

    const query = '''
      query FindScenes(\$performerId: ID!) {
        findScenes(scene_filter: {
          performers: {
            value: \$performerId
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

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'ApiKey': apiKey,
        },
        body: jsonEncode({
          'query': query,
          'variables': {'performerId': performerId},
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final scenes = body['data']?['findScenes']?['scenes'] as List?;
        
        if (scenes != null) {
          return scenes
              .map((s) => _mapSceneToMediaItem(s, s['title'] ?? 'Unknown'))
              .toList();
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }
}
