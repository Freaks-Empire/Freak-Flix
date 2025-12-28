/// lib/services/tmdb_discover_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/discover_filter.dart';
import '../models/tmdb_item.dart';
import '../providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

enum DiscoverType { all, movie, tv, anime }

class TmdbDiscoverService {
  final SettingsProvider settings;
  final http.Client _client;
  static const _baseHost = 'api.themoviedb.org';
  static const _imageBase = 'https://image.tmdb.org/t/p/w500';

  TmdbDiscoverService(this.settings, {http.Client? client})
      : _client = client ?? http.Client();

  final Map<String, _CacheEntry> _cache = {};

  void clearCache() => _cache.clear();

  String? get _key {
    final k = settings.tmdbApiKey.trim();
    return k.isEmpty ? null : k;
  }

  Future<DiscoverBundle> fetchAll({DiscoverFilter? filter, DiscoverType type = DiscoverType.all}) async {
    final key = _key;
    if (key == null) {
      throw Exception('TMDB API key is missing. Add it in Settings first.');
    }

    final f = filter ?? DiscoverFilter.empty;
    
    // For anime, "Upcoming" is usually "Airing Now/Next Season", handled via discover dates.
    // For specific types, we parallelize.
    final results = await Future.wait([
      fetchTrending(filter: f, type: type),
      fetchRecommended(filter: f, type: type),
      fetchPopular(filter: f, type: type),
      fetchUpcoming(filter: f, type: type),
      fetchTopRated(filter: f, type: type),
    ]);

    return DiscoverBundle(
      trending: results[0],
      recommended: results[1],
      popular: results[2],
      upcoming: results[3],
      topRated: results[4],
    );
  }

  Future<List<TmdbItem>> fetchTrending({DiscoverFilter? filter, DiscoverType type = DiscoverType.all, int page = 1}) async {
    final key = _key;
    if (key == null) return [];

    // Special handling for Anime Trending -> use Discover with recent dates or just popularity?
    // TMDB doesn't have /trending/anime. use discover.
    if (type == DiscoverType.anime) {
      // Trending: Airing in last 3 months + high popularity (Seasonal hits)
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      return _fetchAnime(
        sortBy: 'popularity.desc', 
        filter: filter, 
        page: page,
        extraQuery: {'air_date.gte': threeMonthsAgo.toString().substring(0,10)},
      );
    }
    
    String path;
    switch (type) {
      case DiscoverType.movie:
        path = '/3/trending/movie/week';
        break;
      case DiscoverType.tv:
        path = '/3/trending/tv/week';
        break;
      default:
        path = '/3/trending/all/week';
        break;
    }

    final uri = Uri.https(
      _baseHost,
      path,
      {
        'api_key': key,
        'language': 'en-US',
        'page': '$page',
      },
    );
    // For trending/all, defaultType isn't strict, items have 'media_type'.
    // but _getList needs a fallback.
    return _getList(uri, defaultType: type == DiscoverType.movie ? TmdbMediaType.movie : TmdbMediaType.tv, allowFilter: false);
  }

  Future<List<TmdbItem>> fetchRecommended({DiscoverFilter? filter, DiscoverType type = DiscoverType.all, int page = 1}) async {
    // "Recommended" -> Top Rated / Critically Acclaimed
    
    if (type == DiscoverType.anime) {
       // Top Rated Anime
       return _fetchAnime(
        sortBy: 'vote_average.desc', 
        filter: filter,
        page: page,
        extraQuery: {
          'vote_count.gte': '250',
          // Exclude extremely old stuff if desired? No, masterpieces are timeless.
        }
      );
    }

    if (type == DiscoverType.movie) {
      return _fetchWithOptionalDiscover(
        mediaType: TmdbMediaType.movie,
        fallbackPath: '/3/movie/now_playing',
        sortBy: 'popularity.desc',
        filter: filter,
        page: page,
        extraQuery: {'region': 'US'}
      );
    }

    if (type == DiscoverType.tv) {
      return _fetchWithOptionalDiscover(
        mediaType: TmdbMediaType.tv,
        fallbackPath: '/3/tv/on_the_air',
        sortBy: 'popularity.desc',
        filter: filter,
        page: page,
      );
    }

    // Default mixed: TV popular as before?
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.tv,
      fallbackPath: '/3/tv/popular', // keeping old default
      sortBy: 'popularity.desc',
      filter: filter,
      page: page,
    );
  }

  Future<List<TmdbItem>> fetchPopular({DiscoverFilter? filter, DiscoverType type = DiscoverType.all, int page = 1}) async {
    if (type == DiscoverType.anime) {
      return _fetchAnime(sortBy: 'popularity.desc', filter: filter, page: page);
    }
    
    final mediaType = (type == DiscoverType.tv) ? TmdbMediaType.tv : TmdbMediaType.movie; 
    // If all, default to movie popular? Or mixed?
    // Old implementation used "movie/popular" for this slot? No, lines 71 was movie/popular.

    final path = (type == DiscoverType.tv) ? '/3/tv/popular' : '/3/movie/popular';
    
    return _fetchWithOptionalDiscover(
      mediaType: mediaType,
      fallbackPath: path,
      sortBy: 'popularity.desc',
      filter: filter,
      page: page,
    );
  }

  Future<List<TmdbItem>> fetchUpcoming({DiscoverFilter? filter, DiscoverType type = DiscoverType.all, int page = 1}) async {
     if (type == DiscoverType.anime) {
      // Upcoming anime: future dates
      final nextWeek = DateTime.now().add(const Duration(days: 1));
      return _fetchAnime(
        sortBy: 'popularity.desc', 
        filter: filter,
        page: page,
        extraQuery: {'first_air_date.gte': nextWeek.toString().substring(0,10)}
      );
    }
    
    if (type == DiscoverType.tv) {
       return _fetchWithOptionalDiscover(
        mediaType: TmdbMediaType.tv,
        fallbackPath: '/3/tv/airing_today', // closest to upcoming
        sortBy: 'popularity.desc',
        filter: filter,
        page: page,
      ); 
    }

    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.movie,
      fallbackPath: '/3/movie/upcoming',
      sortBy: 'primary_release_date.asc',
      filter: filter,
      extraQuery: {'region': 'US'},
      page: page,
    );
  }

  Future<List<TmdbItem>> fetchTopRated({DiscoverFilter? filter, DiscoverType type = DiscoverType.all, int page = 1}) async {
     if (type == DiscoverType.anime) {
      return _fetchAnime(sortBy: 'vote_average.desc', filter: filter, page: page, extraQuery: {'vote_count.gte': '100'});
    }
    
    final mediaType = (type == DiscoverType.tv) ? TmdbMediaType.tv : TmdbMediaType.movie; 
    final path = (type == DiscoverType.tv) ? '/3/tv/top_rated' : '/3/movie/top_rated';

    return _fetchWithOptionalDiscover(
      mediaType: mediaType,
      fallbackPath: path,
      sortBy: 'vote_average.desc',
      filter: filter,
      page: page,
    );
  }

  // --- Helper for Anime ---
  Future<List<TmdbItem>> _fetchAnime({
    required String sortBy,
    DiscoverFilter? filter,
    int page = 1,
    Map<String, String>? extraQuery,
  }) {
    return _fetchWithOptionalDiscover(
      mediaType: TmdbMediaType.tv,
      fallbackPath: '/3/discover/tv', // Always discover for anime
      sortBy: sortBy,
      filter: filter,
      page: page,
      extraQuery: {
        'with_genres': '16', // Animation
        'with_original_language': 'ja', // Japanese
        ...?extraQuery,
      },
      forceDiscover: true,
    );
  }

  Future<List<TmdbItem>> _fetchWithOptionalDiscover({
    required TmdbMediaType mediaType,
    required String fallbackPath,
    required String sortBy,
    DiscoverFilter? filter,
    Map<String, String>? extraQuery,
    int page = 1,
    bool forceDiscover = false,
  }) async {
    final key = _key;
    if (key == null) return [];

    final hasFilter = _hasFilter(filter) || forceDiscover;
    final path = hasFilter
        ? '/3/discover/${mediaType == TmdbMediaType.tv ? 'tv' : 'movie'}'
        : fallbackPath;

    final query = {
      'api_key': key,
      'language': 'en-US',
      'page': '$page',
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
    final cacheKey = _generateCacheKey(uri);
    
    // 1. Check Memory Cache
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (entry.isValid) {
        return entry.items;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // 2. Check Persistent Cache (Lazy load)
    final prefs = await SharedPreferences.getInstance();
    final persistentParam = prefs.getString(cacheKey);
    if (persistentParam != null) {
       try {
         final json = jsonDecode(persistentParam) as Map<String, dynamic>;
         final timestamp = DateTime.fromMillisecondsSinceEpoch(json['ts'] as int);
         final entry = _CacheEntry(
            (json['items'] as List).map((x) => TmdbItem.fromJson(x)).toList(), 
            timestamp
         );
         
         if (entry.isValid) {
            _cache[cacheKey] = entry; // Hydrate memory
            return entry.items;
         } else {
            // Expired
            await prefs.remove(cacheKey);
         }
       } catch (e) {
         debugPrint('Error parsing persistent cache for $cacheKey: $e');
         await prefs.remove(cacheKey);
       }
    }

    // 3. Network Fetch
    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null) return [];
    
    final items = results
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

    // 4. Save to Cache
    final entry = _CacheEntry(items, DateTime.now());
    _cache[cacheKey] = entry;
    
    // Async save to prefs to not block UI?
    // We want to avoid race conditions but for cache it's fine.
    _saveToPersistentCache(prefs, cacheKey, entry);

    return items;
  }
  
  String _generateCacheKey(Uri uri) {
    // Sanitize URI to be key-safe. 
    // We remove the API Key to potentially share cache if keys change? 
    // No, different keys might have different perms? Unlikely for public API.
    // Better to just hash the whole thing or the path+query without api_key.
    // For simplicity, hash the whole URI string.
    final bytes = utf8.encode(uri.toString());
    final digest = md5.convert(bytes);
    return 'tmdb_discovery_${digest.toString()}';
  }

  Future<void> _saveToPersistentCache(SharedPreferences prefs, String key, _CacheEntry entry) async {
      try {
        final data = {
          'ts': entry.timestamp.millisecondsSinceEpoch,
          'items': entry.items.map((i) => i.toJson()).toList(),
        };
        await prefs.setString(key, jsonEncode(data));
      } catch (e) {
        debugPrint('Failed to save persistence cache: $e');
      }
  }
}

class _CacheEntry {
  final List<TmdbItem> items;
  final DateTime timestamp;

  _CacheEntry(this.items, this.timestamp);

  // Cache validity duration: 60 minutes
  bool get isValid => DateTime.now().difference(timestamp) < const Duration(minutes: 60);
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
