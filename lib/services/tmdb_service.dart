import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/tmdb_item.dart';
import '../models/tmdb_episode.dart';
import '../models/tmdb_extended_details.dart';
import '../models/tmdb_person.dart';
import '../models/cast_member.dart';
import '../providers/settings_provider.dart';

class TmdbService {
  final SettingsProvider settings;
  final http.Client _client;

  TmdbService(this.settings, {http.Client? client}) : _client = client ?? http.Client();

  static const _baseHost = 'api.themoviedb.org';
  static const _imageBase = 'https://image.tmdb.org/t/p/w500';

  String? get _key {
    final k = settings.tmdbApiKey.trim();
    return k.isEmpty ? null : k;
  }

  bool get hasKey => _key != null;

  Future<bool> validateKey() async {
    final key = _key;
    if (key == null) return false;

    final uri = Uri.https(_baseHost, '/3/configuration', {'api_key': key});
    final res = await _client.get(uri);
    if (res.statusCode == 200) return true;
    if (res.statusCode == 401 || res.statusCode == 403) return false;
    return false;
  }

  Future<MediaItem> enrich(MediaItem item) async {
    final key = _key;
    if (key == null) return item;
    if (item.type == MediaType.scene || item.type == MediaType.unknown) return item;
    if (item.title == null || item.title!.trim().isEmpty) return item;

    int tmdbId;
    // If ID is already set manually, use it. Otherwise search.
    if (item.tmdbId != null) {
      tmdbId = item.tmdbId!;
    } else {
      final searchPath = '/3/search/${item.type == MediaType.tv ? 'tv' : 'movie'}';
      final query = Uri.https(
        _baseHost,
        searchPath,
        {
          'api_key': key,
          'query': item.title!,
          if (item.year != null) 'year': item.year.toString(),
          'include_adult': settings.enableAdultContent.toString(),
        },
      );

      final res = await _client.get(query);
      if (res.statusCode != 200) return item;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return item;

      final best = results.first as Map<String, dynamic>;
      tmdbId = best['id'] as int;
      // We could also update best match details here but the details call below covers it
    }

    String? posterPath;
    String? backdropPath;
    String? overview;
    num? voteAverage;
    int? year;

    int? runtimeMinutes;
    List<String> genres = [];

    final detailsPath = '/3/${item.type == MediaType.tv ? 'tv' : 'movie'}/$tmdbId';
    final detailsUri = Uri.https(
      _baseHost,
      detailsPath,
      {'api_key': key},
    );

    final detailsRes = await _client.get(detailsUri);
    String? title;
    if (detailsRes.statusCode == 200) {
      final d = jsonDecode(detailsRes.body) as Map<String, dynamic>;
      title = item.type == MediaType.movie ? d['title'] : d['name'];
      
      if (item.type == MediaType.movie) {
        runtimeMinutes = d['runtime'] as int?;
      } else {
        final runTimes = d['episode_run_time'];
        if (runTimes is List && runTimes.isNotEmpty) {
          runtimeMinutes = (runTimes.first as num?)?.toInt();
        }
      }
      final genreList = d['genres'] as List<dynamic>?;
      if (genreList != null) {
        genres = genreList
            .map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList();
      }
      
      posterPath = d['poster_path'];
      backdropPath = d['backdrop_path'];
      overview = d['overview'];
      voteAverage = (d['vote_average'] as num?)?.toDouble();
      final dateStr = item.type == MediaType.movie ? d['release_date'] : d['first_air_date'];
      if (dateStr != null && dateStr.toString().length >= 4) {
         year = int.tryParse(dateStr.toString().substring(0, 4));
      }
    }

    return item.copyWith(
      title: title ?? item.title,
      year: year ?? item.year,
      posterUrl: posterPath != null ? '$_imageBase$posterPath' : item.posterUrl,
      backdropUrl: backdropPath != null ? '$_imageBase$backdropPath' : item.backdropUrl,
      overview: overview?.isNotEmpty == true ? overview : item.overview,
      rating: voteAverage?.toDouble() ?? item.rating,
      runtimeMinutes: runtimeMinutes ?? item.runtimeMinutes,
      genres: genres.isNotEmpty ? genres : item.genres,
      tmdbId: tmdbId,
    );
  }

  Future<TmdbExtendedDetails?> getExtendedDetails(int tmdbId, MediaType type) async {
    final key = _key;
    if (key == null) return null;
    if (type == MediaType.scene || type == MediaType.unknown) return null;

    // Fetch credits, videos, and recommendations in parallel (append_to_response is cleaner but lets stick to parallel for clarity/control)
    // Actually append_to_response is much better for performance.
    // /movie/{id}?append_to_response=credits,videos,recommendations,similar

    final path = '/3/${type == MediaType.tv ? 'tv' : 'movie'}/$tmdbId';
    final uri = Uri.https(_baseHost, path, {
      'api_key': key,
      'append_to_response': 'credits,videos,recommendations,similar,reviews,external_ids',
    });

    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    // Parse Cast
    final credits = data['credits'] as Map<String, dynamic>?;
    final castList = (credits?['cast'] as List<dynamic>? ?? [])
        .take(15) // Limit to top 15
        .map((c) {
          final path = c['profile_path'] as String?;
          return CastMember(
            id: (c['id'] as int).toString(),
            name: c['name'] as String? ?? 'Unknown',
            character: c['character'] as String? ?? '',
            profileUrl: path != null ? '$_imageBase$path' : null,
            source: CastSource.tmdb,
          );
        })
        .where((c) => c.profileUrl != null) // Only show cast with photos? Optional.
        .toList();

    // Parse Videos (Trailers)
    final vids = data['videos'] as Map<String, dynamic>?;
    final vidList = (vids?['results'] as List<dynamic>? ?? [])
        .map((v) => TmdbVideo.fromMap(v))
        .toList();

    // Parse Recommendations/Similar
    // 'recommendations' is usually better personalized, 'similar' is content-based.
    // Design asks for "You May Like". Let's mix or prioritize recommendations.
    final recs = data['recommendations'] as Map<String, dynamic>?;
    final recList = (recs?['results'] as List<dynamic>? ?? []);
    
    // If few recommendations, fallback to similar
    final similar = data['similar'] as Map<String, dynamic>?;
    final simList = (similar?['results'] as List<dynamic>? ?? []);

    final combinedRecs = [...recList, ...simList]
        .take(12)
        .map((m) => TmdbItem.fromMap(
              m,
              imageBase: _imageBase,
              defaultType: type == MediaType.tv ? TmdbMediaType.tv : TmdbMediaType.movie,
            ))
        .where((i) => i.posterUrl != null)
        .toList(); // Simple de-dup? IDK, set probably better but list is fine for now

    // Parse Seasons (Only for TV)
    final seasonsData = data['seasons'] as List<dynamic>?;
    final seasonList = (seasonsData ?? [])
        .map((s) => TmdbSeason.fromMap(s))
        .where((s) => s.seasonNumber > 0) // Usually skip season 0 (Specials) unless wanted
        .toList();

    // Parse Reviews
    final reviewsData = data['reviews'] as Map<String, dynamic>?;
    final reviewsList = (reviewsData?['results'] as List<dynamic>? ?? [])
        .map((r) => TmdbReview.fromMap(r))
        .toList();

    // Parse External IDs
    final externals = data['external_ids'] as Map<String, dynamic>? ?? {};
    final exIds = <String, String>{};
    if (externals['imdb_id'] != null) exIds['imdb'] = externals['imdb_id'].toString();
    if (externals['facebook_id'] != null) exIds['facebook'] = externals['facebook_id'].toString();
    if (externals['instagram_id'] != null) exIds['instagram'] = externals['instagram_id'].toString();
    if (externals['twitter_id'] != null) exIds['twitter'] = externals['twitter_id'].toString();

    // Parse Genres
    final genreList = (data['genres'] as List<dynamic>? ?? [])
        .map((g) => TmdbGenre(id: g['id'] as int, name: g['name'] as String))
        .toList();

    return TmdbExtendedDetails(
       cast: castList,
       videos: vidList,
       recommendations: combinedRecs,
       seasons: seasonList,
       reviews: reviewsList,
       externalIds: exIds,
       genres: genreList,
       status: data['status'] as String? ?? 'Unknown',
       numberOfEpisodes: data['number_of_episodes'] as int? ?? 0,
       tagline: (data['tagline'] as String?)?.isNotEmpty == true ? data['tagline'] : null,
    );
  }

  Future<List<TmdbEpisode>> getSeasonEpisodes(int tvId, int seasonNumber) async {
    final key = _key;
    if (key == null) return [];

    final path = '/3/tv/$tvId/season/$seasonNumber';
    final uri = Uri.https(_baseHost, path, {'api_key': key});

    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final episodes = data['episodes'] as List<dynamic>?;

    if (episodes == null) return [];

    return episodes
        .map((e) => TmdbEpisode.fromMap(e, _imageBase))
        .toList();
  }
  Future<TmdbMovie?> getMovieDetails(int tmdbId) async {
    final key = _key;
    if (key == null) return null;

    final uri = Uri.https(_baseHost, '/3/movie/$tmdbId', {'api_key': key});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TmdbMovie.fromJson(data);
  }

  Future<TmdbTv?> getTvDetails(int tmdbId) async {
    final key = _key;
    if (key == null) return null;

    final uri = Uri.https(_baseHost, '/3/tv/$tmdbId', {'api_key': key});
    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TmdbTv.fromJson(data);
  }

  Future<List<TmdbItem>> getTrending() async {
    // /trending/all/day
    // https://developer.themoviedb.org/reference/trending-all
    if (_apiKey == null) return [];
    
    final uri = Uri.https(_baseUrl, '/3/trending/all/day', {
      'api_key': _apiKey,
      'language': 'en-US',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List).map((e) => TmdbItem.fromJson(e)).toList();
        // Filter out people if undesired, or keep 'all'. 
        // Usually trending includes people, but for media discovery we might strictly want movie/tv.
        // Let's filter to keep only movie/tv for now to avoid clicking a person and having no details screen.
        return results.where((i) => i.mediaType == MediaType.movie || i.mediaType == MediaType.tv).toList();
      }
    } catch (e) {
      debugPrint('Error getting trending: $e');
    }
    return [];
  }

  Future<List<TmdbItem>> searchMulti(String query) async {
    final key = _key;
    if (key == null || query.trim().isEmpty) return [];

    final uri = Uri.https(_baseHost, '/3/search/multi', {
      'api_key': key,
      'query': query,
      'include_adult': settings.enableAdultContent.toString(),
      'language': 'en-US',
    });

    final res = await _client.get(uri);
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null) return [];

    return results
        .where((m) => m['media_type'] == 'movie' || m['media_type'] == 'tv')
        .map((m) => TmdbItem.fromMap(
              m,
              imageBase: _imageBase,
              defaultType: m['media_type'] == 'movie'
                  ? TmdbMediaType.movie
                  : TmdbMediaType.tv,
            ))
        .where((i) => i.posterUrl != null) // Filter items without posters
        .toList();
  }

  Future<TmdbPerson?> getPersonDetails(String tmdbId) async {
    final key = _key;
    if (key == null) return null;

    final uri = Uri.https(_baseHost, '/3/person/$tmdbId', {
      'api_key': key,
      'append_to_response': 'combined_credits,external_ids',
    });

    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TmdbPerson.fromMap(data, _imageBase);
  }
}


