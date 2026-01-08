/// lib/services/metadata_service.dart
// ignore_for_file: avoid_print

import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import '../models/stash_endpoint.dart';
import 'stash_db_service.dart';
import 'anilist_service.dart';
import 'trakt_service.dart';
import 'tmdb_service.dart';
import '../utils/filename_parser.dart';
import 'package:path/path.dart' as p;

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

    // 0. Manual Override Check (StashDB ID) - Lock Respect
    if (item.stashId != null && item.stashId!.isNotEmpty) {
       if (settings.stashEndpoints.any((e) => e.enabled)) {
          final rawId = item.stashId!.replaceFirst('stashdb:', '');
          final stashItem = await _stash.getScene(rawId, settings.stashEndpoints);
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
              stashId: rawId,
            );
          }
       }
    }

    // 1. Strict Rules Check
    
    // Rule A: Adult Content -> StashDB ONLY
    if (item.isAdult) {
       if (settings.enableAdultContent && settings.stashEndpoints.any((e) => e.enabled)) {
          MediaItem? stashItem;

          // Attempt 1: Performer-First Search
          if (parsed.performers.isNotEmpty) {
             print('[metadata] StashDB: Attempting performer-first search for "${parsed.seriesTitle}" with performer: ${parsed.performers.first} (Strict: ${settings.requirePerformerMatch})');
             stashItem = await _stash.searchSceneByPerformer(
               parsed.seriesTitle, 
               parsed.performers.first, 
               settings.stashEndpoints,
               requirePerformerMatch: settings.requirePerformerMatch, // Pass setting
             );
          }

          // Attempt 2: Standard title search (fallback)
          if (stashItem == null) {
             // If strict matching is required AND we had performers, we might choose NOT to fallback
             // But the prompt implies fallback logic is standard unless specified otherwise.
             // Usually strict matching means "if performer match fails, fail whole thing" OR "only accept high confidence".
             // We will allow fallback for now unless safety setting implies "ONLY allow confirmed matches".
             // Given safety net context, we proceed to fallback but log it.
             
             print('[metadata] StashDB: Performer search failed or no performers. Trying title search: "${parsed.seriesTitle}"');
             stashItem = await _stash.searchScene(
               parsed.seriesTitle, settings.stashEndpoints);
          }
          
          // Attempt 3: Search by parent folder name (Fallback)
          if (stashItem == null) {
            try {
              String parentDir = '';
              
              if (item.id.startsWith('onedrive')) {
                  parentDir = p.basename(item.folderPath);
              } else if (item.filePath.isNotEmpty) {
                  parentDir = p.basename(p.dirname(item.filePath));
              }

              if (parentDir.isNotEmpty && parentDir != parentDir.toUpperCase() && parentDir != '.') { 
                 print('[metadata] StashDB: Title search failed. Retrying with folder: "$parentDir"');
                 stashItem = await _stash.searchScene(
                   parentDir, settings.stashEndpoints);

                 // Attempt 4: Parse parent folder name and search
                 if (stashItem == null) {
                    final parsedFolder = FilenameParser.parse(parentDir);
                    if (parsedFolder.seriesTitle.isNotEmpty && parsedFolder.seriesTitle != parsed.seriesTitle) {
                       print('[metadata] StashDB: Folder search failed. Retrying with parsed folder: "${parsedFolder.seriesTitle}"');
                       stashItem = await _stash.searchScene(
                         parsedFolder.seriesTitle, settings.stashEndpoints);
                    }
                 }
              }
            } catch (e) {
              print('[metadata] Error extracting parent folder: $e');
            }
          }

          if (stashItem != null) {
            String? stashId;
            if (stashItem.id.startsWith('stashdb:')) {
              stashId = stashItem.id.replaceFirst('stashdb:', '');
            }

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
              stashId: stashId, 
            );
          }
       }
       return item;
    }

    // Rule B: Anime -> AniList ONLY
    if (item.isAnime) {
       var aniCandidate = await _ani.enrichWithAniList(working);
       if (aniCandidate.anilistId != null) {
          return _ensureTypeForTvHints(aniCandidate);
       }
       return item;
    }

    // Rule C: Standard Content -> TMDB only (via Trakt/TMDB)
    MediaItem base;
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
