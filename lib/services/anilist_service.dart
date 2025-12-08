import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// AniList uses the public GraphQL endpoint. Adjust the query if you need more fields.
class AniListService {
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<MediaItem> enrichWithAniList(MediaItem item) async {
    final search = _buildSearchString(item);
    if (search.isEmpty) return item;

    final key = search.toLowerCase();
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

    final variables = {'search': search};
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

  String _buildSearchString(MediaItem item) {
    final raw = (item.title ?? item.fileName).replaceAll(RegExp(r'[\[\]\(\)]'), ' ');

    // Strip common noise: SxxEyy, "Season 1", resolutions, source tags, encodes, discs.
    final cleaned = raw
        .replaceAll(RegExp(r'\b[Ss]\d{1,2}[Ee]\d{1,3}\b'), ' ')
        .replaceAll(RegExp(r'\b[Ss]eason\s*\d{1,2}\b'), ' ')
        .replaceAll(RegExp(r'\b[Ee][Pp]?(?:isode)?\s*\d{1,3}\b'), ' ')
        .replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ')
        .replaceAll(RegExp(r'\b(480|720|1080|2160)[pi]\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(bluray|bd|webrip|web-dl|hdrip|remux|dvdrip)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(x264|x265|hevc|avc|aac|flac|ddp?\d?)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(multi|dual audio|subbed|dubbed)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[._-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Leave only letters, numbers, and spaces to improve AniList search matching.
    final alphaNum = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return alphaNum;
  }

  MediaItem _apply(MediaItem item, Map<String, dynamic> media) {
    final title = (media['title'] as Map<String, dynamic>?)?['english'] as String? ??
        (media['title'] as Map<String, dynamic>?)?['romaji'] as String? ??
        item.title;
    final year = media['seasonYear'] as int?;
    final episodes = media['episodes'] as int?;
    final genres = (media['genres'] as List<dynamic>? ?? []).cast<String>();
    final score = (media['averageScore'] as num?)?.toDouble();
    final runtime = media['duration'] as int?;
    final format = (media['format'] as String?)?.toUpperCase();
    final isMovieFormat = format == 'MOVIE';
    return item.copyWith(
      title: item.title ?? title,
      year: item.year ?? year,
      type: isMovieFormat ? MediaType.movie : MediaType.tv,
      episode: isMovieFormat ? item.episode : (item.episode ?? episodes),
      posterUrl: media['coverImage']?['large'] as String?,
      backdropUrl: media['bannerImage'] as String?,
      overview: item.overview ?? media['description'] as String?,
      rating: score != null ? score / 10.0 : null,
      runtimeMinutes: runtime,
      genres: item.genres.isNotEmpty ? item.genres : genres,
      isAnime: true,
    );
  }
}