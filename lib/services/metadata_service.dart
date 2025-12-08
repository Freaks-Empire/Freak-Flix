import '../models/media_item.dart';
import '../providers/settings_provider.dart';
import 'anilist_service.dart';
import 'omdb_service.dart';

class MetadataService {
  final OmdbService _omdb = OmdbService();
  final AniListService _ani = AniListService();
  final SettingsProvider settings;

  MetadataService(this.settings);

  Future<MediaItem> enrich(MediaItem item) async {
    final preferAniList = settings.preferAniListForAnime;

    // If we already know it is anime, use AniList only and skip OMDb entirely.
    if (item.type == MediaType.anime) {
      return _ani.enrichWithAniList(item);
    }

    // If user prefers AniList for anime-like content, try AniList first; if it classifies as anime, keep it.
    if (preferAniList) {
      final enriched = await _ani.enrichWithAniList(item);
      if (enriched.type == MediaType.anime) return enriched;
    }

    // Otherwise fall back to OMDb (movies/TV). OMDb key is required for this path.
    return _omdb.enrichWithOmdb(item);
  }
}