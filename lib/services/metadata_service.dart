// ignore_for_file: avoid_print

import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import 'anilist_service.dart';
import 'trakt_service.dart';
import 'tmdb_service.dart';
import '../utils/filename_parser.dart';

class MetadataService {
  final AniListService _ani = AniListService();
  final TraktService _trakt = TraktService();
  final SettingsProvider settings;
  final Map<String, Map<String, dynamic>> _showCache = {};
  TmdbService? _tmdb;
  String? _lastTmdbKey;

  MetadataService(this.settings);

  Future<MediaItem> enrich(MediaItem item) async {
    final tmdbKey = settings.tmdbApiKey.trim();
    if (tmdbKey.isNotEmpty) {
      if (_tmdb == null || _lastTmdbKey != tmdbKey) {
        _tmdb = TmdbService(tmdbKey);
        _lastTmdbKey = tmdbKey;
      }
    } else {
      _tmdb = null;
      _lastTmdbKey = null;
    }

    final parsed = FilenameParser.parse(item.fileName);
    var working = item.copyWith(
      title: parsed.seriesTitle,
      year: item.year ?? parsed.year,
      season: item.season ?? parsed.season ?? (parsed.episode != null ? 1 : null),
      episode: item.episode ?? parsed.episode,
      type: _inferType(item, parsed),
      showKey: item.showKey ?? _seriesKey(parsed.seriesTitle, item.year ?? parsed.year, null),
    );
    final preferAniList = settings.preferAniListForAnime;

    // Always attempt AniList first to auto-detect anime by name/title.
    var aniCandidate = await _ani.enrichWithAniList(working);

    MediaItem base;
    if (preferAniList && aniCandidate.isAnime) {
      if (aniCandidate.type == MediaType.unknown) {
        aniCandidate = aniCandidate.copyWith(type: MediaType.tv);
      }
      base = _ensureTypeForTvHints(aniCandidate);
    } else {
      // Otherwise fall back to Trakt (movies/TV detection via genres) if key exists.
      final bool looksLikeEpisode = aniCandidate.season != null ||
          aniCandidate.episode != null ||
          aniCandidate.type == MediaType.tv ||
          aniCandidate.isAnime;

      if (!_trakt.hasKey) {
        base = _ensureTypeForTvHints(aniCandidate);
      } else {
        final searchTitle = parsed.seriesTitle;

        if (looksLikeEpisode) {
          final cacheKey = _seriesKey(searchTitle, aniCandidate.year);
          Map<String, dynamic>? meta = _showCache[cacheKey];
          if (meta == null) {
            print('[metadata] Parsed "$searchTitle" S${working.season ?? '-'}E${working.episode ?? '-'}');
            meta = await _trakt.searchShow(searchTitle, year: aniCandidate.year);
            print('[metadata] Trakt search for "$searchTitle" -> ${meta?['title']} (${meta?['trakt']})');
            final traktId = meta?['trakt'] as int?;
            if (traktId != null) {
              final details = await _trakt.getShowDetails(traktId);
              if (details != null) {
                meta = {...meta ?? {}, ...details};
              }
            }
            if (meta != null) {
              _showCache[cacheKey] = meta;
            }
          }
          if (meta == null) {
            base = _ensureTypeForTvHints(aniCandidate);
          } else {
            final enriched = _trakt.applyMetadata(aniCandidate, meta).copyWith(
              showKey: _seriesKey(searchTitle, aniCandidate.year, meta['trakt'] as int?),
            );
            print('[metadata] Applied show: ${enriched.title} traktId=${meta['trakt']} isAnime=${enriched.isAnime}');
            base = _ensureTypeForTvHints(enriched.copyWith(
              season: enriched.season ?? working.season,
              episode: enriched.episode ?? working.episode,
            ));
          }
        } else {
          // Movie flow
          final meta = await _trakt.searchMovie(searchTitle, year: aniCandidate.year);
          if (meta == null) {
            base = _ensureTypeForTvHints(aniCandidate);
          } else {
            base = _trakt.applyMetadata(aniCandidate.copyWith(type: MediaType.movie), meta);
          }
        }
      }
    }

    if (_tmdb == null) {
      return base;
    }

    try {
      return await _tmdb!.enrich(base);
    } catch (e) {
      print('[metadata] TMDB error: $e');
      return base;
    }
  }

  MediaItem _ensureTypeForTvHints(MediaItem item) {
    final looksLikeTv = item.type == MediaType.tv ||
        item.season != null ||
        item.episode != null ||
        item.isAnime;
    if (looksLikeTv && item.type == MediaType.unknown) {
      return item.copyWith(type: MediaType.tv);
    }
    return item;
  }

  MediaType _inferType(MediaItem original, ParsedMediaName parsed) {
    final hasTvMarkers = parsed.season != null || parsed.episode != null || original.season != null || original.episode != null;
    if (hasTvMarkers || original.isAnime) return MediaType.tv;
    return original.type == MediaType.unknown ? MediaType.movie : original.type;
  }

  String _seriesKey(String title, int? year, [int? traktId]) {
    if (traktId != null) return 'trakt:$traktId';
    final base = title.toLowerCase().trim();
    final yr = year?.toString() ?? '';
    return '$base-$yr';
  }
}