import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// Put your Trakt Client ID here. Create one at https://trakt.tv/oauth/applications
// (copy the Client ID, no secret needed for public metadata reads).
const _traktClientId = 'REPLACE_WITH_TRAKT_CLIENT_ID';

class TraktService {
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<MediaItem> enrichWithTrakt(MediaItem item) async {
    if (_traktClientId == 'REPLACE_WITH_TRAKT_CLIENT_ID') return item;

    final query = _buildSearchQuery(item);
    if (query.isEmpty) return item;
    final cacheKey = '${query.toLowerCase()}-${item.year ?? ''}-${item.type.name}';
    if (_cache.containsKey(cacheKey)) {
      return _apply(item, _cache[cacheKey]!);
    }

    final uri = Uri.https('api.trakt.tv', '/search/movie,show', {
      'query': query,
      if (item.year != null) 'year': item.year.toString(),
      'extended': 'full',
    });

    try {
      final headers = <String, String>{
        'trakt-api-version': '2',
        'trakt-api-key': _traktClientId,
        'Content-Type': 'application/json',
      };
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return item;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return item;

      final preferredType = (item.type == MediaType.tv || item.type == MediaType.anime)
          ? 'show'
          : item.type == MediaType.movie
              ? 'movie'
              : null;

      Map<String, dynamic>? pick;
      for (final raw in list) {
        final type = raw['type'] as String?;
        if (preferredType != null && type == preferredType) {
          pick = raw as Map<String, dynamic>;
          break;
        }
      }
      pick ??= list.first as Map<String, dynamic>;

      final data = (pick['movie'] as Map<String, dynamic>?) ??
          (pick['show'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      if (data.isEmpty) return item;
      _cache[cacheKey] = data;
      return _apply(item, data, pick['type'] as String?);
    } catch (_) {
      return item;
    }
  }

  String _buildSearchQuery(MediaItem item) {
    final raw = (item.title ?? item.fileName).replaceAll(RegExp(r'[\[\]\(\)]'), ' ');
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
    return cleaned;
  }

  MediaItem _apply(MediaItem item, Map<String, dynamic> data, [String? typeHint]) {
    final title = data['title'] as String? ?? item.title;
    final year = data['year'] as int? ?? item.year;
    final overview = data['overview'] as String? ?? item.overview;
    final genres = (data['genres'] as List<dynamic>? ?? []).cast<String>();
    final rating = (data['rating'] as num?)?.toDouble();
    final runtime = data['runtime'] as int?;

    MediaType mappedType;
    if (typeHint == 'movie') {
      mappedType = MediaType.movie;
    } else if (typeHint == 'show') {
      mappedType = genres.any((g) => g.toLowerCase() == 'anime') ? MediaType.anime : MediaType.tv;
    } else {
      mappedType = item.type;
    }

    return item.copyWith(
      title: item.title ?? title,
      year: year,
      type: item.type == MediaType.unknown ? mappedType : (mappedType == MediaType.anime ? mappedType : item.type),
      overview: overview,
      rating: rating,
      runtimeMinutes: runtime,
      genres: item.genres.isNotEmpty ? item.genres : genres,
      // Trakt does not deliver posters/backdrops directly without TMDB; leave as-is.
    );
  }
}
