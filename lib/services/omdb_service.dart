import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

// Put your OMDb API key here. Free keys are available at http://www.omdbapi.com/apikey.aspx
const _omdbApiKey = 'REPLACE_WITH_OMDB_KEY';

class OmdbService {
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<MediaItem> enrichWithOmdb(MediaItem item) async {
    if (_omdbApiKey == 'REPLACE_WITH_OMDB_KEY') return item;
    final query = _normalizedKey(item);
    if (_cache.containsKey(query)) {
      return _apply(item, _cache[query]!);
    }

    final uri = Uri.https('www.omdbapi.com', '/', {
      'apikey': _omdbApiKey,
      't': item.title ?? item.fileName,
      if (item.year != null) 'y': item.year.toString(),
    });
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return item;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['Response'] != 'True') return item;
      _cache[query] = body;
      return _apply(item, body);
    } catch (_) {
      return item;
    }
  }

  String _normalizedKey(MediaItem item) {
    final base = item.title ?? item.fileName;
    return '${base.toLowerCase()}-${item.year ?? ''}';
  }

  MediaItem _apply(MediaItem item, Map<String, dynamic> body) {
    final type = mediaTypeFromString(body['Type'] as String?);
    final poster = body['Poster'] as String?;
    final backdrop = body['Poster'] as String?; // OMDb lacks backdrops; reuse poster.
    final genres = (body['Genre'] as String?)?.split(',').map((e) => e.trim()).toList() ?? <String>[];
    final rating = double.tryParse((body['imdbRating'] ?? '').toString());
    final runtimeStr = (body['Runtime'] ?? '').toString().split(' ').first;
    final runtime = int.tryParse(runtimeStr);
    return item.copyWith(
      title: item.title ?? body['Title'] as String?,
      year: item.year ?? int.tryParse((body['Year'] ?? '').toString().split('–').first),
      type: item.type == MediaType.unknown ? type : item.type,
      posterUrl: poster?.toLowerCase() == 'n/a' ? null : poster,
      backdropUrl: backdrop,
      overview: item.overview ?? body['Plot'] as String?,
      rating: rating,
      runtimeMinutes: runtime,
      genres: item.genres.isNotEmpty ? item.genres : genres,
    );
  }
}