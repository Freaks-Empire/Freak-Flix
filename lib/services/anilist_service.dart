import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// AniList uses the public GraphQL endpoint. Adjust the query if you need more fields.
class AniListService {
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<MediaItem> enrichWithAniList(MediaItem item) async {
    final key = _normalizedKey(item);
    if (_cache.containsKey(key)) {
      return _apply(item, _cache[key]!);
    }

    const url = 'https://graphql.anilist.co';
    const query = r'''
      query ($search: String) {
        Media(search: $search, type: ANIME) {
          id
          title { romaji english native }
          description(asHtml: false)
          episodes
          status
          seasonYear
          coverImage { large }
          bannerImage
          genres
          averageScore
          duration
        }
      }
    ''';

    final variables = {'search': item.title ?? item.fileName};
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'variables': variables}),
      );
      if (res.statusCode != 200) return item;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final media = (body['data'] as Map<String, dynamic>?)?['Media'] as Map<String, dynamic>?;
      if (media == null) return item;
      _cache[key] = media;
      return _apply(item, media);
    } catch (_) {
      return item;
    }
  }

  String _normalizedKey(MediaItem item) => (item.title ?? item.fileName).toLowerCase();

  MediaItem _apply(MediaItem item, Map<String, dynamic> media) {
    final title = (media['title'] as Map<String, dynamic>?)?['english'] as String? ??
        (media['title'] as Map<String, dynamic>?)?['romaji'] as String? ??
        item.title;
    final year = media['seasonYear'] as int?;
    final episodes = media['episodes'] as int?;
    final genres = (media['genres'] as List<dynamic>? ?? []).cast<String>();
    final score = (media['averageScore'] as num?)?.toDouble();
    final runtime = media['duration'] as int?;
    return item.copyWith(
      title: item.title ?? title,
      year: item.year ?? year,
      type: MediaType.anime,
      episode: item.episode ?? episodes,
      posterUrl: media['coverImage']?['large'] as String?,
      backdropUrl: media['bannerImage'] as String?,
      overview: item.overview ?? media['description'] as String?,
      rating: score != null ? score / 10.0 : null,
      runtimeMinutes: runtime,
      genres: item.genres.isNotEmpty ? item.genres : genres,
    );
  }
}