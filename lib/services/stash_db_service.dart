import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

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
            images {
              url
            }
            studio {
              name
            }
            performers {
              performer {
                name
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
        final scenes = body['data']?['searchScene']?['scenes'] as List?;
        
        if (scenes != null && scenes.isNotEmpty) {
          final scene = scenes.first;
          return _mapSceneToMediaItem(scene, title); // Pass original title/filename
        }
      }
    } catch (e) {
      // ignore error
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

    // Extract Studio
    final studio = scene['studio']?['name'];

    // Construct Overview
    String overview = scene['details'] ?? '';
    if (performers != null && performers.isNotEmpty) {
      overview = 'Performers: $performers\n\n$overview';
    }
    if (studio != null) {
      overview = 'Studio: $studio\n\n$overview';
    }

    return MediaItem(
      id: "stashdb:${scene['id']}",
      title: scene['title'] ?? originalFileName, // Prefer StashDB title
      fileName: originalFileName,
      path: '', // Will be filled by LibraryProvider
      size: 0, // Will be filled by LibraryProvider
      modified: DateTime.tryParse(scene['date'] ?? '') ?? DateTime.now(),
      type: MediaType.movie, // Treat as movie
      posterUrl: poster,
      overview: overview.trim(),
      studio: studio,
      isAdult: true,
      backdropUrl: poster, // Use poster as backdrop for now
    );
  }
}
