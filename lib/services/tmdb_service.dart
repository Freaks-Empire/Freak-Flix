import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class TmdbService {
  final String apiKey;
  final http.Client _client;

  TmdbService(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  static const _baseHost = 'api.themoviedb.org';
  static const _imageBase = 'https://image.tmdb.org/t/p/w500';

  Future<MediaItem> enrich(MediaItem item) async {
    if (item.title == null || item.title!.trim().isEmpty) return item;

    final searchPath = '/3/search/${item.type == MediaType.tv ? 'tv' : 'movie'}';
    final query = Uri.https(
      _baseHost,
      searchPath,
      {
        'api_key': apiKey,
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
      {'api_key': apiKey},
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
}
