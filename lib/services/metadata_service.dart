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
    if (item.type == MediaType.anime || preferAniList) {
      final enriched = await _ani.enrichWithAniList(item);
      if (enriched.type == MediaType.anime) return enriched;
    }
    return _omdb.enrichWithOmdb(item);
  }
}