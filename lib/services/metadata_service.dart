// ignore_for_file: avoid_print

import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import 'stash_db_service.dart';
import 'anilist_service.dart';
import 'trakt_service.dart';
import 'tmdb_service.dart';
import '../utils/filename_parser.dart';

class MetadataService {
  final StashDbService _stash = StashDbService();
  final AniListService _ani = AniListService();
  AniListService get aniListService => _ani;
  final TraktService _trakt = TraktService();
  final SettingsProvider settings;
  final TmdbService tmdbService;
  final Map<String, Map<String, dynamic>> _showCache = {};

  MetadataService(this.settings, this.tmdbService);

  Future<MediaItem> enrich(MediaItem item) async {
    final parsed = FilenameParser.parse(item.fileName);
    var working = item.copyWith(
      title: parsed.seriesTitle,
      year: item.year ?? parsed.year,
      season: item.season ?? parsed.season ?? (parsed.episode != null ? 1 : null),
      episode: item.episode ?? parsed.episode,
      type: _inferType(item, parsed),
      showKey: item.showKey ?? _seriesKey(parsed.seriesTitle, item.year ?? parsed.year, null),
    );

    // 1. Strict Rules Check
    
    // Rule A: Adult Content -> StashDB ONLY
    if (item.isAdult) {
       if (settings.enableAdultContent && settings.stashApiKey.isNotEmpty) {
          final stashItem = await _stash.searchScene(
            parsed.seriesTitle, settings.stashApiKey, settings.stashUrl);
          if (stashItem != null) {
            return item.copyWith(
              title: stashItem.title,
              year: stashItem.year,
              overview: stashItem.overview,
              posterUrl: stashItem.posterUrl,
              backdropUrl: stashItem.backdropUrl,
              isAdult: true,
              type: MediaType.scene,
              genres: stashItem.genres,
              cast: stashItem.cast, 
            );
          }
       }
       // If not enabled or not found, return original item. 
       // Do NOT fall through to TMDB/AniList.
       return item;
    }

    // Rule B: Anime -> AniList ONLY
    if (item.isAnime) {
       // Prefer AniList for Anime is implied by "Library Type: Anime"
       var aniCandidate = await _ani.enrichWithAniList(working);
       if (aniCandidate.anilistId != null) {
          return _ensureTypeForTvHints(aniCandidate);
       }
       // If AniList fails, return original item. 
       // User requested "Anime handles metadata nothing else".
       // We could technically fallback to TMDB if we wanted, but "nothing else" implies strictness.
       // However, AniList might miss some obscure stuff. 
       // Let's assume strict compliance with user request.
       return item;
    }

    // 2. Standard Content (Movies/TV) -> TMDB (with Trakt helper)
    // Always attempt AniList first? No, only for Anime.
    // Wait, what if it's "Movies" library but contains Anime movie?
    // User said "Library type adult -> stash", "Movies and TV -> TMDB".
    // "Anime -> AniList".
    // So if item is NOT tagged as Adult or Anime (by library folder), we proceed to Standard Flow.
    
    // Standard Flow: Trakt (for ID/Type) -> TMDB
    MediaItem base;
    
    // Auto-detect Anime if NOT strictly in Anime folder?
    // If user puts "Naruto" in "TV Shows", do they want AniList?
    // "Prefer AniList For Anime" setting exists.
    final preferAniList = settings.preferAniListForAnime;
    if (preferAniList) {
       var aniCandidate = await _ani.enrichWithAniList(working);
       if (aniCandidate.isAnime && aniCandidate.anilistId != null) {
         return _ensureTypeForTvHints(aniCandidate);
       }
    }

    // Otherwise fall back to Trakt (movies/TV detection via genres) if key exists.
      final bool looksLikeEpisode = working.season != null ||
          working.episode != null ||
          working.type == MediaType.tv;

      if (!_trakt.hasKey) {
        base = _ensureTypeForTvHints(working);
      } else {
        final searchTitle = parsed.seriesTitle;

        if (looksLikeEpisode) {
          final cacheKey = _seriesKey(searchTitle, working.year);
          Map<String, dynamic>? meta = _showCache[cacheKey];
          if (meta == null) {
            print('[metadata] Parsed "$searchTitle" S${working.season ?? '-'}E${working.episode ?? '-'}');
            meta = await _trakt.searchShow(searchTitle, year: working.year);
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
            base = _ensureTypeForTvHints(working);
          } else {
            final enriched = _trakt.applyMetadata(working, meta).copyWith(
              showKey: _seriesKey(searchTitle, working.year, meta['trakt'] as int?),
            );
            base = _ensureTypeForTvHints(enriched.copyWith(
              season: enriched.season ?? working.season,
              episode: enriched.episode ?? working.episode,
            ));
          }
        } else {
          // Movie flow
          final meta = await _trakt.searchMovie(searchTitle, year: working.year);
          if (meta == null) {
            base = _ensureTypeForTvHints(working);
          } else {
            base = _trakt.applyMetadata(working.copyWith(type: MediaType.movie), meta);
          }
        }
    }

    // TMDB Enrichment
    final bool tmdbAllowed = settings.hasTmdbKey && settings.tmdbStatus != TmdbKeyStatus.invalid;
    if (!tmdbAllowed || !tmdbService.hasKey) {
      return base;
    }

    try {
      return await tmdbService.enrich(base);
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