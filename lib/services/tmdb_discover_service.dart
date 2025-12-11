import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/discover_filter.dart';
import '../models/tmdb_item.dart';
import '../providers/settings_provider.dart';

class TmdbDiscoverService {
  final SettingsProvider settings;
  final http.Client _client;
  static const _baseHost = 'api.themoviedb.org';
  static const _imageBase = 'https://image.tmdb.org/t/p/w500';

  TmdbDiscoverService(this.settings, {http.Client? client})
      : _client = client ?? http.Client();

  String? get _key {
    final k = settings.tmdbApiKey.trim();
    return k.isEmpty ? null : k;
  }

  Future<DiscoverBundle> fetchAll({DiscoverFilter? filter}) async {
    final key = _key;
    if (key == null) {
      throw Exception('TMDB API key is missing. Add it in Settings first.');
    }

    final f = filter ?? DiscoverFilter.empty;
    final results = await Future.wait([
      fetchTrending(filter: f),
      fetchRecommended(filter: f),
      fetchPopular(filter: f),
      fetchUpcoming(filter: f),
      fetchTopRated(filter: f),
    ]);

    return DiscoverBundle(
      trending: results[0],
      recommended: results[1],
      popular: results[2],
      upcoming: results[3],
      topRated: results[4],
    );
  }

  Future<List<TmdbItem>> fetchTrending({DiscoverFilter? filter}) async {
    final key = _key;
    if (key == null) return [];
    final uri = Uri.https(
      _baseHost,
      '/3/trending/all/week',
      {
        'api_key': key,
        'language': 'en-US',
      },
    );
    return _getList(uri, defaultType: TmdbMediaType.movie, allowFilter: false);
  }

  Future<List<TmdbItem>> fetchRecommended({DiscoverFilter? filter}) async {
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.tv,
      fallbackPath: '/3/tv/popular',
      sortBy: 'popularity.desc',
      filter: filter,
    );
  }

  Future<List<TmdbItem>> fetchPopular({DiscoverFilter? filter}) async {
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.movie,
      fallbackPath: '/3/movie/popular',
      sortBy: 'popularity.desc',
      filter: filter,
    );
  }

  Future<List<TmdbItem>> fetchUpcoming({DiscoverFilter? filter}) async {
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.movie,
      fallbackPath: '/3/movie/upcoming',
      sortBy: 'primary_release_date.asc',
      filter: filter,
      extraQuery: {'region': 'US'},
    );
  }

  Future<List<TmdbItem>> fetchTopRated({DiscoverFilter? filter}) async {
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.movie,
      fallbackPath: '/3/movie/top_rated',
      sortBy: 'vote_average.desc',
      filter: filter,
    );
  }

  Future<List<TmdbItem>> _fetchWithOptionalDiscover({
    required TmdbMediaType mediaType,
    required String fallbackPath,
    required String sortBy,
    DiscoverFilter? filter,
    Map<String, String>? extraQuery,
  }) async {
    final key = _key;
    if (key == null) return [];

    final hasFilter = _hasFilter(filter);
    final path = hasFilter
        ? '/3/discover/${mediaType == TmdbMediaType.tv ? 'tv' : 'movie'}'
        : fallbackPath;

    final query = {
      'api_key': key,
      'language': 'en-US',
      if (hasFilter) 'sort_by': sortBy,
      ...?_applyFilter(filter),
      ...?extraQuery,
    };

    final uri = Uri.https(_baseHost, path, query);
    return _getList(uri, defaultType: mediaType);
  }

  Map<String, String>? _applyFilter(DiscoverFilter? filter) {
    if (filter == null) return null;

    final query = <String, String>{};
    if (filter.genreId != null) query['with_genres'] = '${filter.genreId}';

    if (filter.decadeStartYear != null) {
      final start = filter.decadeStartYear!;
      final end = start + 9;
      query['primary_release_date.gte'] = '$start-01-01';
      query['primary_release_date.lte'] = '$end-12-31';
    }

    if (filter.minRating != null) {
      query['vote_average.gte'] = (filter.minRating! / 2).toStringAsFixed(1);
      query['vote_count.gte'] = '50';
    }

    return query.isEmpty ? null : query;
  }

  bool _hasFilter(DiscoverFilter? f) {
    if (f == null) return false;
    return f.genreId != null || f.decadeStartYear != null || f.minRating != null;
  }

  Future<List<TmdbItem>> _getList(
    Uri uri, {
    required TmdbMediaType defaultType,
    bool allowFilter = true,
  }) async {
    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null) return [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => TmdbItem.fromMap(
            m,
            imageBase: _imageBase,
            defaultType: defaultType,
          ),
        )
        .where((item) => item.title.isNotEmpty)
        .toList();
  }
}

class DiscoverBundle {
  final List<TmdbItem> trending;
  final List<TmdbItem> recommended;
  final List<TmdbItem> popular;
  final List<TmdbItem> upcoming;
  final List<TmdbItem> topRated;

  const DiscoverBundle({
    required this.trending,
    required this.recommended,
    required this.popular,
    required this.upcoming,
    required this.topRated,
  });

  static const empty = DiscoverBundle(
    trending: [],
    recommended: [],
    popular: [],
    upcoming: [],
    topRated: [],
  );
}
