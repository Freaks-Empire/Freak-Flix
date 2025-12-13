import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/tmdb_item.dart';
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
    if (item.title == null || item.title!.trim().isEmpty) return item;

    final searchPath = '/3/search/${item.type == MediaType.tv ? 'tv' : 'movie'}';
    final query = Uri.https(
      _baseHost,
      searchPath,
      {
        'api_key': key,
        'query': item.title!,
        if (item.year != null) 'year': item.year.toString(),
        'include_adult': 'false',
      },
    );

    final res = await _client.get(query);
    if (res.statusCode != 200) return item;

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return item;

    final best = results.first as Map<String, dynamic>;
    final int tmdbId = best['id'] as int;
    final String? posterPath = best['poster_path'] as String?;
    final String? backdropPath = best['backdrop_path'] as String?;
    final String? overview = best['overview'] as String?;
    final num? voteAverage = best['vote_average'] as num?;
    final String? date = (item.type == MediaType.tv
            ? best['first_air_date']
            : best['release_date'])
        as String?;
    final int? year =
        date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

    int? runtimeMinutes;
    List<String> genres = [];

    final detailsPath = '/3/${item.type == MediaType.tv ? 'tv' : 'movie'}/$tmdbId';
    final detailsUri = Uri.https(
      _baseHost,
      detailsPath,
      {'api_key': key},
    );

    final detailsRes = await _client.get(detailsUri);
    if (detailsRes.statusCode == 200) {
      final d = jsonDecode(detailsRes.body) as Map<String, dynamic>;
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
    }

    return item.copyWith(
      year: item.year ?? year,
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

    // Fetch credits, videos, and recommendations in parallel (append_to_response is cleaner but lets stick to parallel for clarity/control)
    // Actually append_to_response is much better for performance.
    // /movie/{id}?append_to_response=credits,videos,recommendations,similar

    final path = '/3/${type == MediaType.tv ? 'tv' : 'movie'}/$tmdbId';
    final uri = Uri.https(_baseHost, path, {
      'api_key': key,
      'append_to_response': 'credits,videos,recommendations,similar',
    });

    final res = await _client.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    // Parse Cast
    final credits = data['credits'] as Map<String, dynamic>?;
    final castList = (credits?['cast'] as List<dynamic>? ?? [])
        .take(15) // Limit to top 15
        .map((c) => TmdbCast.fromMap(c, _imageBase))
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

    return TmdbExtendedDetails(
        cast: castList, videos: vidList, recommendations: combinedRecs);
  }
}

class TmdbExtendedDetails {
  final List<TmdbCast> cast;
  final List<TmdbVideo> videos;
  final List<TmdbItem> recommendations;

  const TmdbExtendedDetails({
    required this.cast,
    required this.videos,
    required this.recommendations,
  });
}

class TmdbCast {
  final String name;
  final String character;
  final String? profileUrl;

  const TmdbCast({required this.name, required this.character, this.profileUrl});

  factory TmdbCast.fromMap(Map<String, dynamic> map, String validImageBase) {
    final path = map['profile_path'] as String?;
    return TmdbCast(
      name: map['name'] as String? ?? 'Unknown',
      character: map['character'] as String? ?? '',
      profileUrl: path != null ? '$validImageBase$path' : null,
    );
  }
}

class TmdbVideo {
  final String key;
  final String site;
  final String type;
  final String name;

  const TmdbVideo({
    required this.key,
    required this.site,
    required this.type,
    required this.name,
  });

  factory TmdbVideo.fromMap(Map<String, dynamic> map) {
    return TmdbVideo(
      key: map['key'] as String? ?? '',
      site: map['site'] as String? ?? '',
      type: map['type'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }
}
