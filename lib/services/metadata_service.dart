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

    // Always attempt AniList first to auto-detect anime by name/title.
    final aniCandidate = await _ani.enrichWithAniList(item);
    if (aniCandidate.type == MediaType.anime) return aniCandidate;

    // If user prefers AniList, keep AniList result even for non-anime types.
    if (preferAniList) return aniCandidate;

    // Otherwise fall back to OMDb (movies/TV). OMDb key is required for this path.
    return _omdb.enrichWithOmdb(item);
  }
}