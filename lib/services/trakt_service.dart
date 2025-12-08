import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// Put your Trakt Client ID here. Create one at https://trakt.tv/oauth/applications
// (copy the Client ID, no secret needed for public metadata reads).
const _traktClientId = 'REPLACE_WITH_TRAKT_CLIENT_ID';

bool get _hasTraktKey => _traktClientId != 'REPLACE_WITH_TRAKT_CLIENT_ID' && _traktClientId.isNotEmpty;

class TraktService {
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<int, Map<String, dynamic>> _showDetailsCache = {};

  bool get hasKey => _hasTraktKey;

  Future<Map<String, dynamic>?> searchShow(String title, {int? year}) async {
    return _search(title, type: 'show', year: year);
  }

  Future<Map<String, dynamic>?> searchMovie(String title, {int? year}) async {
    return _search(title, type: 'movie', year: year);
  }

  Future<MediaItem> enrichWithTrakt(MediaItem item) async {
    if (!_hasTraktKey) return item;

    final query = _buildSearchQuery(item);
    if (query.isEmpty) return item;

    final bool prefersShow = _looksLikeEpisode(item);
    final meta = prefersShow
        ? await searchShow(query, year: item.year)
        : await searchMovie(query, year: item.year);
    if (meta == null) return item;
    return applyMetadata(item, meta);
  }

  String _buildSearchQuery(MediaItem item) {
    return _cleanQuery(item.title ?? item.fileName);
  }

  String _cleanQuery(String input) {
    final raw = input.replaceAll(RegExp(r'[\[\]\(\)]'), ' ');
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

  Future<Map<String, dynamic>?> _search(String title, {required String type, int? year}) async {
    if (!_hasTraktKey) return null;
    final query = _cleanQuery(title);
    if (query.isEmpty) return null;

    final cacheKey = '$type-${query.toLowerCase()}-${year ?? ''}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    final uri = Uri.https('api.trakt.tv', '/search/$type', {
      'query': query,
      if (year != null) 'year': year.toString(),
      'extended': 'full',
    });

    try {
      final headers = <String, String>{
        'trakt-api-version': '2',
        'trakt-api-key': _traktClientId,
        'Content-Type': 'application/json',
      };
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;

      final best = _pickBest(list, expectedType: type, expectedYear: year);
      if (best == null) return null;
      _cache[cacheKey] = best;
      return best;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickBest(List<dynamic> list, {required String expectedType, int? expectedYear}) {
    Map<String, dynamic>? best;
    double bestScore = -1;

    for (final raw in list) {
      final map = raw as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type != expectedType) continue;
      final data = map[type] as Map<String, dynamic>?;
      if (data == null) continue;

      final score = (map['score'] as num?)?.toDouble() ?? 0.0;
      final yearMatch = expectedYear != null && data['year'] == expectedYear;
      if (yearMatch) return _toMetadata(data, type);

      if (score > bestScore) {
        bestScore = score;
        best = _toMetadata(data, type);
      } else if (best == null) {
        best = _toMetadata(data, type);
      }
    }

    if (best != null) return best;

    for (final raw in list) {
      final map = raw as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type != expectedType) continue;
      final data = map[type] as Map<String, dynamic>?;
      if (data != null) return _toMetadata(data, type);
    }
    return null;
  }

  Map<String, dynamic> _toMetadata(Map<String, dynamic> data, String type) {
    final ids = (data['ids'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final countryRaw = data['country'] ?? data['origin_country'];
    final originCountries = countryRaw is List
        ? countryRaw.map((e) => e.toString()).toList()
        : countryRaw is String
            ? [countryRaw]
            : <String>[];
    return {
      'type': type,
      'title': data['title'],
      'year': data['year'],
      'overview': data['overview'],
      'genres': (data['genres'] as List<dynamic>? ?? []).cast<String>(),
      'rating': (data['rating'] as num?)?.toDouble(),
      'runtime': data['runtime'],
      'tmdb': ids['tmdb'],
      'trakt': ids['trakt'],
      'slug': ids['slug'],
      'original_language': data['language'],
      'origin_country': originCountries,
    };
  }

  Future<Map<String, dynamic>?> getShowDetails(int traktId) async {
    if (_showDetailsCache.containsKey(traktId)) return _showDetailsCache[traktId];
    if (!_hasTraktKey) return null;

    final uri = Uri.https('api.trakt.tv', '/shows/$traktId', {'extended': 'full,images'});
    try {
      final headers = <String, String>{
        'trakt-api-version': '2',
        'trakt-api-key': _traktClientId,
        'Content-Type': 'application/json',
      };
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ids = (data['ids'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final images = data['images'] as Map<String, dynamic>?;
      final posters = images?['poster'] as Map<String, dynamic>?;
      final backdrops = images?['fanart'] as Map<String, dynamic>?;
      final result = {
        'type': 'show',
        'title': data['title'],
        'year': data['year'],
        'overview': data['overview'],
        'genres': (data['genres'] as List<dynamic>? ?? []).cast<String>(),
        'rating': (data['rating'] as num?)?.toDouble(),
        'runtime': data['runtime'],
        'tmdb': ids['tmdb'],
        'trakt': ids['trakt'],
        'slug': ids['slug'],
        'original_language': data['language'],
        'origin_country': (data['country'] is List)
            ? (data['country'] as List).map((e) => e.toString()).toList()
            : data['country'] is String
                ? [data['country']]
                : <String>[],
        'poster': posters?['full'] ?? posters?['medium'] ?? posters?['thumb'],
        'backdrop': backdrops?['full'] ?? backdrops?['medium'] ?? backdrops?['thumb'],
      };
      _showDetailsCache[traktId] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  bool isAnime(Map<String, dynamic> meta) {
    final genres = (meta['genres'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
    final hasAnimeGenre = genres.any((g) => g == 'anime' || g == 'animation');
    final language = (meta['original_language'] as String?)?.toLowerCase();
    final countries = (meta['origin_country'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()).toList();
    final hasJapan = countries.contains('jp') || countries.contains('jpn') || countries.contains('japan');
    return hasAnimeGenre || language == 'ja' || hasJapan;
  }

  MediaItem applyMetadata(MediaItem item, Map<String, dynamic> meta) {
    final metaType = meta['type'] as String?;
    final isAnimeMeta = isAnime(meta);
    MediaType mappedType;
    if (metaType == 'movie') {
      mappedType = MediaType.movie;
    } else if (metaType == 'show') {
      mappedType = MediaType.tv;
    } else {
      mappedType = item.type;
    }

    final genres = (meta['genres'] as List<dynamic>? ?? []).cast<String>();
    final poster = meta['poster'] as String?;
    final backdrop = meta['backdrop'] as String?;
    final traktId = meta['trakt'] as int?;

    return item.copyWith(
      title: item.title ?? meta['title'] as String?,
      year: meta['year'] as int? ?? item.year,
      type: item.type == MediaType.unknown ? mappedType : item.type,
      overview: meta['overview'] as String? ?? item.overview,
      rating: meta['rating'] as double? ?? item.rating,
      runtimeMinutes: meta['runtime'] as int? ?? item.runtimeMinutes,
      genres: item.genres.isNotEmpty ? item.genres : genres,
      isAnime: item.isAnime || isAnimeMeta,
      tmdbId: meta['tmdb'] as int? ?? item.tmdbId,
      posterUrl: item.posterUrl ?? poster,
      backdropUrl: item.backdropUrl ?? backdrop,
      showKey: item.showKey ?? (traktId != null ? 'trakt:$traktId' : null),
    );
  }

  bool _looksLikeEpisode(MediaItem item) {
    if (item.type == MediaType.tv || item.isAnime) return true;
    if (item.season != null || item.episode != null) return true;
    return RegExp(r'[Ss]\d{1,2}[Ee]\d{1,3}').hasMatch(item.fileName);
  }
}
