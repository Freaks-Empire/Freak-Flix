
import 'tmdb_item.dart';

class TmdbExtendedDetails {
  final List<TmdbCast> cast;
  final List<TmdbVideo> videos;
  final List<TmdbItem> recommendations;
  final List<TmdbSeason> seasons;

  const TmdbExtendedDetails({
    required this.cast,
    required this.videos,
    required this.recommendations,
    required this.seasons,
  });
}

class TmdbSeason {
  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final String? airDate;
  final String? posterPath;

  const TmdbSeason({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
    this.airDate,
    this.posterPath,
  });

  factory TmdbSeason.fromMap(Map<String, dynamic> map) {
    return TmdbSeason(
      id: map['id'] as int? ?? 0, // Fallback safely
      name: map['name'] as String? ?? '',
      seasonNumber: map['season_number'] as int? ?? 0,
      episodeCount: map['episode_count'] as int? ?? 0,
      airDate: map['air_date'] as String?,
      posterPath: map['poster_path'] as String?,
    );
  }
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
