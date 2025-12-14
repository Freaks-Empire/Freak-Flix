import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/tmdb_extended_details.dart';
import '../models/tmdb_episode.dart';
import '../models/tmdb_item.dart'; // For recommendations if needed

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
      anilistId: media['id'] as int?,
    );
  }

  Future<TmdbExtendedDetails?> getDetails(int id) async {
    const url = 'https://graphql.anilist.co';
    const query = r'''
      query ($id: Int) {
        Media(id: $id) {
          id
          title { romaji english }
          bannerImage
          coverImage { large }
          description
          episodes
          recommendations(perPage: 10, sort: RATING_DESC) {
             nodes {
               mediaRecommendation {
                 id
                 title { romaji english }
                 coverImage { large }
                 type
               }
             }
          }
          streamingEpisodes {
            title
            thumbnail
            url
            site
          }
        }
      }
    ''';

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'variables': {'id': id}}),
      );
      
      if (res.statusCode != 200) return null;
      
      final body = jsonDecode(res.body);
      final media = body['data']?['Media'];
      if (media == null) return null;

      final recs = (media['recommendations']?['nodes'] as List<dynamic>? ?? [])
          .map((n) {
             final m = n['mediaRecommendation'];
             if (m == null) return null;
             // Map to TmdbItem (basic)
             return TmdbItem(
               id: m['id'],
               title: m['title']['english'] ?? m['title']['romaji'] ?? '',
               posterUrl: m['coverImage']?['large'],
               type: TmdbMediaType.tv, // Anime is TV usually
               releaseYear: null,
             );
          })
          .whereType<TmdbItem>()
          .toList();

      return TmdbExtendedDetails(
        cast: [], // TODO: fetch characters
        videos: [], // TODO: fetch trailer
        recommendations: recs,
        seasons: [
           TmdbSeason(
             id: id,
             name: 'Season 1',
             seasonNumber: 1,
             episodeCount: media['episodes'] as int? ?? 0,
             posterPath: media['coverImage']?['large'],
           )
        ],
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<TmdbEpisode>> getEpisodes(int id) async {
    // Re-query or optimize? 
    // We already queried details. Maybe we should cache or just re-query.
    // Ideally getDetails returns cached items.
    // For now, simple re-query of streamingEpisodes + episodes count.
    // Note: AniList "streamingEpisodes" often INCOMPLETE or region locked.
    // Fallback: Generate list 1..N.
    
    // Using same query as getDetails basically.
    const url = 'https://graphql.anilist.co';
    const query = r'''
      query ($id: Int) {
        Media(id: $id) {
          episodes
          streamingEpisodes {
            title
            thumbnail
            url
            site
          }
          nextAiringEpisode {
             episode
          }
        }
      }
    ''';
    
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'variables': {'id': id}}),
      );
      if (res.statusCode != 200) return [];
      
      final data = jsonDecode(res.body)['data']['Media'];
      final count = data['episodes'] as int? ?? 0;
      final streams = (data['streamingEpisodes'] as List<dynamic>? ?? []);
      
      // If streaming episodes exist, map them? NOT Reliable usually.
      // Often streams are just "Episode 1", "Episode 2".
      // But titles are nice.
      // Let's create a list of size `count`.
      // If streams cover it, use titles.
      
      final List<TmdbEpisode> list = [];
      
      // We can't trust streams length == count.
      // Let's prefer generating 1..count.
      // If count is 0, check nextAiring.
      final total = count > 0 ? count : (data['nextAiringEpisode'] != null ? (data['nextAiringEpisode']['episode'] - 1) : 0);
      
      for (int i = 1; i <= total; i++) {
         String name = 'Episode $i';
         String? thumb;
         String overview = '';
         
         // Try to find matching stream info relative to index
         // Streaming episodes might be sparse or not 1-indexed in array.
         // Usually array is sorted?
         if (i <= streams.length) {
            final s = streams[i-1];
            // Check if title has useful info.
            final t = s['title'] as String?;
            if (t != null && t.isNotEmpty) name = t;
            thumb = s['thumbnail'] as String?;
         }
         
         list.add(TmdbEpisode(
           id: i, // Dummy ID
           name: name,
           overview: overview,
           stillPath: thumb,
           episodeNumber: i,
           seasonNumber: 1,
           airDate: null,
           voteAverage: 0,
         ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}